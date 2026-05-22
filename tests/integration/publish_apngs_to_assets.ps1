#!/usr/bin/env pwsh
# publish_apngs_to_assets.ps1 — force-amend-push the working tree's
# tutorial APNGs onto the orphan `assets` branch.
#
# Workflow:
#   1. Re-record APNGs via `rerecord_all.ps1` (lands them in
#      doc/source/_static/tutorials/, which is .gitignored on source
#      branches).
#   2. Eyeball-review the new APNGs locally.
#   3. Run this script. It checks out the `assets` worktree, copies the
#      working tree's APNGs in, amends the single root commit, and
#      force-pushes. The `assets` branch ends with exactly one commit
#      (just like before), so GitHub GCs the prior blobs in ~2 weeks.
#
# Run from anywhere on a source branch:
#   pwsh modules/dasImgui/tests/integration/publish_apngs_to_assets.ps1
#
# Flags:
#   -Remote <name>   Defaults to `origin`.
#   -DryRun          Show what would happen; force-push not issued.
#   -KeepWorktree    Leave the temporary worktree on disk after pushing
#                    (handy if you're iterating; default removes it).

param(
    [string]$Remote = "origin",
    [switch]$DryRun,
    [switch]$KeepWorktree
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$srcTutorialDir = Join-Path $repoRoot "doc\source\_static\tutorials"
$worktreePath   = Join-Path (Split-Path -Parent $repoRoot) "dasImgui-assets-publish-wt"

# Check there's actually something to publish.
$srcApngs = Get-ChildItem $srcTutorialDir -Filter "*.apng" -ErrorAction SilentlyContinue
if (-not $srcApngs -or $srcApngs.Count -eq 0) {
    Write-Host "FAIL: no APNGs found in $srcTutorialDir" -ForegroundColor Red
    Write-Host "      run rerecord_all.ps1 first (or fetch_tutorial_apngs.ps1)."
    exit 1
}
$srcMB = [math]::Round((($srcApngs | Measure-Object Length -Sum).Sum / 1MB), 1)
Write-Host "[publish_apngs_to_assets] source: $($srcApngs.Count) APNGs, $srcMB MB"
Write-Host "[publish_apngs_to_assets] remote: $Remote"

# Spin up a fresh worktree pinned to origin/assets so we don't disturb the
# source-branch working tree.
git -C $repoRoot fetch $Remote assets 2>&1 | Out-Null
if (Test-Path $worktreePath) {
    Write-Host "[publish_apngs_to_assets] removing stale worktree at $worktreePath"
    git -C $repoRoot worktree remove --force $worktreePath 2>&1 | Out-Null
    Remove-Item -Recurse -Force $worktreePath -ErrorAction SilentlyContinue
}
git -C $repoRoot worktree add -B assets-publish $worktreePath "$Remote/assets" 2>&1 | Out-Null
Write-Host "[publish_apngs_to_assets] worktree: $worktreePath"

# Replace the worktree's APNG set with the source-branch versions.
$dstTutorialDir = Join-Path $worktreePath "doc\source\_static\tutorials"
New-Item -ItemType Directory -Force -Path $dstTutorialDir | Out-Null
Remove-Item -Force (Join-Path $dstTutorialDir "*.apng") -ErrorAction SilentlyContinue
Copy-Item -Force "$srcTutorialDir\*.apng" -Destination $dstTutorialDir

# Amend the root commit so history stays at one commit.
git -C $worktreePath add doc/source/_static/tutorials/
$pending = git -C $worktreePath diff --cached --name-only
if (-not $pending) {
    Write-Host "[publish_apngs_to_assets] no APNG changes vs $Remote/assets -- nothing to push"
    if (-not $KeepWorktree) {
        git -C $repoRoot worktree remove --force $worktreePath 2>&1 | Out-Null
    }
    exit 0
}
git -C $worktreePath commit --amend --no-edit | Out-Null

if ($DryRun) {
    Write-Host "[publish_apngs_to_assets] -DryRun: would force-push assets-publish -> $Remote/assets"
    Write-Host ""
    Write-Host "  Changed files:"
    git -C $worktreePath diff --name-only "$Remote/assets" "HEAD" | ForEach-Object {
        Write-Host "    $_"
    }
} else {
    Write-Host "[publish_apngs_to_assets] force-pushing to $Remote/assets ..."
    git -C $worktreePath push --force-with-lease $Remote "HEAD:assets"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: push to $Remote/assets failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "[publish_apngs_to_assets] OK -- GitHub will GC the previous blobs in ~2 weeks." -ForegroundColor Green
}

if (-not $KeepWorktree) {
    git -C $repoRoot worktree remove --force $worktreePath 2>&1 | Out-Null
    git -C $repoRoot branch -D assets-publish 2>&1 | Out-Null
}
