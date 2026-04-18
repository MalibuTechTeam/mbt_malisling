# =============================================================================
#  MBT Emote Menu - Deploy to FiveM server
#
#  Syncs the resource from the dev folder to your FiveM server's resources
#  folder using robocopy. Excludes dev-only artifacts (node_modules, .git,
#  web/src, pnpm-lock, etc.) so only runtime files are copied.
#
#  Usage examples:
#     .\deploy-to-server.ps1
#     .\deploy-to-server.ps1 -Dest 'C:\FXServer\server-data\resources\[mbt]\mbt_emote_menu'
#     .\deploy-to-server.ps1 -Build         # rebuild NUI before deploying
#     .\deploy-to-server.ps1 -WhatIf        # dry run
#
#  First run: edit the $DefaultDest below to point to your server, then you
#  can just run `.\deploy-to-server.ps1` without arguments.
# =============================================================================

param(
    [string]$Src  = 'D:\Projects\FiveM\MBT\mbt_malisling',
    [string]$Dest = '',
    [switch]$Build,
    [switch]$WhatIf
)

# ---- Edit this line once with your server path, then forget it -------------
$DefaultDest = 'D:\Projects\FiveM\MalibuESX\server-data\resources\[wip]\mbt_malisling'
# ----------------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Dest)) { $Dest = $DefaultDest }

Write-Host "=== MBT Malisling - deploy ===" -ForegroundColor Cyan
Write-Host "Source : $Src"
Write-Host "Target : $Dest"
if ($WhatIf) { Write-Host "DRY RUN (no files will be written)" -ForegroundColor Yellow }
Write-Host ""

# --- Sanity: source exists --------------------------------------------------
if (-not (Test-Path -LiteralPath $Src -PathType Container)) {
    Write-Error "Source folder not found: $Src"
    exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $Src 'fxmanifest.lua'))) {
    Write-Error "No fxmanifest.lua in $Src - is this really the resource root?"
    exit 1
}

# --- Optional: rebuild NUI first -------------------------------------------
if ($Build) {
    Write-Host "[build] pnpm build..." -ForegroundColor Cyan
    Push-Location (Join-Path $Src 'web')
    try {
        & pnpm build
        if ($LASTEXITCODE -ne 0) { throw "pnpm build failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
    Write-Host ""
}

# --- Sanity: dist exists ----------------------------------------------------
$distPath = Join-Path $Src 'web\dist\index.html'
if (-not (Test-Path -LiteralPath $distPath)) {
    Write-Error "web/dist/index.html not found. Run with -Build or execute 'pnpm build' manually first."
    exit 1
}

# --- Ensure target parent exists -------------------------------------------
$destParent = [System.IO.Path]::GetDirectoryName($Dest)
if (-not (Test-Path -LiteralPath $destParent)) {
    Write-Error "Target parent folder does not exist: $destParent"
    exit 1
}

# --- Robocopy options -------------------------------------------------------
# /MIR  - mirror (sync, remove stale files in dest)
# /NFL  - no file list in log (cleaner output)
# /NDL  - no directory list
# /NP   - no progress percent per file
# /R:1  - retry once on failure (instead of default 1 million)
# /W:1  - 1 second wait between retries
# /L    - list only (dry run)
$robocopyOpts = @('/MIR', '/NFL', '/NDL', '/NP', '/R:1', '/W:1')
if ($WhatIf) { $robocopyOpts += '/L' }

# --- Exclusions -------------------------------------------------------------
$excludeDirs = @(
    'node_modules',
    '.git',
    '.github',
    '.vite',
    '.vscode',
    '.idea',
    "$Src\web\src",
    "$Src\web\public"
)

$excludeFiles = @(
    'pnpm-lock.yaml',
    'package.json',
    'package-lock.json',
    'yarn.lock',
    'tsconfig.json',
    'tsconfig.*.json',
    'tsconfig.tsbuildinfo',
    'vite.config.*',
    '.gitignore',
    '.gitattributes',
    'rename-resource.ps1',
    'deploy-to-server.ps1',
    'cfx_release_post.md',
    'video_showcase_script.md',
    '*.tmp',
    '*.bak',
    '*.swp',
    '.DS_Store',
    'Thumbs.db'
)

$robocopyArgs = @($Src, $Dest) + $robocopyOpts
$robocopyArgs += '/XD'
$robocopyArgs += $excludeDirs
$robocopyArgs += '/XF'
$robocopyArgs += $excludeFiles

Write-Host "[sync] robocopy..." -ForegroundColor Cyan
& robocopy @robocopyArgs | Out-Host
$rc = $LASTEXITCODE

# Robocopy exit codes: 0-7 are success (0 = no change, 1 = files copied, ...)
# 8+ is an actual failure
if ($rc -ge 8) {
    Write-Error "robocopy failed with exit code $rc"
    exit $rc
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Exit code: $rc (robocopy: 0=no changes, 1-7=files copied)"

if (-not $WhatIf) {
    Write-Host ""
    Write-Host "In the FiveM server console:" -ForegroundColor Cyan
    Write-Host "   ensure mbt_malisling"
    Write-Host "or:" -ForegroundColor Cyan
    Write-Host "   restart mbt_malisling"
}
