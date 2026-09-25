# =============================================================================
# Aula-huskeliste – MitID-login fra Windows
#
# Logger ind på Aula med MitID fra din egen computer (Aula blokerer login fra
# servere) og flytter derefter login'et sikkert over på din server via SSH.
#
# Kør i PowerShell:
#   irm https://raw.githubusercontent.com/jesperbagger/aula-huskeliste/main/scripts/login-windows.ps1 | iex
#
# Kør scriptet igen, hvis du en dag får mailen "Aula-automation: kræver handling".
# =============================================================================
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $Repo = if ($env:AULA_HUSKELISTE_REPO) { $env:AULA_HUSKELISTE_REPO } else { 'jesperbagger/aula-huskeliste' }
    $User = if ($env:AULA_SERVER_USER) { $env:AULA_SERVER_USER } else { 'ubuntu' }
    $Base = "https://github.com/$Repo/releases/latest/download"

    function Info([string]$m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
    function Ok([string]$m) { Write-Host "    OK  $m" -ForegroundColor Green }

    Write-Host "`nAula-huskeliste - MitID-login" -ForegroundColor White
    Write-Host "Kør dette hjemmefra (ikke via VPN eller arbejdsnetværk)." -ForegroundColor DarkGray

    # --- 1. Forudsætninger ---------------------------------------------------
    Info "1/5  Tjekker SSH"
    if (-not (Get-Command ssh -ErrorAction SilentlyContinue) -or -not (Get-Command scp -ErrorAction SilentlyContinue)) {
        throw "SSH mangler. Installer 'OpenSSH-klient' under Indstillinger > System > Valgfrie funktioner, og prøv igen."
    }
    Ok "SSH er installeret"

    # --- 2. Server og nøgle ---------------------------------------------------
    Info "2/5  Forbindelse til din server"
    $Server = (Read-Host "    Serverens IP-adresse (fx 203.0.113.10)").Trim()
    if (-not $Server) { throw "Du skal indtaste serverens IP-adresse." }

    $DefaultKey = Get-ChildItem -Path (Join-Path $HOME 'Downloads') -Filter 'ssh-key-*.key' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $Prompt = "    Sti til din SSH-nøgle"
    if ($DefaultKey) { $Prompt += " [Enter = $($DefaultKey.FullName)]" }
    $Key = (Read-Host $Prompt).Trim().Trim('"')
    if (-not $Key -and $DefaultKey) { $Key = $DefaultKey.FullName }
    if (-not $Key -or -not (Test-Path -LiteralPath $Key)) { throw "Kan ikke finde SSH-nøglen: '$Key'" }

    $SshOpts = @('-i', $Key, '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=15')
    & ssh @SshOpts "$User@$Server" 'command -v aula-import-login >/dev/null'
    if ($LASTEXITCODE -ne 0) {
        throw "Kunne ikke forbinde til serveren, eller installationsscriptet er ikke kørt endnu (trin 2)."
    }
    Ok "Forbundet til $Server"

    # --- 3. Hent aula-programmet ------------------------------------------
    Info "3/5  Henter aula-programmet"
    $Work = Join-Path $env:TEMP ("aula-login-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $Work | Out-Null
    try {
        $Exe = Join-Path $Work 'aula.exe'
        Invoke-WebRequest -UseBasicParsing -Uri "$Base/aula-windows-x64.exe" -OutFile $Exe
        Invoke-WebRequest -UseBasicParsing -Uri "$Base/SHA256SUMS" -OutFile (Join-Path $Work 'SHA256SUMS')
        $Expected = (Get-Content (Join-Path $Work 'SHA256SUMS') | Where-Object { $_ -match 'aula-windows-x64\.exe$' }) -split '\s+' | Select-Object -First 1
        $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Exe).Hash
        if (-not $Expected -or $Actual -ne $Expected.ToUpper()) { throw "Kontrolsummen passer ikke. Prøv igen." }
        Ok "aula.exe er hentet og kontrolleret"

        # --- 4. MitID-login ---------------------------------------------------
        Info "4/5  Log ind med MitID"
        Write-Host "    Skriv dit MitID-brugernavn, når der spørges om 'MitID username'." -ForegroundColor DarkGray
        Write-Host "    Derefter vises en QR-kode. Scan den med MitID-appen og godkend." -ForegroundColor DarkGray
        $Data = Join-Path $Work 'data'
        $env:AULA_MCP_DIR = $Data
        $env:AULA_MCP_NO_KEYCHAIN = '1'
        & $Exe login
        if ($LASTEXITCODE -ne 0) { throw "Login mislykkedes. Står der 'bot protection', så er du ikke på dit hjemmenetværk." }
        $Tokens = Join-Path $Data 'tokens.json'
        $KeyFile = Join-Path $Data '.key'
        if (-not (Test-Path -LiteralPath $Tokens) -or -not (Test-Path -LiteralPath $KeyFile)) {
            throw "Login gav ingen tokens. Prøv igen."
        }
        Ok "Logget ind"

        # --- 5. Flyt login'et til serveren --------------------------------------
        Info "5/5  Flytter login'et til serveren"
        & ssh @SshOpts "$User@$Server" 'mkdir -p ~/aula-login && chmod 700 ~/aula-login'
        if ($LASTEXITCODE -ne 0) { throw "Kunne ikke oprette mappe på serveren." }
        & scp @SshOpts $Tokens $KeyFile "${User}@${Server}:aula-login/"
        if ($LASTEXITCODE -ne 0) { throw "Kunne ikke kopiere login'et til serveren." }
        & ssh @SshOpts "$User@$Server" 'sudo aula-import-login ~/aula-login'
        if ($LASTEXITCODE -ne 0) { throw "Serveren kunne ikke importere login'et." }
        Ok "Serveren er logget ind på Aula"
    }
    finally {
        Remove-Item Env:AULA_MCP_DIR -ErrorAction SilentlyContinue
        Remove-Item Env:AULA_MCP_NO_KEYCHAIN -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "`nFærdigt. Login'et ligger nu kun på din server (kopien på denne PC er slettet)." -ForegroundColor Green
    Write-Host "Næste skridt: tilføj connectoren i Claude (trin 4 i vejledningen).`n"
}
