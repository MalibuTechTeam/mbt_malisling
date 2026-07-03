# install_ox_patch.ps1
# Applies the mbt_malisling patch to ox_inventory, once.
# Run with the server STOPPED, then restart.
#
# Usage:
#   .\install_ox_patch.ps1
#   .\install_ox_patch.ps1 -OxPath "C:\server\resources\[ox]\ox_inventory"

param(
    [string]$OxPath = ""
)

$ErrorActionPreference = "Stop"
$utf8      = New-Object System.Text.UTF8Encoding($false)
$scriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $PWD.Path }

# --- Locate ox_inventory -----------------------------------------------------------
if (-not $OxPath) {
    Write-Host "Searching for ox_inventory..." -ForegroundColor Gray

    # Candidates: walk up the tree from scriptDir + read DefaultDest from deploy-to-server.ps1
    $searchRoots = [System.Collections.Generic.List[string]]::new()

    # 1) Read DefaultDest from deploy-to-server.ps1 if present
    $deployScript = Join-Path $scriptDir "deploy-to-server.ps1"
    if (Test-Path -LiteralPath $deployScript) {
        $deployContent = Get-Content -LiteralPath $deployScript -Raw -ErrorAction SilentlyContinue
        if ($deployContent -match '\$DefaultDest\s*=\s*[''"]([^''"]+)[''"]') {
            $deployDest = $Matches[1]
            # Walk up from DefaultDest until we hit 'resources'
            $d = $deployDest
            for ($i = 0; $i -lt 8; $i++) {
                if ([string]::IsNullOrWhiteSpace($d)) { break }
                if ((Split-Path $d -Leaf) -eq "resources") { $searchRoots.Add($d); break }
                $sub = Join-Path $d "resources"
                if (Test-Path -LiteralPath $sub -PathType Container) { $searchRoots.Add($sub); break }
                $p = Split-Path $d -Parent
                if ($p -eq $d) { break }
                $d = $p
            }
        }
    }

    # 2) Also walk up from scriptDir (fallback if the script lives inside the server)
    $d = $scriptDir
    for ($i = 0; $i -lt 10; $i++) {
        if ([string]::IsNullOrWhiteSpace($d)) { break }
        if ((Split-Path $d -Leaf) -eq "resources") { if (-not $searchRoots.Contains($d)) { $searchRoots.Add($d) }; break }
        $sub = Join-Path $d "resources"
        if (Test-Path -LiteralPath $sub -PathType Container) { if (-not $searchRoots.Contains($sub)) { $searchRoots.Add($sub) }; break }
        $p = Split-Path $d -Parent
        if ($p -eq $d) { break }
        $d = $p
    }

    $resourcesDir = if ($searchRoots.Count -gt 0) { $searchRoots[0] } else { $null }

    if ($resourcesDir) {
        Write-Host "Searching in: $resourcesDir" -ForegroundColor Gray
        try {
            $manifests = Get-ChildItem -LiteralPath $resourcesDir -Filter "fxmanifest.lua" -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Directory.Name -eq "ox_inventory" }

            $hits = @($manifests | ForEach-Object { $_.Directory.FullName })

            if ($hits.Count -eq 1) {
                $OxPath = $hits[0]
                Write-Host "Found: $OxPath" -ForegroundColor Green
            } elseif ($hits.Count -gt 1) {
                Write-Host "Found $($hits.Count) ox_inventory installs:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $hits.Count; $i++) {
                    Write-Host "  [$($i + 1)] $($hits[$i])" -ForegroundColor White
                }
                $choice = Read-Host "Choose the number"
                $idx = [int]$choice - 1
                if ($idx -ge 0 -and $idx -lt $hits.Count) {
                    $OxPath = $hits[$idx]
                } else {
                    Write-Host "[ERROR] Invalid choice." -ForegroundColor Red
                    exit 1
                }
            }
        } catch {
            Write-Host "Search failed: $_" -ForegroundColor Yellow
        }
    }

    if (-not $OxPath) {
        Write-Host "ox_inventory not found automatically." -ForegroundColor Yellow
        Write-Host "Example: D:\FXServer\resources\[ox]\ox_inventory" -ForegroundColor Gray
        $OxPath = Read-Host "Enter the full path to ox_inventory"
    }
}

