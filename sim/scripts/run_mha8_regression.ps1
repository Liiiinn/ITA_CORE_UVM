param(
    [string]$CasesManifest = "",
    [string]$QuestaBin = "",
    [string]$UvmHome = $env:UVM_HOME,
    [string]$Python = "python",
    [string]$OutDir = "",
    [switch]$DryRun,
    [switch]$StopOnFirstFail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SimDir = Split-Path -Parent $ScriptDir
$CoreDir = Split-Path -Parent $SimDir
$WorkspaceDir = Split-Path -Parent $CoreDir
$LoggerDir = Join-Path $SimDir "logger"
$SimLogDir = Join-Path $SimDir "output\logs"
$SmokeScript = Join-Path $ScriptDir "smoke.ps1"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ($CasesManifest -eq "") {
    $CasesManifest = Join-Path $LoggerDir "random_mha8_cases.json"
}

if ($OutDir -eq "") {
    $OutDir = Join-Path $SimDir "output\random_regression\$Timestamp"
} elseif (-not [System.IO.Path]::IsPathRooted($OutDir)) {
    $OutDir = Join-Path $CoreDir $OutDir
}

function Resolve-RepoPath {
    param([string]$PathText)

    if ($PathText -eq "") {
        return ""
    }
    if ([System.IO.Path]::IsPathRooted($PathText)) {
        return $PathText
    }

    $coreCandidate = Join-Path $CoreDir $PathText
    if (Test-Path -LiteralPath $coreCandidate) {
        return $coreCandidate
    }

    $workspaceCandidate = Join-Path $WorkspaceDir $PathText
    if (Test-Path -LiteralPath $workspaceCandidate) {
        return $workspaceCandidate
    }

    if ($PathText -like "ITA_CORE_UVM/*" -or $PathText -like "ITA_CORE_UVM\*") {
        return $workspaceCandidate
    }
    return $coreCandidate
}

function Resolve-Tool {
    param([string]$Name)

    if ($QuestaBin -ne "") {
        return Join-Path $QuestaBin $Name
    }
    return $Name
}

function Resolve-PowerShellExe {
    if ($PSVersionTable.PSEdition -eq "Core") {
        return "pwsh"
    }
    return Join-Path $PSHOME "powershell.exe"
}

function Get-JsonProp {
    param(
        $Object,
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $prop = $Object.PSObject.Properties |
        Where-Object { $_.Name -ieq $Name } |
        Select-Object -First 1
    if ($null -eq $prop) {
        return $Default
    }
    return $prop.Value
}

function Get-JsonInt {
    param(
        $Object,
        [string]$Name,
        [int]$Default = 0
    )

    $value = Get-JsonProp $Object $Name $null
    if ($null -eq $value) {
        return $Default
    }
    return [int]$value
}

function Get-SmokeArgValue {
    param(
        [string[]]$Arguments,
        [string]$Name,
        [string]$Default = ""
    )

    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        if ($Arguments[$i] -ieq $Name -and ($i + 1) -lt $Arguments.Count) {
            return $Arguments[$i + 1]
        }
    }
    return $Default
}

function Set-ValueArg {
    param(
        [string[]]$Arguments,
        [string]$Name,
        [string]$Value
    )

    $result = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        if ($Arguments[$i] -ieq $Name) {
            if (($i + 1) -lt $Arguments.Count) {
                $i++
            }
            continue
        }
        $result.Add($Arguments[$i])
    }
    $result.Add($Name)
    $result.Add($Value)
    return [string[]]$result.ToArray()
}

function Set-SwitchArg {
    param(
        [string[]]$Arguments,
        [string]$Name,
        [bool]$Present
    )

    $result = New-Object System.Collections.Generic.List[string]
    foreach ($arg in $Arguments) {
        if ($arg -ieq $Name) {
            continue
        }
        $result.Add($arg)
    }
    if ($Present) {
        $result.Add($Name)
    }
    return [string[]]$result.ToArray()
}

function Convert-SafeName {
    param([string]$Name)

    return ($Name -replace "[^A-Za-z0-9_.-]", "_")
}

