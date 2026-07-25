param(
    [string[]]$CasesManifests = @(),
    [string]$QuestaBin = "",
    [string]$UvmHome = $env:UVM_HOME,
    [string]$Python = "python",
    [string]$OutDir = "",
    [ValidatePattern("^[sbceftx]+$")]
    [string]$CodeCoverageSpec = "sbcef",
    [switch]$Resume,
    [ValidateRange(0, 3600)]
    [int]$CaseCooldownSeconds = 0,
    [switch]$DryRun,
    [switch]$StopOnFirstFail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SimDir = Split-Path -Parent $ScriptDir
$RepoRoot = Split-Path -Parent $SimDir
$RegressionScript = Join-Path $ScriptDir "run_mha8_regression.ps1"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$CoverageScope = "/ita_mha8_tb_top/dut"

function Write-Utf8File([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if ($parent -ne "" -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Resolve-RepoPath([string]$PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $PathValue))
}

function Resolve-Tool([string]$Name) {
    if ($QuestaBin -ne "") {
        $candidate = Join-Path $QuestaBin $Name
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Required tool not found: $Name"
    }
    return $command.Source
}

function Resolve-PowerShellExe() {
    $powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($null -ne $powershell) {
        return $powershell.Source
    }
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($null -ne $pwsh) {
        return $pwsh.Source
    }
    throw "Neither powershell.exe nor pwsh.exe is available"
}

function Get-DutFingerprint() {
    $dutDir = Join-Path $RepoRoot "dut"
    $entries = Get-ChildItem -LiteralPath $dutDir -Recurse -File |
        Where-Object { $_.Extension -in @(".sv", ".svh", ".v") } |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($RepoRoot.Length).TrimStart([char[]]"\/").Replace("\", "/")
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            "$relative=$hash"
        }

    if (@($entries).Count -eq 0) {
        throw "No DUT HDL files found under $dutDir"
    }

    $payload = [System.Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $digest = $sha.ComputeHash($payload)
    }
    finally {
        $sha.Dispose()
    }
    return ([System.BitConverter]::ToString($digest)).Replace("-", "").ToLowerInvariant()
}

function Invoke-LoggedTool([string]$Tool, [string[]]$Arguments, [string]$LogPath) {
    $commandLine = "$Tool " + (($Arguments | ForEach-Object {
        if ($_ -match "\s") { '"' + $_ + '"' } else { $_ }
    }) -join " ")
    Add-Content -LiteralPath $LogPath -Value ("CMD> " + $commandLine) -Encoding UTF8
    & $Tool @Arguments 2>&1 | ForEach-Object {
        $line = [string]$_
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
        Write-Host $line
    }
    $exitCode = $LASTEXITCODE
    return $exitCode
}

if ($CasesManifests.Count -eq 0) {
    $CasesManifests = @(
        "sim/cases/protocol_directed_mha8_cases.json",
        "sim/cases/protocol_random_mha8_cases.json",
        "sim/cases/random_mha8_cases.json",
        "sim/cases/numerical_corner_mha8_cases.json"
    )
}

$resolvedManifests = @($CasesManifests | ForEach-Object { Resolve-RepoPath $_ })
$caseNames = @{}
foreach ($manifestPath in $resolvedManifests) {
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Cases manifest not found: $manifestPath"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    foreach ($case in @($manifest.cases)) {
        $expectFail = $false
        if ($case.PSObject.Properties.Name -contains "expect_fail") {
            $expectFail = [bool]$case.expect_fail
        }
        if ($expectFail) {
            throw "Code coverage closure accepts legal cases only; expected-fail case found in $manifestPath`: $($case.name)"
        }
        if ($caseNames.ContainsKey($case.name)) {
            throw "Duplicate case name across closure manifests: $($case.name)"
        }
        $caseNames[$case.name] = $manifestPath
    }
}

if ($Resume -and $OutDir -eq "") {
    throw "-Resume requires the original -OutDir so completed case artifacts can be validated"
}
if ($OutDir -eq "") {
    $OutDir = Join-Path $RepoRoot "sim/output/code_coverage_closure/$Timestamp"
} else {
    $OutDir = Resolve-RepoPath $OutDir
}

$powershellExe = Resolve-PowerShellExe
$startTime = Get-Date
$sourceFingerprint = Get-DutFingerprint
$suiteRecords = New-Object System.Collections.Generic.List[object]
$runStatePath = Join-Path $OutDir "coverage_run_state.json"
$manifestSignature = ($resolvedManifests -join "|")

if ($Resume -and (Test-Path -LiteralPath $runStatePath -PathType Leaf)) {
    $runState = Get-Content -LiteralPath $runStatePath -Raw | ConvertFrom-Json
    if ($runState.code_coverage_spec -ne $CodeCoverageSpec -or
        $runState.scope -ne $CoverageScope -or
        $runState.dut_source_fingerprint_sha256 -ne $sourceFingerprint -or
        (($runState.manifests -join "|") -ne $manifestSignature)) {
        throw "Resume metadata does not match the requested manifests, coverage spec/scope, or current DUT fingerprint"
    }
} elseif ($Resume -and (Test-Path -LiteralPath $OutDir)) {
    Write-Warning "Legacy interrupted run has no coverage_run_state.json; validating reusable cases from their PASS result, UCDB, and launch command"
}

if (-not $DryRun) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    $runState = [ordered]@{
        code_coverage_spec = $CodeCoverageSpec
        scope = $CoverageScope
        dut_source_fingerprint_sha256 = $sourceFingerprint
        manifests = $resolvedManifests
    }
    Write-Utf8File $runStatePath (($runState | ConvertTo-Json -Depth 4) + "`n")
}