$targetFile = Join-Path $OxPath "modules\weapon\client.lua"
Write-Host "Target: $targetFile" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $targetFile)) {
    Write-Host "[ERROR] File not found: $targetFile" -ForegroundColor Red
    exit 1
}

# --- Read patch files (kept separate) ----------------------------------------
$hookFile   = Join-Path $scriptDir "patches\ox_hook.lua"
$appendFile = Join-Path $scriptDir "patches\ox_append.lua"
foreach ($f in @($hookFile, $appendFile)) {
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Host "[ERROR] Patch file not found: $f" -ForegroundColor Red
        exit 1
    }
}
$hook      = [System.IO.File]::ReadAllText($hookFile,   $utf8)
$appendLua = [System.IO.File]::ReadAllText($appendFile, $utf8)

# --- Read target file ---------------------------------------------------------
$content = [System.IO.File]::ReadAllText($targetFile, $utf8)
Write-Host "Read $($content.Length) characters." -ForegroundColor Gray

# --- Idempotency: if the patch is already present, restore the backup and reapply
$hasHook   = $content.Contains("mbt_malisling:holster_request")
$hasAppend = $content.Contains("mbt_malisling:sendAnim")

if ($hasHook -or $hasAppend) {
    $bakFile = "$targetFile.bak"
    if (-not (Test-Path -LiteralPath $bakFile)) {
        Write-Host "[ERROR] Patch already present but backup not found: $bakFile" -ForegroundColor Red
        Write-Host "Restore the original ox_inventory file manually and re-run." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Patch already present. Restoring backup and reapplying..." -ForegroundColor Yellow
    Copy-Item -LiteralPath $bakFile -Destination $targetFile -Force
    $content = [System.IO.File]::ReadAllText($targetFile, $utf8)
}

# --- Step 1: hook inside Weapon.Equip ----------------------------------------
$insertPoint = "sleep = anim and anim[3] or 1200"

if (-not $content.Contains($insertPoint)) {
    Write-Host "[ERROR] Insertion point not found." -ForegroundColor Red
    $sleepLines = ($content -split "`n") | Where-Object { $_ -match "sleep" }
    if ($sleepLines) {
        Write-Host "Lines containing 'sleep' in the file:" -ForegroundColor Yellow
        $sleepLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "No 'sleep' line - unsupported ox_inventory version." -ForegroundColor Red
    }
    exit 1
}

$patched = $content.Replace($insertPoint, $hook + $insertPoint)

if ($patched -eq $content) {
    $norm    = $content.Replace("`r`n", "`n")
    $patched = $norm.Replace($insertPoint, $hook + $insertPoint)
    if ($patched -eq $norm) {
        Write-Host "[ERROR] Hook replacement failed." -ForegroundColor Red
        exit 1
    }
}

# --- Step 2: append sendAnim before 'return Weapon' --------------------------
$returnPoint = "return Weapon"

if (-not $patched.Contains($returnPoint)) {
    Write-Host "[ERROR] 'return Weapon' not found in the file." -ForegroundColor Red
    exit 1
}

$lastIndex = $patched.LastIndexOf($returnPoint)
$patched   = $patched.Substring(0, $lastIndex) + $appendLua + "`n" + $patched.Substring($lastIndex)

if (-not $patched.Contains("mbt_malisling:holster_request") -or -not $patched.Contains("mbt_malisling:sendAnim")) {
    Write-Host "[ERROR] Post-replacement verification failed." -ForegroundColor Red
    exit 1
}

# --- Backup + write ----------------------------------------------------------
Copy-Item -LiteralPath $targetFile -Destination "$targetFile.bak" -Force
Write-Host "Backup: $targetFile.bak" -ForegroundColor Yellow

[System.IO.File]::WriteAllText($targetFile, $patched, $utf8)

Write-Host "[OK] Patch applied successfully!" -ForegroundColor Green
Write-Host "Restart the server to apply the changes." -ForegroundColor Cyan