function Format-CommandArg {
    param([string]$Arg)

    if ($Arg -match '[\s;"]') {
        return '"' + ($Arg -replace '"', '\"') + '"'
    }
    return $Arg
}

function Format-CommandLine {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    $parts = @((Format-CommandArg $Command))
    foreach ($arg in $Arguments) {
        $parts += (Format-CommandArg $arg)
    }
    return ($parts -join " ")
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Text
    )

    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Add-TextLine {
    param(
        [string]$Path,
        [string]$Text
    )

    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::AppendAllText($Path, $Text + [Environment]::NewLine, $encoding)
}

function Invoke-LoggedTool {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [string]$LogFile
    )

    $cmdLine = Format-CommandLine $Command $Arguments
    Write-Host "PS> $cmdLine"
    Add-TextLine $LogFile "PS> $cmdLine"
    $output = & $Command @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    foreach ($line in @($output)) {
        Add-TextLine $LogFile ([string]$line)
    }
    return $exitCode
}

$CasesManifest = Resolve-RepoPath $CasesManifest
if (-not (Test-Path -LiteralPath $CasesManifest -PathType Leaf)) {
    throw "Cases manifest not found: $CasesManifest"
}

$PowerShellExe = Resolve-PowerShellExe
$caseConfig = Get-Content -LiteralPath $CasesManifest -Raw | ConvertFrom-Json
$cases = @(Get-JsonProp $caseConfig "cases" @())
if ($cases.Count -eq 0) {
    throw "No cases found in manifest: $CasesManifest"
}

if (-not $DryRun) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$results = New-Object System.Collections.Generic.List[object]
$startTime = Get-Date
$caseIndex = 0
$stoppedEarly = $false

