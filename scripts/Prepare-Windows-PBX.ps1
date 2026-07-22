[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\Atlantis',
    [string]$PbxSource = '',
    [switch]$InstallOptionalTools
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    throw 'Run this script from an elevated PowerShell window.'
}

$folders = @(
    $InstallRoot,
    (Join-Path $InstallRoot 'PBX'),
    (Join-Path $InstallRoot 'Logs'),
    (Join-Path $InstallRoot 'Backups'),
    (Join-Path $InstallRoot 'Installer-Drop'),
    (Join-Path $InstallRoot 'Config')
)
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
}

$log = Join-Path $InstallRoot ('Logs\prepare-windows-pbx-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Start-Transcript -Path $log -Force

try {
    Write-Host 'Configuring Windows for the dedicated MG PBX VM...' -ForegroundColor Cyan

    # Keep the server awake while preserving Windows Update and Defender.
    powercfg /change standby-timeout-ac 0 | Out-Null
    powercfg /change hibernate-timeout-ac 0 | Out-Null
    powercfg /change monitor-timeout-ac 15 | Out-Null

    # Enable Remote Desktop for local-network maintenance.
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
    Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue

    # Install and enable OpenSSH Server.
    $sshCapability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*' | Select-Object -First 1
    if ($sshCapability -and $sshCapability.State -ne 'Installed') {
        Add-WindowsCapability -Online -Name $sshCapability.Name | Out-Null
    }
    if (Get-Service sshd -ErrorAction SilentlyContinue) {
        Set-Service -Name sshd -StartupType Automatic
        Start-Service sshd
        if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
        }
    }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Warning 'winget was not found. Install or update Microsoft App Installer, then run this script again.'
    }
    else {
        $requiredApps = @(
            'Python.Python.3.11',
            'OpenJS.NodeJS.LTS',
            'Git.Git',
            '7zip.7zip',
            'Microsoft.VCRedist.2015+.x64',
            'Microsoft.EdgeWebView2Runtime'
        )
        $optionalApps = @('Notepad++.Notepad++', 'Microsoft.VisualStudioCode')
        $apps = if ($InstallOptionalTools) { $requiredApps + $optionalApps } else { $requiredApps }

        foreach ($app in $apps) {
            Write-Host "Installing or updating $app..."
            & winget.exe install --id $app -e --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
            if ($LASTEXITCODE -notin @(0, -1978335189)) {
                Write-Warning "winget returned exit code $LASTEXITCODE for $app. Review the log before continuing."
            }
        }
    }

    if ($PbxSource) {
        if (-not (Test-Path $PbxSource)) {
            throw "PBX source path does not exist: $PbxSource"
        }
        Write-Host 'Copying the PBX project...'
        robocopy $PbxSource (Join-Path $InstallRoot 'PBX') /MIR /R:2 /W:2 /XD '.git' 'node_modules' '__pycache__'
        if ($LASTEXITCODE -ge 8) {
            throw "Robocopy failed with exit code $LASTEXITCODE"
        }
    }

    $launcherPath = Join-Path $InstallRoot 'Start-MG-PBX.ps1'
    @'
$ErrorActionPreference = 'Stop'
$root = 'C:\Atlantis\PBX'
$logDir = 'C:\Atlantis\Logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Set-Location $root

$entryPoints = @(
    @{ Path = 'start-pbx.ps1'; Type = 'powershell' },
    @{ Path = 'start-pbx.cmd'; Type = 'cmd' },
    @{ Path = 'start-pbx.bat'; Type = 'cmd' },
    @{ Path = 'server.js'; Type = 'node' },
    @{ Path = 'app.py'; Type = 'python' },
    @{ Path = 'main.py'; Type = 'python' }
)

foreach ($entry in $entryPoints) {
    $candidate = Join-Path $root $entry.Path
    if (Test-Path $candidate) {
        switch ($entry.Type) {
            'powershell' { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $candidate }
            'cmd'        { & cmd.exe /c $candidate }
            'node'       { & node.exe $candidate }
            'python'     { & python.exe $candidate }
        }
        exit $LASTEXITCODE
    }
}

$packageJson = Join-Path $root 'package.json'
if (Test-Path $packageJson) {
    & npm.cmd start
    exit $LASTEXITCODE
}

"No recognized PBX startup file was found in $root" | Out-File (Join-Path $logDir 'pbx-startup-error.txt') -Append
exit 2
'@ | Set-Content -Path $launcherPath -Encoding UTF8

    $taskName = 'MG PBX Automatic Startup'
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User 'SYSTEM' -RunLevel Highest -Description 'Starts the dedicated MG PBX after Windows boots.' | Out-Null

    $statusScript = Join-Path $InstallRoot 'PBX-STATUS.cmd'
    @"
@echo off
setlocal
cls
echo ============================================================
echo   MG PBX STATUS
echo ============================================================
sc query sshd
echo.
schtasks /query /tn "MG PBX Automatic Startup" /v /fo list
echo.
netstat -ano | findstr LISTENING
pause
"@ | Set-Content -Path $statusScript -Encoding ASCII

    Write-Host ''
    Write-Host 'Windows PBX preparation completed.' -ForegroundColor Green
    Write-Host "PBX folder: $InstallRoot\PBX"
    Write-Host "Drop files here: $InstallRoot\Installer-Drop"
    Write-Host "Log: $log"
    Write-Host 'Restart Windows after the PBX project has been copied and its dependencies installed.'
}
finally {
    Stop-Transcript | Out-Null
}