for ($index = 0; $index -lt $resolvedManifests.Count; $index++) {
    $manifestPath = $resolvedManifests[$index]
    $suiteName = [System.IO.Path]::GetFileNameWithoutExtension($manifestPath)
    $suiteOutDir = Join-Path $OutDir ("{0:D2}_{1}" -f $index, $suiteName)
    $runnerArgs = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $RegressionScript,
        "-CasesManifest", $manifestPath,
        "-QuestaBin", $QuestaBin,
        "-UvmHome", $UvmHome,
        "-Python", $Python,
        "-OutDir", $suiteOutDir,
        "-EnableCodeCoverage",
        "-CodeCoverageSpec", $CodeCoverageSpec,
        "-CaseCooldownSeconds", [string]$CaseCooldownSeconds
    )
    if ($Resume) {
        $runnerArgs += "-Resume"
    }
    if ($StopOnFirstFail) {
        $runnerArgs += "-StopOnFirstFail"
    }
    if ($DryRun) {
        $runnerArgs += "-DryRun"
        Write-Host ("DRYRUN> " + $powershellExe + " " + ($runnerArgs -join " "))
        continue
    }

    New-Item -ItemType Directory -Path $suiteOutDir -Force | Out-Null
    $suiteLog = Join-Path $suiteOutDir "closure_wrapper.log"
    & $powershellExe @runnerArgs 2>&1 | Tee-Object -FilePath $suiteLog
    $suiteExit = $LASTEXITCODE
    if ($suiteExit -ne 0) {
        throw "Suite regression failed with exit code $suiteExit`: $manifestPath"
    }

    if ((Get-DutFingerprint) -ne $sourceFingerprint) {
        throw "DUT source fingerprint changed while closure was running; refusing to merge UCDB files"
    }

    $summaryPath = Join-Path $suiteOutDir "regression_summary.json"
    if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
        throw "Suite summary not found: $summaryPath"
    }
    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    if ([int]$summary.fail -ne 0 -or [int]$summary.pass -ne [int]$summary.total) {
        throw "Suite is not fully passing: $manifestPath"
    }
    if (-not [bool]$summary.code_coverage.enabled -or $summary.code_coverage.status -ne "PASS") {
        throw "Suite did not produce successful code coverage: $manifestPath"
    }
    if ($summary.code_coverage.spec -ne $CodeCoverageSpec -or $summary.code_coverage.scope -ne $CoverageScope) {
        throw "Suite code coverage metadata does not match closure spec/scope: $manifestPath"
    }

    $suiteUcdb = [string]$summary.coverage_merge.merged_ucdb
    if (-not (Test-Path -LiteralPath $suiteUcdb -PathType Leaf)) {
        throw "Suite merged UCDB not found: $suiteUcdb"
    }
    $suiteRecords.Add([pscustomobject]@{
        manifest = $manifestPath
        out_dir = $suiteOutDir
        summary = $summaryPath
        ucdb = $suiteUcdb
        total = [int]$summary.total
        pass = [int]$summary.pass
    })
}

if ($DryRun) {
    Write-Host "DRYRUN> merge legal UCDB files and generate functional/code coverage text, HTML, DU details, provenance, and summary"
    exit 0
}

$coverageDir = Join-Path $OutDir "coverage"
New-Item -ItemType Directory -Path $coverageDir -Force | Out-Null
$coverageLog = Join-Path $coverageDir "vcover.log"
Write-Utf8File $coverageLog ""
$vcover = Resolve-Tool "vcover.exe"
$mergedUcdb = Join-Path $coverageDir "legal_mha8_merged.ucdb"
$functionalReport = Join-Path $coverageDir "coverage_report.txt"
$functionalHtml = Join-Path $coverageDir "coverage_html"
$codeReport = Join-Path $coverageDir "code_coverage_report.txt"
$codeHtml = Join-Path $coverageDir "code_coverage_html"
$duDetails = Join-Path $coverageDir "code_coverage_du_details.txt"
$duDetailsDir = Join-Path $coverageDir "code_coverage_du_details"
$provenancePath = Join-Path $coverageDir "coverage_provenance.json"
$summaryPath = Join-Path $coverageDir "coverage_summary.txt"
$ucdbInputs = @($suiteRecords | ForEach-Object { $_.ucdb })

$mergeExit = Invoke-LoggedTool $vcover (@("merge", $mergedUcdb) + $ucdbInputs) $coverageLog
if ($mergeExit -ne 0) { throw "vcover merge failed with exit code $mergeExit" }

