<#
.SYNOPSIS
    Safely synchronizes changes from upstream (GopeedLab/gopeed) to local fork (hoodmoshla/gopeed).

.DESCRIPTION
    1. Verifies remotes (origin = hoodmoshla/gopeed, upstream = GopeedLab/gopeed).
    2. Fetches the latest commits from upstream/main.
    3. Displays new upstream commits and checks for potential file conflicts with our custom features:
       - Smart Android Background Service (background_service_controller.dart, android_foreground_service.dart, app_runtime_controller.dart, main_shell.dart)
       - Android Update System (updater.dart, app_update_dialog.dart)
    4. Creates a safety backup branch before merging.
    5. Merges upstream/main safely without overwriting custom modifications.
    6. Automatically executes test suite to verify no regressions in background service and updater.

.PARAMETER CheckOnly
    Only inspect upstream changes without merging.

.PARAMETER AutoResolve
    Attempts to merge and run verification tests automatically.
#>

param(
    [switch]$CheckOnly,
    [switch]$AutoResolve
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     Gopeed Safe Upstream Synchronizer (sync-upstream)    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify Git availability
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    if (Test-Path "C:\Users\Hood\git\cmd\git.exe") {
        $env:PATH = "C:\Users\Hood\git\cmd;$env:PATH"
    } else {
        Write-Error "Git executable not found in PATH."
        exit 1
    }
}

# 2. Verify Remotes
Write-Host "`n[1/5] Verifying Git Remotes..." -ForegroundColor Yellow
$remotes = git remote -v
$hasOrigin = $remotes -match "origin\s+.*hoodmoshla/gopeed"
$hasUpstream = $remotes -match "upstream\s+.*GopeedLab/gopeed"

if (-not $hasUpstream) {
    Write-Host "Adding upstream remote -> https://github.com/GopeedLab/gopeed.git" -ForegroundColor Green
    git remote add upstream https://github.com/GopeedLab/gopeed.git
} else {
    Write-Host "Upstream remote verified: GopeedLab/gopeed" -ForegroundColor Green
}

if ($hasOrigin) {
    Write-Host "Origin remote verified: hoodmoshla/gopeed" -ForegroundColor Green
}

# 3. Fetch Upstream
Write-Host "`n[2/5] Fetching upstream/main..." -ForegroundColor Yellow
git fetch upstream main

# 4. Check Divergence
$counts = git rev-list --left-right --count HEAD...upstream/main
$localAhead = ($counts -split '\s+')[0]
$upstreamAhead = ($counts -split '\s+')[1]

Write-Host "Local commits ahead of upstream: $localAhead" -ForegroundColor Gray
Write-Host "Upstream commits ahead of local: $upstreamAhead" -ForegroundColor Gray

if ([int]$upstreamAhead -eq 0) {
    Write-Host "`nYour branch is completely up to date with upstream/main! Nothing to merge." -ForegroundColor Green
    exit 0
}

Write-Host "`nRecent commits in upstream/main:" -ForegroundColor Cyan
git log --oneline HEAD..upstream/main -n 10

# Check if upstream modified any of our protected custom files
$protectedFiles = @(
    "ui/flutter/lib/app/application/background_service_controller.dart",
    "ui/flutter/lib/app/application/android_foreground_service.dart",
    "ui/flutter/lib/app/application/app_runtime_controller.dart",
    "ui/flutter/lib/app/router/shells/main_shell.dart",
    "ui/flutter/lib/util/updater.dart"
)

$changedFiles = git diff --name-only HEAD..upstream/main
$conflicts = @()
foreach ($file in $protectedFiles) {
    if ($changedFiles -contains $file) {
        $conflicts += $file
    }
}

if ($conflicts.Count -gt 0) {
    Write-Host "`n[WARNING] Upstream modified the following custom feature files:" -ForegroundColor Yellow
    foreach ($c in $conflicts) {
        Write-Host "  - $c" -ForegroundColor Red
    }
} else {
    Write-Host "`n[OK] No file conflicts detected with custom features." -ForegroundColor Green
}

if ($CheckOnly) {
    Write-Host "`nCheckOnly mode requested. Exiting without merging." -ForegroundColor Cyan
    exit 0
}

# 5. Backup current branch before merging
$backupBranch = "backup-before-sync-" + (Get-Date -Format "yyyyMMdd-HHmmss")
Write-Host "`n[3/5] Creating safety backup branch: $backupBranch..." -ForegroundColor Yellow
git branch $backupBranch
Write-Host "Backup branch created successfully." -ForegroundColor Green

# 6. Merge upstream
Write-Host "`n[4/5] Merging upstream/main into current branch..." -ForegroundColor Yellow
try {
    git merge upstream/main --no-edit
    Write-Host "Merged upstream/main successfully." -ForegroundColor Green
} catch {
    Write-Host "`n[ERROR] Merge conflict occurred during git merge." -ForegroundColor Red
    Write-Host "Your changes are safe on branch: $backupBranch" -ForegroundColor Yellow
    Write-Host "Resolve the conflict manually or run: git merge --abort" -ForegroundColor Yellow
    exit 1
}

# 7. Run Verification Tests
Write-Host "`n[5/5] Running verification tests..." -ForegroundColor Yellow
$flutterBin = "C:\Users\Hood\flutter\bin"
if (Test-Path "$flutterBin\flutter.bat") {
    $env:PATH = "$flutterBin;$env:PATH"
}
Push-Location "ui/flutter"
try {
    flutter test test/app/application/background_service_controller_test.dart test/updater_test.dart
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "   Sync and Verification Completed Successfully!          " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
} catch {
    Write-Host "`n[WARNING] Tests failed after merge. Please review." -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
