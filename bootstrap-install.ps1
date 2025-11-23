param(
    [Parameter(Mandatory = $true)]
    [string]$DdApiKey,

    [string]$DdSite = "datadoghq.com",
    [string]$DdEnv  = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "Configuring TLS 1.2..."
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072

# =========================
# SQL Server installation
# =========================
Write-Host "=== [SQL] Starting SQL Express install ==="

$installDir = "C:\install"
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

$sqlUrl = "https://go.microsoft.com/fwlink/?linkid=866658"
$sqlExe = Join-Path $installDir "sqlexpress.exe"

Write-Host "=== [SQL] Downloading SQL installer ==="
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlExe

if (-not (Test-Path $sqlExe)) {
    Write-Error "SQL installer failed to download. Exiting."
    exit 1
}

Write-Host "=== [SQL] File downloaded ==="
Get-Item $sqlExe | Select-Object FullName, Length, LastWriteTime | Out-String | Write-Host

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
Start-Process -FilePath $sqlExe -ArgumentList $sqlArgs -Wait -NoNewWindow

Write-Host "=== [SQL] Checking SQL service ==="
$svc = Get-Service -Name "MSSQL`$SQLEXPRESS" -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Error "SQL Express service MSSQL`$SQLEXPRESS not found after install. Failing script."
    exit 1
}

Write-Host "=== [SQL] SQL Express installed successfully (State: $($svc.Status)) ==="

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
    Write-Error "Datadog installer failed to download. Exiting."
    exit 1
}

Write-Host "=== [DD] Running Datadog installer ==="
Start-Process -FilePath $dd -Wait -NoNewWindow

Write-Host "=== [Bootstrap] Script completed successfully ==="
exit 0
