param(
    [Parameter(Mandatory = $true)]
    [string]$DdApiKey,

    [string]$DdSite = "datadoghq.com",
    [string]$DdEnv  = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "=== [Bootstrap] Starting ==="

Write-Host "Configuring TLS 1.2..."
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.ServicePointManager]::SecurityProtocol -bor 3072

function Install-SqlExpress {
    Write-Host "=== [SQL] Starting SQL Express install ==="

    $installDir = "C:\install"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    $sqlUrl = "https://go.microsoft.com/fwlink/?linkid=866658"
    $sqlExe = Join-Path $installDir "sqlexpress.exe"

    Write-Host "=== [SQL] Downloading SQL installer from $sqlUrl ==="
    try {
        Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlExe
    }
    catch {
        Write-Warning "=== [SQL] Download failed: $($_.Exception.Message) ==="
        return
    }

    if (-not (Test-Path $sqlExe)) {
        Write-Warning "=== [SQL] Installer file not found after download. Skipping SQL install. ==="
        return
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
    Write-Host "=== [SQL] Args: $sqlArgs ==="

    try {
        $process = Start-Process -FilePath $sqlExe -ArgumentList $sqlArgs `
            -Wait -NoNewWindow -PassThru
        $exitCode = $process.ExitCode
        Write-Host "=== [SQL] Installer exit code: $exitCode ==="

        if ($exitCode -ne 0) {
            Write-Warning "=== [SQL] Installer returned non-zero exit code $exitCode. Check SQL setup logs under 'C:\Program Files\Microsoft SQL Server\150\Setup Bootstrap\Log'. Continuing anyway. ==="
        }
    }
    catch {
        Write-Warning "=== [SQL] Exception while running installer: $($_.Exception.Message). Continuing. ==="
        return
    }

    Write-Host "=== [SQL] Checking SQL service (MSSQL`$SQLEXPRESS) ==="
    $svc = Get-Service -Name "MSSQL`$SQLEXPRESS" -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Warning "=== [SQL] SQL Express service MSSQL`$SQLEXPRESS not found after install. Continuing. ==="
        return
    }

    Write-Host "=== [SQL] SQL Express service state: $($svc.Status) ==="
}

function Install-DatadogAgent {
    Write-Host "=== [DD] Setting Datadog environment variables ==="
    $env:DD_API_KEY        = $DdApiKey
    $env:DD_SITE           = $DdSite
    $env:DD_ENV            = $DdEnv
    $env:DD_REMOTE_UPDATES = "true"

    $tempPath = "C:\Windows\SystemTemp"
    if (-not (Test-Path $tempPath)) {
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    }

    $dd = Join-Path $tempPath "datadog-installer-x86_64.exe"

    Write-Host "=== [DD] Downloading Datadog installer ==="
    try {
        Invoke-WebRequest -Uri "https://install.datadoghq.com/datadog-installer-x86_64.exe" -OutFile $dd
    }
    catch {
        Write-Warning "=== [DD] Download failed: $($_.Exception.Message) ==="
        return
    }

    if (-not (Test-Path $dd)) {
        Write-Warning "=== [DD] Datadog installer file not found after download. Skipping. ==="
        return
    }

    Write-Host "=== [DD] Download complete ==="
    Get-Item $dd | Select-Object FullName, Length, LastWriteTime | Out-String | Write-Host

    Write-Host "=== [DD] Running Datadog installer ==="
    try {
        $proc = Start-Process -FilePath $dd -Wait -NoNewWindow -PassThru
        $ddExit = $proc.ExitCode
        Write-Host "=== [DD] Installer exit code: $ddExit ==="
    }
    catch {
        Write-Warning "=== [DD] Exception while running installer: $($_.Exception.Message) ==="
        return
    }
}

# -------------------------
# Main
# -------------------------
Install-SqlExpress
Install-DatadogAgent

Write-Host "=== [Bootstrap] Script completed (no hard failures). ==="
exit 0
