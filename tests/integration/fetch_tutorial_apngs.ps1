#!/usr/bin/env pwsh
# fetch_tutorial_apngs.ps1 — pull tutorial APNGs from origin/assets into
# doc/source/_static/tutorials/.
#
# The APNGs live on an orphan `assets` branch (single force-amend-pushed
# commit) so the source-repo history doesn't accumulate hundreds of MB per
# re-record sweep. Every sphinx build needs the binaries on disk; this
# script is the bridge.
#
# Idempotent — re-runs are cheap (git fetch is incremental, checkout just
# overwrites). Safe to run unconditionally before sphinx-build.
#
# Run from anywhere:
#   pwsh modules/dasImgui/tests/integration/fetch_tutorial_apngs.ps1
#
# Flags:
#   -Remote <name>   Defaults to `origin`. Override if your remote is named
#                    differently (e.g. `upstream`).
#   -Quiet           Suppress per-file output; only print summary.

param(
    [string]$Remote = "origin",
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$tutorialDir = Join-Path $repoRoot "doc\source\_static\tutorials"

if (-not $Quiet) {
    Write-Host "[fetch_tutorial_apngs] remote: $Remote"
    Write-Host "[fetch_tutorial_apngs] target: $tutorialDir"
}

Set-Location $repoRoot

# Fetch the assets branch ref. --depth 1 keeps the local clone small.
git fetch --depth 1 $Remote assets 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: git fetch ${Remote}/assets failed" -ForegroundColor Red
    exit 1
}

# Make sure the directory exists; otherwise `git checkout` will create it.
New-Item -ItemType Directory -Force -Path $tutorialDir | Out-Null

# Checkout the .apng files from FETCH_HEAD into the working tree. Restricting
# the pathspec to *.apng leaves the orphan branch's README.md alone (we
# don't want it bleeding into the source tree).
git checkout FETCH_HEAD -- doc/source/_static/tutorials/*.apng
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: git checkout assets-branch APNGs failed" -ForegroundColor Red
    exit 1
}

# Unstage them so they don't appear in `git diff` -- they're .gitignored
# but git checkout from a ref stages them anyway.
git reset HEAD -- doc/source/_static/tutorials/*.apng 2>&1 | Out-Null

$count = (Get-ChildItem $tutorialDir -Filter "*.apng" | Measure-Object).Count
$totalMB = [math]::Round(((Get-ChildItem $tutorialDir -Filter "*.apng" | Measure-Object Length -Sum).Sum / 1MB), 1)
Write-Host "[fetch_tutorial_apngs] $count APNGs ($totalMB MB) ready in $tutorialDir"
