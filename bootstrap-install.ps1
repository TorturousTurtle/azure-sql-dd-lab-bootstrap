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
Write-Host "Creating SQL install folder..."
New-Item -ItemType Directory -Path "C:\install" -Force | Out-Null

$sqlUrl = "https://go.microsoft.com/fwlink/?linkid=866658"  # SQL Server Developer
$sqlExe = "C:\install\sqldeveloper.exe"

Write-Host "Downloading SQL Server installer from $sqlUrl ..."
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlExe

Write-Host "Downloaded SQL installer:"
Get-Item $sqlExe | Select-Object FullName, Length, LastWriteTime

Write-Host "Starting silent SQL Server install..."
$sqlArgs = @(
    "/Q",
    "/ACTION=Install",
    "/FEATURES=SQLEngine",
    "/INSTANCENAME=MSSQLSERVER",
    "/SECURITYMODE=SQL",
    "/SAPWD=P@ssw0rd1234!",
    "/SQLSYSADMINACCOUNTS=`"Administrators`"",
    "/TCPENABLED=1",
    "/IACCEPTSQLSERVERLICENSETERMS=1"
)

Start-Process -FilePath $sqlExe -ArgumentList $sqlArgs -Wait -NoNewWindow
Write-Host "SQL Server installation completed."

# =========================
# Datadog Agent installation
# =========================
Write-Host "Setting Datadog environment variables..."
$env:DD_API_KEY        = $DdApiKey
$env:DD_SITE           = $DdSite
$env:DD_ENV            = $DdEnv
$env:DD_REMOTE_UPDATES = "true"

Write-Host "Creating Datadog temp folder..."
New-Item -ItemType Directory -Path "C:\Windows\SystemTemp" -Force | Out-Null

$dd = "C:\Windows\SystemTemp\datadog-installer-x86_64.exe"

Write-Host "Downloading Datadog installer..."
Invoke-WebRequest -Uri "https://install.datadoghq.com/datadog-installer-x86_64.exe" -OutFile $dd

Write-Host "Downloaded Datadog installer:"
Get-Item $dd | Select-Object FullName, Length, LastWriteTime

Write-Host "Running Datadog installer..."
Start-Process -FilePath $dd -Wait -NoNewWindow

Write-Host "Bootstrap script completed."