$reportExit = Invoke-LoggedTool $vcover @("report", "-details", "-output", $functionalReport, $mergedUcdb) $coverageLog
if ($reportExit -ne 0) { throw "functional coverage report failed with exit code $reportExit" }
$htmlExit = Invoke-LoggedTool $vcover @("report", "-html", "-details", "-output", $functionalHtml, $mergedUcdb) $coverageLog
if ($htmlExit -ne 0) { throw "functional coverage HTML report failed with exit code $htmlExit" }

$codeExit = Invoke-LoggedTool $vcover @(
    "report", "-code", $CodeCoverageSpec, "-zeros",
    "-instance=$CoverageScope", "-recursive", "-output", $codeReport, $mergedUcdb
) $coverageLog
if ($codeExit -ne 0) { throw "code coverage report failed with exit code $codeExit" }
$codeHtmlExit = Invoke-LoggedTool $vcover @(
    "report", "-html", "-code", $CodeCoverageSpec, "-zeros",
    "-instance=$CoverageScope", "-recursive", "-output", $codeHtml, $mergedUcdb
) $coverageLog
if ($codeHtmlExit -ne 0) { throw "code coverage HTML report failed with exit code $codeHtmlExit" }

$ownedDesignUnits = @(
    "ita_mha8", "ita", "ita_controller", "ita_input_sampler", "ita_inp1_mux", "ita_inp2_mux",
    "ita_sumdotp", "ita_dotp", "ita_accumulator", "ita_softmax_top", "ita_softmax",
    "ita_max_finder", "ita_requatization_controller", "ita_requantizer", "ita_activation",
    "ita_relu", "ita_gelu", "ita_fifo_controller", "ita_output_controller",
    "ita_weight_controller", "ita_head_sum", "ita_serdiv",
    "ita_register_file_1w_multi_port_read", "ita_register_file_1w_multi_port_read_we",
    "ita_register_file_1w_1r_double_width_write", "lzc"
)
New-Item -ItemType Directory -Path $duDetailsDir -Force | Out-Null
Write-Utf8File $duDetails "MHA8 design-unit code coverage details`n"
foreach ($designUnit in $ownedDesignUnits) {
    $duReport = Join-Path $duDetailsDir "$designUnit.txt"
    $duExit = Invoke-LoggedTool $vcover @(
        "report", "-code", $CodeCoverageSpec, "-details", "-zeros",
        "-du=$designUnit", "-output", $duReport, $mergedUcdb
    ) $coverageLog
    if ($duExit -ne 0) {
        throw "design-unit code coverage report failed for $designUnit with exit code $duExit"
    }
    Add-Content -LiteralPath $duDetails -Value ("`n===== $designUnit =====`n") -Encoding UTF8
    Add-Content -LiteralPath $duDetails -Value (Get-Content -LiteralPath $duReport -Raw) -Encoding UTF8
}

$endTime = Get-Date
$waiverJson = Join-Path $RepoRoot "sim/coverage/mha8_code_coverage_waivers.json"
$provenance = [ordered]@{
    name = "mha8_code_coverage_closure"
    start_time = $startTime.ToString("o")
    end_time = $endTime.ToString("o")
    elapsed_seconds = [Math]::Round(($endTime - $startTime).TotalSeconds, 3)
    code_coverage_spec = $CodeCoverageSpec
    scope = $CoverageScope
    dut_source_fingerprint_sha256 = $sourceFingerprint
    raw_coverage_only = $true
    waiver_file = $waiverJson
    waivers_applied = $false
    manifests = $resolvedManifests
    suites = @($suiteRecords.ToArray())
    merged_ucdb = $mergedUcdb
    reports = [ordered]@{
        functional_text = $functionalReport
        functional_html = $functionalHtml
        code_text = $codeReport
        code_html = $codeHtml
        code_du_details = $duDetails
        code_du_detail_dir = $duDetailsDir
    }
}
Write-Utf8File $provenancePath (($provenance | ConvertTo-Json -Depth 8) + "`n")

$totalCases = ($suiteRecords | Measure-Object -Property total -Sum).Sum
$summaryLines = @(
    "MHA8 Code Coverage Closure Summary",
    "out_dir=$OutDir",
    "legal_cases=$totalCases",
    "suite_count=$($suiteRecords.Count)",
    "code_coverage_spec=$CodeCoverageSpec",
    "scope=$CoverageScope",
    "dut_source_fingerprint_sha256=$sourceFingerprint",
    "raw_coverage_only=true",
    "waivers_applied=false",
    "merged_ucdb=$mergedUcdb",
    "functional_report=$functionalReport",
    "code_coverage_report=$codeReport",
    "code_coverage_du_details=$duDetails",
    "provenance=$provenancePath"
)
Write-Utf8File $summaryPath (($summaryLines -join "`n") + "`n")

Write-Host "MHA8 code coverage closure PASS"
Write-Host "  legal_cases=$totalCases"
Write-Host "  merged_ucdb=$mergedUcdb"
Write-Host "  code_report=$codeReport"
Write-Host "  du_details=$duDetails"
