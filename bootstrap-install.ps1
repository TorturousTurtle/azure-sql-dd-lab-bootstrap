param(
    [Parameter(Mandatory = $true)]
    [string]$DdApiKey,

    [string]$DdSite = "datadoghq.com",
    [string]$DdEnv  = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "=== [Bootstrap] Starting bootstrap-install.ps1 ==="

Write-Host "=== [Bootstrap] Configuring TLS 1.2 ==="
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072

# =========================
# SQL Server installation
# =========================
Write-Host "=== [SQL] Starting SQL Express install ==="

$installDir = "C:\install"
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

$sqlUrl = "https://go.microsoft.com/fwlink/?linkid=866658"
$sqlExe = Join-Path $installDir "sqlexpress.exe"

Write-Host "=== [SQL] Downloading SQL installer from $sqlUrl ==="
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlExe

if (-not (Test-Path $sqlExe)) {
    Write-Error "SQL installer failed to download to $sqlExe. Exiting."
    exit 1
}

Write-Host "=== [SQL] File downloaded ==="
Get-Item $sqlExe | Select-Object FullName, Length, LastWriteTime | Out-String | Write-Host

Write-Host "=== [SQL] Installing .NET Framework 3.5 (required for SQL Express) ==="
Install-WindowsFeature Net-Framework-Core -ErrorAction Stop

$sqlArgs = @(
    "/Q",
    "/ACTION=Install",
    "/FEATURES=SQLEngine",
    "/INSTANCENAME=SQLEXPRESS",
    "/SECURITYMODE=SQL",
    "/SAPWD=P@ssw0rd1234!",
    "/SQLSYSADMINACCOUNTS=`"Administrators`"",
    "/TCPENABLED=1",
    "/IACCEPTSQLSERVERLICENSETERMS=1"
) -join " "

Write-Host "=== [SQL] Running silent SQL Express install ==="
Write-Host "=== [SQL] Args: $sqlArgs ==="

$process = Start-Process -FilePath $sqlExe -ArgumentList $sqlArgs -Wait -NoNewWindow -PassThru
Write-Host "=== [SQL] Installer exit code: $($process.ExitCode) ==="

if ($process.ExitCode -ne 0) {
    Write-Error "SQL Express installer returned non-zero exit code $($process.ExitCode). Exiting."
    exit 1
}

Write-Host "=== [SQL] Checking for MSSQL`$SQLEXPRESS service (with retries) ==="

$svc = $null
for ($i = 1; $i -le 5; $i++) {
    $svc = Get-Service -Name "MSSQL`$SQLEXPRESS" -ErrorAction SilentlyContinue
    if ($svc) { break }
    Write-Host "=== [SQL] Service not found yet (attempt $i/5). Waiting 10 seconds... ==="
    Start-Sleep -Seconds 10
}

if (-not $svc) {
    Write-Error "SQL Express service MSSQL`$SQLEXPRESS not found after install/retries. Failing script."
    exit 1
}

Write-Host "=== [SQL] Service found: MSSQL`$SQLEXPRESS (State: $($svc.Status)) ==="

if ($svc.Status -ne 'Running') {
    Write-Host "=== [SQL] Service not running. Attempting to start MSSQL`$SQLEXPRESS ==="
    try {
        Start-Service -Name "MSSQL`$SQLEXPRESS"
        $svc = Get-Service -Name "MSSQL`$SQLEXPRESS"
        Write-Host "=== [SQL] Service state after Start-Service: $($svc.Status) ==="
    }
    catch {
        Write-Error "Failed to start MSSQL`$SQLEXPRESS: $($_.Exception.Message)"
        exit 1
    }
}

Write-Host "=== [SQL] SQL Express ready (State: $($svc.Status)) ==="

# =========================
# Datadog Agent installation
# =========================
Write-Host "=== [DD] Setting Datadog environment variables ==="
$env:DD_API_KEY        = $DdApiKey
$env:DD_SITE           = $DdSite
$env:DD_ENV            = $DdEnv
$env:DD_REMOTE_UPDATES = "true"

$tempPath = "C:\Windows\SystemTemp"
New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

$dd = Join-Path $tempPath "datadog-installer-x86_64.exe"

Write-Host "=== [DD] Downloading Datadog installer ==="
Invoke-WebRequest -Uri "https://install.datadoghq.com/datadog-installer-x86_64.exe" -OutFile $dd

if (-not (Test-Path $dd)) {
    Write-Error "Datadog installer failed to download to $dd. Exiting."
    exit 1
}

Write-Host "=== [DD] Datadog installer file info ==="
Get-Item $dd | Select-Object FullName, Length, LastWriteTime | Out-String | Write-Host

Write-Host "=== [DD] Running Datadog installer ==="
$ddProcess = Start-Process -FilePath $dd -Wait -NoNewWindow -PassThru
Write-Host "=== [DD] Datadog installer exit code: $($ddProcess.ExitCode) ==="

if ($ddProcess.ExitCode -ne 0) {
    Write-Error "Datadog installer returned non-zero exit code $($ddProcess.ExitCode). Exiting."
    exit 1
}

Write-Host "=== [Bootstrap] Script completed successfully ==="
exit 0