foreach ($case in $cases) {
    $caseName = [string](Get-JsonProp $case "name" ("case_$caseIndex"))
    $safeCaseName = Convert-SafeName $caseName
    $caseDir = Join-Path $OutDir ("{0:D3}_{1}" -f $caseIndex, $safeCaseName)
    $caseLog = Join-Path $caseDir "smoke_wrapper.log"
    $caseResultPath = Join-Path $caseDir "case_result.json"
    $caseUcdb = Join-Path $caseDir "$safeCaseName.ucdb"
    $caseVsimLog = Join-Path $caseDir "vsim.log"

    $smoke = Get-JsonProp $case "smoke_ps1" $null
    if ($null -eq $smoke) {
        throw "Case $caseName has no smoke_ps1 section"
    }

    $rawArgs = @(Get-JsonProp $smoke "args" @())
    if ($rawArgs.Count -eq 0) {
        throw "Case $caseName has no smoke_ps1.args"
    }

    $smokeArgs = @()
    foreach ($arg in $rawArgs) {
        $smokeArgs += [string]$arg
    }

    $future = Get-JsonProp $smoke "future_plusargs" $null
    $seed = Get-JsonInt $future "ntb_random_seed" (Get-JsonInt $case "seed" 1)
    $sourceGapMax = Get-JsonInt $future "ITA_SOURCE_GAP_MAX" 0
    $inputSourceGapMax = Get-JsonInt $future "ITA_INPUT_SOURCE_GAP_MAX" $sourceGapMax
    $weightSourceGapMax = Get-JsonInt $future "ITA_WEIGHT_SOURCE_GAP_MAX" $sourceGapMax
    $biasSourceGapMax = Get-JsonInt $future "ITA_BIAS_SOURCE_GAP_MAX" $sourceGapMax
    $groupIdleGapMax = Get-JsonInt $future "ITA_GROUP_IDLE_GAP_MAX" 0
    $readyLowMax = Get-JsonInt $future "ITA_READY_LOW_MAX" 0
    $readyHighMax = Get-JsonInt $future "ITA_READY_HIGH_MAX" 1
    $expectFail = [bool](Get-JsonProp $case "expect_fail" $false)
    $expectedErrorRegex = [string](Get-JsonProp $case "expected_error_regex" "")

    if ($QuestaBin -ne "") {
        $smokeArgs = Set-ValueArg $smokeArgs "-QuestaBin" $QuestaBin
    }
    if ($UvmHome -ne "") {
        $smokeArgs = Set-ValueArg $smokeArgs "-UvmHome" $UvmHome
    }
    $smokeArgs = Set-ValueArg $smokeArgs "-Python" $Python
    $smokeArgs = Set-ValueArg $smokeArgs "-UvmSeed" ([string]$seed)
    $smokeArgs = Set-ValueArg $smokeArgs "-SourceGapMax" ([string]$sourceGapMax)
    $smokeArgs = Set-ValueArg $smokeArgs "-InputSourceGapMax" ([string]$inputSourceGapMax)
    $smokeArgs = Set-ValueArg $smokeArgs "-WeightSourceGapMax" ([string]$weightSourceGapMax)
    $smokeArgs = Set-ValueArg $smokeArgs "-BiasSourceGapMax" ([string]$biasSourceGapMax)
    $smokeArgs = Set-ValueArg $smokeArgs "-GroupIdleGapMax" ([string]$groupIdleGapMax)
    $smokeArgs = Set-ValueArg $smokeArgs "-ReadyLowMax" ([string]$readyLowMax)
    $smokeArgs = Set-ValueArg $smokeArgs "-ReadyHighMax" ([string]$readyHighMax)
    $smokeArgs = Set-SwitchArg $smokeArgs "-EnableCoverage" $true
    $smokeArgs = Set-ValueArg $smokeArgs "-CoverageUcdb" $caseUcdb
    if ($DryRun) {
        $smokeArgs = Set-SwitchArg $smokeArgs "-DryRun" $true
    }

    $testName = Get-SmokeArgValue $smokeArgs "-TestName" "ita_mha8_base_test"
    $status = "PASS"
    $exitCode = 0
    $failureMessage = ""
    $matchedExpectedError = $false

    Write-Host ("[{0}/{1}] {2}" -f ($caseIndex + 1), $cases.Count, $caseName)

    if ($DryRun) {
        $processArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $SmokeScript) + $smokeArgs
        Write-Host ("PS> " + (Format-CommandLine $PowerShellExe $processArgs))
        & $PowerShellExe @processArgs
        $status = "DRYRUN"
    } else {
        New-Item -ItemType Directory -Path $caseDir -Force | Out-Null
        $processArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $SmokeScript) + $smokeArgs
        Write-Utf8File $caseLog ("PS> " + (Format-CommandLine $PowerShellExe $processArgs) + [Environment]::NewLine)
        try {
            $output = & $PowerShellExe @processArgs 2>&1
            foreach ($line in @($output)) {
                Add-TextLine $caseLog ([string]$line)
            }
            if ($LASTEXITCODE -ne 0) {
                $exitCode = $LASTEXITCODE
                throw "smoke.ps1 failed with exit code $exitCode"
            }
        } catch {
            $status = "FAIL"
            if ($exitCode -eq 0) {
                $exitCode = 1
            }
            $failureMessage = $_.Exception.Message
            Add-TextLine $caseLog ("FAILED: " + $failureMessage)
        }

        $sourceVsimLog = Join-Path $SimLogDir "$testName.log"
        if (Test-Path -LiteralPath $sourceVsimLog -PathType Leaf) {
            Copy-Item -LiteralPath $sourceVsimLog -Destination $caseVsimLog -Force
        }

        if ($expectFail) {
            if ($exitCode -eq 0) {
                $status = "FAIL"
                $failureMessage = "Expected failure but smoke.ps1 exited 0"
            } else {
                $logText = ""
                if (Test-Path -LiteralPath $caseLog -PathType Leaf) {
                    $logText = Get-Content -LiteralPath $caseLog -Raw
                }
                if ($expectedErrorRegex -eq "" -or [regex]::IsMatch($logText, $expectedErrorRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
                    $matchedExpectedError = $true
                    $status = "PASS"
                } else {
                    $status = "FAIL"
                    $failureMessage = "Expected failure did not match regex: $expectedErrorRegex"
                }
            }
        }
    }

    $paths = Get-JsonProp $case "paths" $null
    $manifestPath = Resolve-RepoPath ([string](Get-JsonProp $paths "uvm_manifest" ""))
    $ucdbExists = (Test-Path -LiteralPath $caseUcdb -PathType Leaf)

    $result = [ordered]@{
        name = $caseName
        category = [string](Get-JsonProp $case "category" "")
        spec_basis = [string](Get-JsonProp $case "spec_basis" "")
        status = $status
        exit_status = $exitCode
        seed = $seed
        projection = [string](Get-JsonProp $case "projection" "")
        activation = [string](Get-JsonProp $case "activation" "")
        tile_s = Get-JsonInt $case "tile_s" 0
        tile_e = Get-JsonInt $case "tile_e" 0
        tile_p = Get-JsonInt $case "tile_p" 0
        tile_f = Get-JsonInt $case "tile_f" 0
        source_gap_max = $sourceGapMax
        input_source_gap_max = $inputSourceGapMax
        weight_source_gap_max = $weightSourceGapMax
        bias_source_gap_max = $biasSourceGapMax
        group_idle_gap_max = $groupIdleGapMax
        ready_low_max = $readyLowMax
        ready_high_max = $readyHighMax
        expect_fail = $expectFail
        expected_error_regex = $expectedErrorRegex
        matched_expected_error = $matchedExpectedError
        log_path = $caseLog
        vsim_log_path = $caseVsimLog
        manifest_path = $manifestPath
        ucdb_path = $caseUcdb
        ucdb_exists = $ucdbExists
        failure_message = $failureMessage
    }
    $results.Add([pscustomobject]$result)

    if (-not $DryRun) {
        Write-Utf8File $caseResultPath (($result | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
    }

    if ($status -eq "FAIL" -and $StopOnFirstFail) {
        $stoppedEarly = $true
        break
    }

    $caseIndex++
}

if ($stoppedEarly -and ($caseIndex + 1) -lt $cases.Count) {
    for ($skipIndex = $caseIndex + 1; $skipIndex -lt $cases.Count; $skipIndex++) {
        $skippedCase = $cases[$skipIndex]
        $skippedName = [string](Get-JsonProp $skippedCase "name" ("case_$skipIndex"))
        $results.Add([pscustomobject][ordered]@{
            name = $skippedName
            category = [string](Get-JsonProp $skippedCase "category" "")
            spec_basis = [string](Get-JsonProp $skippedCase "spec_basis" "")
            status = "SKIPPED"
            exit_status = 0
            seed = Get-JsonInt $skippedCase "seed" 0
            projection = [string](Get-JsonProp $skippedCase "projection" "")
            activation = [string](Get-JsonProp $skippedCase "activation" "")
            tile_s = Get-JsonInt $skippedCase "tile_s" 0
            tile_e = Get-JsonInt $skippedCase "tile_e" 0
            tile_p = Get-JsonInt $skippedCase "tile_p" 0
            tile_f = Get-JsonInt $skippedCase "tile_f" 0
            source_gap_max = 0
            input_source_gap_max = 0
            weight_source_gap_max = 0
            bias_source_gap_max = 0
            group_idle_gap_max = 0
            ready_low_max = 0
            ready_high_max = 0
            expect_fail = [bool](Get-JsonProp $skippedCase "expect_fail" $false)
            expected_error_regex = [string](Get-JsonProp $skippedCase "expected_error_regex" "")
            matched_expected_error = $false
            log_path = ""
            vsim_log_path = ""
            manifest_path = ""
            ucdb_path = ""
            ucdb_exists = $false
            failure_message = "Skipped after first failure"
        })
    }
}

$endTime = Get-Date
$elapsed = $endTime - $startTime
$passCount = @($results | Where-Object { $_.status -eq "PASS" }).Count
$failCount = @($results | Where-Object { $_.status -eq "FAIL" }).Count
$skipCount = @($results | Where-Object { $_.status -eq "SKIPPED" }).Count
$dryRunCount = @($results | Where-Object { $_.status -eq "DRYRUN" }).Count
$xfailPassCount = @($results | Where-Object { $_.expect_fail -and $_.status -eq "PASS" }).Count

$categorySummary = New-Object System.Collections.Specialized.OrderedDictionary
foreach ($result in $results) {
    $category = [string]$result.category
    if ($category -eq "") {
        $category = "uncategorized"
    }
    if (-not $categorySummary.Contains($category)) {
        $categorySummary.Add($category, [ordered]@{
            total = 0
            pass = 0
            fail = 0
            skipped = 0
            dryrun = 0
            xfail_pass = 0
        })
    }
    $bucket = $categorySummary[$category]
    $bucket["total"]++
    if ($result.status -eq "PASS") { $bucket["pass"]++ }
    if ($result.status -eq "FAIL") { $bucket["fail"]++ }
    if ($result.status -eq "SKIPPED") { $bucket["skipped"]++ }
    if ($result.status -eq "DRYRUN") { $bucket["dryrun"]++ }
    if ($result.expect_fail -and $result.status -eq "PASS") { $bucket["xfail_pass"]++ }
}

$coverage = [ordered]@{
    status = if ($DryRun) { "DRYRUN" } else { "SKIPPED" }
    input_count = 0
    excluded_xfail_ucdb = 0
    merged_ucdb = ""
    report = ""
    text_report = ""
    html_report = ""
    merge_log = ""
    failure_message = ""
}

if (-not $DryRun) {
    $passUcdbs = @($results | Where-Object { $_.status -eq "PASS" -and -not $_.expect_fail -and $_.ucdb_exists } | ForEach-Object { $_.ucdb_path })
    $xfailUcdbs = @($results | Where-Object { $_.status -eq "PASS" -and $_.expect_fail -and $_.ucdb_exists } | ForEach-Object { $_.ucdb_path })
    $coverage.input_count = $passUcdbs.Count
    $coverage.excluded_xfail_ucdb = $xfailUcdbs.Count
    if ($passUcdbs.Count -gt 0) {
        $coverageDir = Join-Path $OutDir "coverage"
        New-Item -ItemType Directory -Path $coverageDir -Force | Out-Null
        $mergedUcdb = Join-Path $coverageDir "random_mha8_merged.ucdb"
        $coverageReport = Join-Path $coverageDir "coverage_report.txt"
        $coverageHtmlReport = Join-Path $coverageDir "coverage_html"
        $coverageLog = Join-Path $coverageDir "vcover.log"
        $vcover = Resolve-Tool "vcover.exe"

        try {
            Write-Utf8File $coverageLog ""
            $mergeArgs = @("merge", $mergedUcdb) + $passUcdbs
            $mergeExit = Invoke-LoggedTool $vcover $mergeArgs $coverageLog
            if ($mergeExit -ne 0) {
                throw "vcover merge failed with exit code $mergeExit"
            }

            $reportArgs = @("report", "-details", "-output", $coverageReport, $mergedUcdb)
            $reportExit = Invoke-LoggedTool $vcover $reportArgs $coverageLog
            if ($reportExit -ne 0) {
                throw "vcover report failed with exit code $reportExit"
            }

            $htmlReportArgs = @("report", "-html", "-details", "-output", $coverageHtmlReport, $mergedUcdb)
            $htmlReportExit = Invoke-LoggedTool $vcover $htmlReportArgs $coverageLog
            if ($htmlReportExit -ne 0) {
                throw "vcover html report failed with exit code $htmlReportExit"
            }

            $coverage.status = "PASS"
            $coverage.merged_ucdb = $mergedUcdb
            $coverage.report = $coverageReport
            $coverage.text_report = $coverageReport
            $coverage.html_report = $coverageHtmlReport
            $coverage.merge_log = $coverageLog
        } catch {
            $coverage.status = "FAIL"
            $coverage.merged_ucdb = $mergedUcdb
            $coverage.report = $coverageReport
            $coverage.text_report = $coverageReport
            $coverage.html_report = $coverageHtmlReport
            $coverage.merge_log = $coverageLog
            $coverage.failure_message = $_.Exception.Message
        }
    }
}

$summary = New-Object System.Collections.Specialized.OrderedDictionary
$summary.Add("name", "random_mha8_regression")
$summary.Add("cases_manifest", $CasesManifest)
$summary.Add("out_dir", $OutDir)
$summary.Add("start_time", $startTime.ToString("o"))
$summary.Add("end_time", $endTime.ToString("o"))
$summary.Add("elapsed_seconds", [math]::Round($elapsed.TotalSeconds, 3))
$summary.Add("total", $results.Count)
$summary.Add("pass", $passCount)
$summary.Add("fail", $failCount)
$summary.Add("skipped", $skipCount)
$summary.Add("dryrun", $dryRunCount)
$summary.Add("xfail_pass", $xfailPassCount)
$summary.Add("by_category", $categorySummary)
$summary.Add("coverage_merge", $coverage)
$caseResults = $results.ToArray()
$summary.Add("cases", [object]$caseResults)

$summaryJsonPath = Join-Path $OutDir "regression_summary.json"
$summaryTxtPath = Join-Path $OutDir "regression_summary.txt"

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add("Random MHA8 Regression Summary")
$summaryLines.Add("manifest=$CasesManifest")
$summaryLines.Add("out_dir=$OutDir")
$summaryLines.Add("total=$($summary["total"]) pass=$passCount fail=$failCount skipped=$skipCount dryrun=$dryRunCount xfail_pass=$xfailPassCount elapsed_s=$($summary["elapsed_seconds"])")
$summaryLines.Add("by_category=" + (($categorySummary.GetEnumerator() | ForEach-Object {
    "$($_.Key):total=$($_.Value["total"]),pass=$($_.Value["pass"]),fail=$($_.Value["fail"]),skipped=$($_.Value["skipped"]),dryrun=$($_.Value["dryrun"]),xfail_pass=$($_.Value["xfail_pass"])"
}) -join "; "))
$summaryLines.Add("coverage_merge=$($coverage.status) input_ucdb=$($coverage.input_count)")
$summaryLines.Add("coverage_excluded_xfail_ucdb=$($coverage.excluded_xfail_ucdb)")
if ($coverage.merged_ucdb -ne "") { $summaryLines.Add("merged_ucdb=$($coverage.merged_ucdb)") }
if ($coverage.text_report -ne "") { $summaryLines.Add("coverage_text_report=$($coverage.text_report)") }
if ($coverage.html_report -ne "") { $summaryLines.Add("coverage_html_report=$($coverage.html_report)") }
if ($coverage.failure_message -ne "") { $summaryLines.Add("coverage_failure=$($coverage.failure_message)") }
$summaryLines.Add("")
foreach ($result in $results) {
    $displayStatus = $result.status
    if ($result.expect_fail -and $result.status -eq "PASS") {
        $displayStatus = "XFAIL_PASS"
    }
    $line = "{0} category={1} seed={2} projection={3} activation={4} tiles={5}/{6}/{7}/{8} gap={9} group_gap={10} ready_low={11} ready_high={12}" -f `
        $displayStatus, $result.category, $result.seed, $result.projection, $result.activation, `
        $result.tile_s, $result.tile_e, $result.tile_p, $result.tile_f, `
        $result.source_gap_max, $result.group_idle_gap_max, $result.ready_low_max, $result.ready_high_max
    if ($result.failure_message -ne "") {
        $line += " failure=" + $result.failure_message
    }
    $line += " name=" + $result.name
    $summaryLines.Add($line)
}

Write-Host ""
foreach ($line in $summaryLines) {
    Write-Host $line
}

if (-not $DryRun) {
    Write-Utf8File $summaryJsonPath (($summary | ConvertTo-Json -Depth 12) + [Environment]::NewLine)
    Write-Utf8File $summaryTxtPath (($summaryLines -join [Environment]::NewLine) + [Environment]::NewLine)
    Write-Host ""
    Write-Host "Summary JSON: $summaryJsonPath"
    Write-Host "Summary TXT : $summaryTxtPath"
}

if ($DryRun) {
    exit 0
}
if ($failCount -gt 0 -or $coverage.status -eq "FAIL") {
    exit 1
}
exit 0
