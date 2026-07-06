param(
    [string]$TestName = "ita_mha8_base_test",
    [string]$QuestaBin = "",
    [string]$UvmHome = $env:UVM_HOME,
    [string]$Python = "python",
    [int]$Heads = 8,
    [ValidateSet("synthetic", "pyita-q")]
    [string]$VectorSource = "synthetic",
    [ValidateSet("Q", "K", "V", "QKV", "ATTN", "ATTNFF")]
    [string]$Projection = "Q",
    [ValidateSet("Auto", "Identity", "Relu", "Gelu")]
    [string]$Activation = "Auto",
    [string]$PyitaDir = "",
    [string]$Manifest = "",
    [string]$StreamName = "",
    [string]$ManifestName = "",
    [string]$RequantName = "",
    [int]$SourceGapMax = 0,
    [int]$InputSourceGapMax = -1,
    [int]$WeightSourceGapMax = -1,
    [int]$BiasSourceGapMax = -1,
    [int]$LockstepIdleGapMax = 0,
    [int]$ReadyLowMax = 0,
    [int]$ReadyHighMax = 0,
    [int]$UvmSeed = 1,
    [string]$TileSOverride = "",
    [string]$TileEOverride = "",
    [string]$TilePOverride = "",
    [string]$TileFOverride = "",
    [switch]$EnableCoverage,
    [string]$CoverageUcdb = "",
    [switch]$GenerateVectors,
    [switch]$NoGenerateVectors,
    [switch]$CompareLinear,
    [switch]$NoCompare,
    [switch]$NoAutoVectorFlow,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SimDir = Split-Path -Parent $ScriptDir
$CoreDir = Split-Path -Parent $SimDir
$WorkspaceDir = Split-Path -Parent $CoreDir
$OutputDir = Join-Path $SimDir "output"
$LogDir = Join-Path $OutputDir "logs"
$LoggerDir = Join-Path $SimDir "logger"
$ToolsDir = Join-Path $CoreDir "tb\tools"
$Transcript = Join-Path $LogDir "$TestName.log"

function Resolve-Tool {
    param([string]$Name)
    if ($QuestaBin -ne "") {
        return Join-Path $QuestaBin $Name
    }
    return $Name
}

function Resolve-RepoPath {
    param([string]$PathText)
    if ($PathText -eq "") {
        return ""
    }
    if ([System.IO.Path]::IsPathRooted($PathText)) {
        return $PathText
    }

    $workspaceCandidate = Join-Path $WorkspaceDir $PathText
    if ((Test-Path $workspaceCandidate) -or $DryRun) {
        return $workspaceCandidate
    }

    return Join-Path $CoreDir $PathText
}

function Invoke-Step {
    param(
        [string]$Command,
        [string[]]$Arguments
    )
    Write-Host ("PS> " + $Command + " " + ($Arguments -join " "))
    if (-not $DryRun) {
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE"
        }
    }
}

function Invoke-PythonStep {
    param(
        [string]$Script,
        [string[]]$Arguments
    )
    $allArgs = @($Script) + $Arguments
    Invoke-Step $Python $allArgs
}

$IsLinearDirected = ($TestName -eq "ita_mha8_linear_directed_test")
$IsQDirected = ($TestName -eq "ita_mha8_q_directed_test")
$IsQkvDirected = ($TestName -eq "ita_mha8_qkv_directed_test")
$IsAttnDirected = ($TestName -eq "ita_mha8_attn_directed_test")
$AutoVectorFlow = (($IsLinearDirected -or $IsQDirected -or $IsQkvDirected -or $IsAttnDirected) -and -not $NoAutoVectorFlow)
$RunGenerateVectors = (($GenerateVectors -or $AutoVectorFlow) -and -not $NoGenerateVectors)
$RunCompareLinear = (($CompareLinear -or $AutoVectorFlow) -and -not $NoCompare)

if ($Heads -le 0 -or $Heads -gt 8) {
    throw "-Heads must be in the range 1..8"
}

if ($InputSourceGapMax -lt 0) {
    $InputSourceGapMax = $SourceGapMax
}
if ($WeightSourceGapMax -lt 0) {
    $WeightSourceGapMax = $SourceGapMax
}
if ($BiasSourceGapMax -lt 0) {
    $BiasSourceGapMax = $SourceGapMax
}

if ($StreamName -eq "") {
    if ($VectorSource -eq "pyita-q") {
        $ProjectionLower = $Projection.ToLowerInvariant()
        $StreamName = "uvm_pyita_${ProjectionLower}_mha8_stream.csv"
    } else {
        $StreamName = "uvm_linear_mha8_stream.csv"
    }
}

