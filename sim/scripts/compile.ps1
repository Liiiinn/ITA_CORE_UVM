param(
    [string]$QuestaBin = "",
    [string]$UvmHome = $env:UVM_HOME,
    [switch]$EnableCodeCoverage,
    [string]$CodeCoverageSpec = "sbceft",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SimDir = Split-Path -Parent $ScriptDir
$RepoRoot = Split-Path -Parent $SimDir
$OutputDir = Join-Path $SimDir "output"
$WorkDir = Join-Path $OutputDir "work"
$LogDir = Join-Path $OutputDir "logs"
$FileList = Join-Path $SimDir "filelist.f"

function Resolve-Tool {
    param([string]$Name)
    if ($QuestaBin -ne "") {
        return Join-Path $QuestaBin $Name
    }
    return $Name
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

if (-not (Test-Path -LiteralPath $FileList -PathType Leaf)) {
    throw "Missing filelist: $FileList"
}

if (-not $DryRun) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$vlib = Resolve-Tool "vlib.exe"
$vmap = Resolve-Tool "vmap.exe"
$vlog = Resolve-Tool "vlog.exe"

Push-Location $SimDir
try {
    Invoke-Step $vlib @($WorkDir)
    Invoke-Step $vmap @("work", $WorkDir)

    $vlogArgs = @("-sv", "-work", "work", "+acc")
    if ($EnableCodeCoverage) {
        if ($CodeCoverageSpec -notmatch "^[sbceftx]+$") {
            throw "Invalid -CodeCoverageSpec '$CodeCoverageSpec'; expected a combination of s,b,c,e,f,t,x"
        }
        $vlogArgs += "+cover=$CodeCoverageSpec"
    }

    if ($UvmHome) {
        $UvmPkg = Join-Path $UvmHome "src/uvm_pkg.sv"
        $UvmInc = Join-Path $UvmHome "src"
        if (Test-Path -LiteralPath $UvmPkg -PathType Leaf) {
            $vlogArgs += "+incdir+$UvmInc"
            $vlogArgs += $UvmPkg
        }
    }

    $vlogArgs += @("-f", $FileList)
    Invoke-Step $vlog $vlogArgs
}
finally {
    Pop-Location
}
