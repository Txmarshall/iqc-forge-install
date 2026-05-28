# iqc-forge-install -- PUBLIC entrypoint for IQC machine bootstrap.
# Contains NO personal data: no paths, no repo lists, no keys.
#
# Fresh-machine usage (one line, in any PowerShell 5.1+ window):
#   irm https://raw.githubusercontent.com/Txmarshall/iqc-forge-install/main/install.ps1 | iex
#
# What it does:
#   1. Verifies winget is present (built into Windows 11).
#   2. Installs git + GitHub CLI if missing.
#   3. Ensures you're authenticated to GitHub (interactive browser login).
#   4. Clones (or fast-forward-updates) the PRIVATE iqc-forge-bootstrap repo.
#   5. Hands off to forge-bootstrap.ps1, which does the real, re-runnable setup.
#
# Re-running is safe: it pulls the latest bootstrap and re-runs (idempotent).

$ErrorActionPreference = 'Stop'

# --- Config (edit these two if you fork/rename) ---
$Owner         = 'Txmarshall'
$BootstrapRepo = 'iqc-forge-bootstrap'   # private repo holding forge-bootstrap.ps1
$Dest          = Join-Path $env:USERPROFILE ".forge\$BootstrapRepo"

function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path','User')
}
function Info($m) { Write-Host "  $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "  $m" -ForegroundColor Yellow }

Write-Host ""
Write-Host "iqc-forge-install -- fetching the IQC machine bootstrap" -ForegroundColor Cyan
Write-Host ""

# 1) winget (App Installer) -- ships with Win11; can't proceed without it.
if (-not (Have winget)) {
    throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run.`n  https://apps.microsoft.com/detail/9NBLGGH4NNS1"
}

# 2) git + gh
foreach ($t in @(@{ id='Git.Git'; c='git' }, @{ id='GitHub.cli'; c='gh' })) {
    if (Have $t.c) {
        Info "$($t.c) present"
    } else {
        Info "Installing $($t.id)..."
        winget install --id $t.id -e --source winget --silent `
            --accept-package-agreements --accept-source-agreements
        Refresh-Path
    }
}
if (-not (Have git)) { throw "git is still not on PATH. Open a NEW PowerShell window and re-run the one-liner." }
if (-not (Have gh))  { throw "gh is still not on PATH. Open a NEW PowerShell window and re-run the one-liner." }

# 3) GitHub auth (interactive). Skipped if already authenticated.
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Info "GitHub authentication needed -- launching browser login..."
    gh auth login --hostname github.com --git-protocol https --web
    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) { throw "GitHub auth did not complete. Re-run the one-liner after 'gh auth login'." }
}
Info "GitHub authenticated"

# 4) Clone or update the private bootstrap repo.
if (Test-Path (Join-Path $Dest '.git')) {
    Info "Updating existing bootstrap clone at $Dest"
    git -C $Dest pull --ff-only
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
    Info "Cloning $Owner/$BootstrapRepo -> $Dest"
    gh repo clone "$Owner/$BootstrapRepo" $Dest
}

# 5) Hand off to the real bootstrap. Child process => fresh PATH from registry.
$bs = Join-Path $Dest 'forge-bootstrap.ps1'
if (-not (Test-Path $bs)) { throw "forge-bootstrap.ps1 not found at $bs" }
Write-Host ""
Info "Launching forge-bootstrap..."
Write-Host ""
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bs
