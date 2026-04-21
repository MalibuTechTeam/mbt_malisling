# install_ox_patch.ps1
# Applica la patch mbt_malisling a ox_inventory una volta sola.
# Esegui con il server SPENTO, poi riavvia.
#
# Uso:
#   .\install_ox_patch.ps1
#   .\install_ox_patch.ps1 -OxPath "C:\server\resources\[ox]\ox_inventory"

param(
    [string]$OxPath = ""
)

$ErrorActionPreference = "Stop"
$utf8      = New-Object System.Text.UTF8Encoding($false)
$scriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $PWD.Path }

# --- Trova ox_inventory -----------------------------------------------------------
if (-not $OxPath) {
    Write-Host "Ricerca ox_inventory in corso..." -ForegroundColor Gray

    # Candidati: risali l'albero dallo scriptDir + leggi DefaultDest da deploy-to-server.ps1
    $searchRoots = [System.Collections.Generic.List[string]]::new()

    # 1) Leggi DefaultDest da deploy-to-server.ps1 se presente
    $deployScript = Join-Path $scriptDir "deploy-to-server.ps1"
    if (Test-Path -LiteralPath $deployScript) {
        $deployContent = Get-Content -LiteralPath $deployScript -Raw -ErrorAction SilentlyContinue
        if ($deployContent -match '\$DefaultDest\s*=\s*[''"]([^''"]+)[''"]') {
            $deployDest = $Matches[1]
            # Risali da DefaultDest fino a trovare 'resources'
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

    # 2) Risali anche dallo scriptDir (fallback se lo script e' dentro il server)
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
        Write-Host "Cercando dentro: $resourcesDir" -ForegroundColor Gray
        try {
            $manifests = Get-ChildItem -LiteralPath $resourcesDir -Filter "fxmanifest.lua" -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Directory.Name -eq "ox_inventory" }

            $hits = @($manifests | ForEach-Object { $_.Directory.FullName })

            if ($hits.Count -eq 1) {
                $OxPath = $hits[0]
                Write-Host "Trovato: $OxPath" -ForegroundColor Green
            } elseif ($hits.Count -gt 1) {
                Write-Host "Trovate $($hits.Count) installazioni di ox_inventory:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $hits.Count; $i++) {
                    Write-Host "  [$($i + 1)] $($hits[$i])" -ForegroundColor White
                }
                $choice = Read-Host "Scegli il numero"
                $idx = [int]$choice - 1
                if ($idx -ge 0 -and $idx -lt $hits.Count) {
                    $OxPath = $hits[$idx]
                } else {
                    Write-Host "[ERRORE] Scelta non valida." -ForegroundColor Red
                    exit 1
                }
            }
        } catch {
            Write-Host "Ricerca fallita: $_" -ForegroundColor Yellow
        }
    }

    if (-not $OxPath) {
        Write-Host "ox_inventory non trovato automaticamente." -ForegroundColor Yellow
        Write-Host "Esempio: D:\FXServer\resources\[ox]\ox_inventory" -ForegroundColor Gray
        $OxPath = Read-Host "Inserisci il percorso completo di ox_inventory"
    }
}

$targetFile = Join-Path $OxPath "modules\weapon\client.lua"
Write-Host "Target: $targetFile" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $targetFile)) {
    Write-Host "[ERRORE] File non trovato: $targetFile" -ForegroundColor Red
    exit 1
}

# --- Lettura file patch da files separati ------------------------------------
$hookFile   = Join-Path $scriptDir "patches\ox_hook.lua"
$appendFile = Join-Path $scriptDir "patches\ox_append.lua"
foreach ($f in @($hookFile, $appendFile)) {
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Host "[ERRORE] File patch non trovato: $f" -ForegroundColor Red
        exit 1
    }
}
$hook      = [System.IO.File]::ReadAllText($hookFile,   $utf8)
$appendLua = [System.IO.File]::ReadAllText($appendFile, $utf8)

# --- Lettura file target ------------------------------------------------------
$content = [System.IO.File]::ReadAllText($targetFile, $utf8)
Write-Host "Letto $($content.Length) caratteri." -ForegroundColor Gray

# --- Idempotency: se la patch e' gia' presente, ripristina il backup e riapplica
$hasHook   = $content.Contains("mbt_malisling:holster_request")
$hasAppend = $content.Contains("mbt_malisling:sendAnim")

if ($hasHook -or $hasAppend) {
    $bakFile = "$targetFile.bak"
    if (-not (Test-Path -LiteralPath $bakFile)) {
        Write-Host "[ERRORE] Patch gia' presente ma backup non trovato: $bakFile" -ForegroundColor Red
        Write-Host "Ripristina manualmente il file originale di ox_inventory e riesegui." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Patch gia' presente. Ripristino backup e re-applicazione..." -ForegroundColor Yellow
    Copy-Item -LiteralPath $bakFile -Destination $targetFile -Force
    $content = [System.IO.File]::ReadAllText($targetFile, $utf8)
}

# --- Punto 1: hook dentro Weapon.Equip ---------------------------------------
$insertPoint = "sleep = anim and anim[3] or 1200"

if (-not $content.Contains($insertPoint)) {
    Write-Host "[ERRORE] Punto di inserimento non trovato." -ForegroundColor Red
    $sleepLines = ($content -split "`n") | Where-Object { $_ -match "sleep" }
    if ($sleepLines) {
        Write-Host "Righe con 'sleep' nel file:" -ForegroundColor Yellow
        $sleepLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "Nessuna riga con 'sleep' - versione ox_inventory non supportata." -ForegroundColor Red
    }
    exit 1
}

$patched = $content.Replace($insertPoint, $hook + $insertPoint)

if ($patched -eq $content) {
    $norm    = $content.Replace("`r`n", "`n")
    $patched = $norm.Replace($insertPoint, $hook + $insertPoint)
    if ($patched -eq $norm) {
        Write-Host "[ERRORE] Sostituzione hook fallita." -ForegroundColor Red
        exit 1
    }
}

# --- Punto 2: append sendAnim prima di 'return Weapon' -----------------------
$returnPoint = "return Weapon"

if (-not $patched.Contains($returnPoint)) {
    Write-Host "[ERRORE] 'return Weapon' non trovato nel file." -ForegroundColor Red
    exit 1
}

$lastIndex = $patched.LastIndexOf($returnPoint)
$patched   = $patched.Substring(0, $lastIndex) + $appendLua + "`n" + $patched.Substring($lastIndex)

if (-not $patched.Contains("mbt_malisling:holster_request") -or -not $patched.Contains("mbt_malisling:sendAnim")) {
    Write-Host "[ERRORE] Verifica post-sostituzione fallita." -ForegroundColor Red
    exit 1
}

# --- Backup + scrittura ------------------------------------------------------
Copy-Item -LiteralPath $targetFile -Destination "$targetFile.bak" -Force
Write-Host "Backup: $targetFile.bak" -ForegroundColor Yellow

[System.IO.File]::WriteAllText($targetFile, $patched, $utf8)

Write-Host "[OK] Patch applicata con successo!" -ForegroundColor Green
Write-Host "Riavvia il server per rendere effettive le modifiche." -ForegroundColor Cyan