if ($ManifestName -eq "") {
    if ($VectorSource -eq "pyita-q") {
        $ProjectionLower = $Projection.ToLowerInvariant()
        $ManifestName = "uvm_pyita_${ProjectionLower}_mha8_manifest.json"
    } else {
        $ManifestName = "uvm_linear_mha8_manifest.json"
    }
}

if ($RequantName -eq "") {
    if ($VectorSource -eq "pyita-q") {
        $ProjectionLower = $Projection.ToLowerInvariant()
        $RequantName = "uvm_pyita_${ProjectionLower}_mha8_requant.csv"
    }
}

if ($Manifest -eq "") {
    $ManifestPath = Join-Path $LoggerDir $ManifestName
} else {
    $ManifestPath = $Manifest
    if (-not [System.IO.Path]::IsPathRooted($ManifestPath)) {
        $ManifestPath = Join-Path $CoreDir $ManifestPath
    }
}

if (-not $DryRun) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    New-Item -ItemType Directory -Path $LoggerDir -Force | Out-Null
}

$VectorOutDir = Split-Path -Parent $ManifestPath
$StreamPath = Join-Path $VectorOutDir $StreamName
$RequantPath = ""
$TileS = 1
$TileE = 1
$TileP = 1
$TileF = 1
$VsimTileS = 1
$VsimTileE = 1
$VsimTileP = 1
$VsimTileF = 1
$ResolvedActivation = "Identity"
if ($Activation -ne "Auto") {
    $ResolvedActivation = $Activation
}
if ([System.IO.Path]::GetFullPath($VectorOutDir) -eq [System.IO.Path]::GetFullPath($LoggerDir)) {
    $StreamPlusArg = "logger/$StreamName"
    if ($RequantName -ne "") {
        $RequantPlusArg = "logger/$RequantName"
    } else {
        $RequantPlusArg = ""
    }
} else {
    $StreamPlusArg = $StreamPath
    if ($RequantName -ne "") {
        $RequantPath = Join-Path $VectorOutDir $RequantName
        $RequantPlusArg = $RequantPath
    } else {
        $RequantPlusArg = ""
    }
}

if ($RunGenerateVectors) {
    if ($VectorSource -eq "pyita-q") {
        if ($PyitaDir -eq "") {
            throw "-PyitaDir is required when -VectorSource pyita-q generates vectors"
        }
        $DutStep = "MatMul"
        if ($IsQDirected -or $IsQkvDirected -or $IsAttnDirected) {
            $DutStep = $Projection
        }
        $ResolvedPyitaDir = Resolve-RepoPath $PyitaDir
        $PyitaCaseDir = Split-Path -Parent $ResolvedPyitaDir
        $PyitaCaseName = Split-Path -Leaf $PyitaCaseDir
        if ($PyitaCaseName -match "data_S(?<S>\d+)_E(?<E>\d+)_P(?<P>\d+)_F(?<F>\d+)") {
            $TileS = [int]([int]$Matches.S / 64)
            $TileE = [int]([int]$Matches.E / 64)
            $TileP = [int]([int]$Matches.P / 64)
            $TileF = [int]([int]$Matches.F / 64)
            if ($TileS -le 0 -or $TileE -le 0 -or $TileP -le 0 -or $TileF -le 0) {
                throw "Invalid tile dimensions derived from $PyitaCaseName"
            }
        }
        if ($Activation -eq "Auto") {
            if ($PyitaCaseName -match "_Relu") {
                $ResolvedActivation = "Relu"
            } elseif ($PyitaCaseName -match "_Gelu") {
                $ResolvedActivation = "Gelu"
            } else {
                $ResolvedActivation = "Identity"
            }
        } else {
            $ResolvedActivation = $Activation
        }
        $genArgs = @(
            "--pyita-dir", $ResolvedPyitaDir,
            "--projection", $Projection,
            "--heads", [string]$Heads,
            "--out-dir", $VectorOutDir,
            "--stream-name", $StreamName,
            "--requant-name", $RequantName,
            "--manifest-name", (Split-Path -Leaf $ManifestPath),
            "--dut-step", $DutStep,
            "--tile-s", [string]$TileS,
            "--tile-e", [string]$TileE,
            "--tile-p", [string]$TileP,
            "--tile-f", [string]$TileF,
            "--activation", $ResolvedActivation
        )
        if ($Projection -ne "QKV" -and $Projection -ne "ATTN" -and $Projection -ne "ATTNFF") {
            $genArgs += @("--source-step", $Projection)
        }
        Invoke-PythonStep (Join-Path $ToolsDir "gen_mha8_pyita_vectors.py") $genArgs
    } else {
        if ($IsQDirected -or $IsQkvDirected -or $IsAttnDirected) {
            throw "$TestName requires -VectorSource pyita-q"
        }
        Invoke-PythonStep (Join-Path $ToolsDir "gen_mha8_vectors.py") @(
            "--heads", [string]$Heads,
            "--out-dir", $VectorOutDir,
            "--stream-name", $StreamName,
            "--manifest-name", (Split-Path -Leaf $ManifestPath)
        )
    }
}

& (Join-Path $ScriptDir "compile.ps1") -QuestaBin $QuestaBin -UvmHome $UvmHome -DryRun:$DryRun

$VsimTileS = $TileS
$VsimTileE = $TileE
$VsimTileP = $TileP
$VsimTileF = $TileF
if ($TileSOverride -ne "") {
    $VsimTileS = [int]$TileSOverride
}
if ($TileEOverride -ne "") {
    $VsimTileE = [int]$TileEOverride
}
if ($TilePOverride -ne "") {
    $VsimTileP = [int]$TilePOverride
}
if ($TileFOverride -ne "") {
    $VsimTileF = [int]$TileFOverride
}

$vsim = Resolve-Tool "vsim.exe"
$CoverageEnabled = ($EnableCoverage -or $CoverageUcdb -ne "")
$vsimArgs = @(
    "-c",
    "-lib", "work",
    "ita_mha8_tb_top",
    "+UVM_TESTNAME=$TestName",
    "+ntb_random_seed=$UvmSeed",
    "+ITA_SOURCE_GAP_ENABLE=1",
    "+ITA_SOURCE_GAP_MIN=0",
    "+ITA_SOURCE_GAP_MAX=$SourceGapMax",
    "+ITA_INPUT_SOURCE_GAP_MIN=0",
    "+ITA_INPUT_SOURCE_GAP_MAX=$InputSourceGapMax",
    "+ITA_WEIGHT_SOURCE_GAP_MIN=0",
    "+ITA_WEIGHT_SOURCE_GAP_MAX=$WeightSourceGapMax",
    "+ITA_BIAS_SOURCE_GAP_MIN=0",
    "+ITA_BIAS_SOURCE_GAP_MAX=$BiasSourceGapMax",
    "+ITA_LOCKSTEP_IDLE_GAP_MIN=0",
    "+ITA_LOCKSTEP_IDLE_GAP_MAX=$LockstepIdleGapMax",
    "+ITA_ASSERT_LEGAL_LOCKSTEP_INPUT=1",
    "+ITA_SINK_BP_ENABLE=1",
    "+ITA_READY_LOW_MIN=0",
    "+ITA_READY_LOW_MAX=$ReadyLowMax",
    "+ITA_READY_HIGH_MIN=1",
    "+ITA_READY_HIGH_MAX=$ReadyHighMax"
)

if ($CoverageEnabled) {
    $vsimArgs += "-coverage"
}

if (($IsLinearDirected -or $IsQDirected -or $IsQkvDirected -or $IsAttnDirected) -and -not $NoAutoVectorFlow) {
    $vsimArgs += "+ITA_STREAM_CSV=$StreamPlusArg"
    if (($IsQDirected -or $IsQkvDirected -or $IsAttnDirected) -and $VectorSource -eq "pyita-q" -and $RequantPlusArg -ne "") {
        if ($IsQDirected) {
            $vsimArgs += "+ITA_DIRECTED_STEP=$Projection"
        }
        $vsimArgs += "+ITA_REQUANT_CSV=$RequantPlusArg"
        $vsimArgs += "+ITA_TILE_S=$VsimTileS"
        $vsimArgs += "+ITA_TILE_E=$VsimTileE"
        $vsimArgs += "+ITA_TILE_P=$VsimTileP"
        $vsimArgs += "+ITA_TILE_F=$VsimTileF"
        $vsimArgs += "+ITA_ACTIVATION=$ResolvedActivation"
    }
}
$DoCommand = "run -all; quit -f"
if ($CoverageUcdb -ne "") {
    $CoverageTclPath = $CoverageUcdb.Replace("\", "/")
    $DoCommand = "coverage save -onexit `"$CoverageTclPath`"; run -all; quit -f"
}

$vsimArgs += @(
    "-do", $DoCommand,
    "-l", $Transcript
)

Push-Location $SimDir
try {
    Invoke-Step $vsim $vsimArgs
}
finally {
    Pop-Location
}

if (-not $DryRun -and (Test-Path $Transcript)) {
    $uvmFailure = Select-String -Path $Transcript -Pattern "UVM_(ERROR|FATAL)\s*:\s*[1-9][0-9]*" | Select-Object -First 1
    if ($null -ne $uvmFailure) {
        throw "Simulation reported UVM error/fatal; see $Transcript"
    }
}

if ($RunCompareLinear) {
    Invoke-PythonStep (Join-Path $ToolsDir "compare_mha8_manifest.py") @(
        "--manifest", $ManifestPath
    )
}
