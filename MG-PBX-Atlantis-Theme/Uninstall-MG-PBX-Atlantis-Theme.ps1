[CmdletBinding()]
param(
    [string]$TargetPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-Elevated {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", ('"{0}"' -f $PSCommandPath)
    )
    if ($TargetPath) {
        $arguments += @("-TargetPath", ('"{0}"' -f $TargetPath))
    }
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList ($arguments -join " ")
}

function Select-DashboardFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the MG PBX dashboard folder containing index.html"
    $dialog.ShowNewFolderButton = $false
    $dialog.RootFolder = [Environment+SpecialFolder]::MyComputer
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw "Rollback cancelled. No dashboard folder was selected."
    }
    return $dialog.SelectedPath
}

function Find-DefaultTarget {
    $candidates = @(
        "C:\Atlantis\PBX",
        "C:\Atlantis\PBX\dashboard",
        "C:\Atlantis\PBX\public",
        "C:\Atlantis\PBX\web",
        (Join-Path $env:USERPROFILE "Documents\windows-pbx"),
        (Join-Path $env:LOCALAPPDATA "MG_PBX"),
        (Join-Path $env:LOCALAPPDATA "Grandstream_DP750_DP720_Dashboard")
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate "atlantis-theme-backups") -PathType Container)) {
            return $candidate
        }
    }
    return ""
}

try {
    if (-not (Test-Administrator)) {
        Restart-Elevated
        exit 0
    }

    if (-not $TargetPath) {
        $TargetPath = Find-DefaultTarget
    }
    if (-not $TargetPath) {
        $TargetPath = Select-DashboardFolder
    }

    $TargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
    $indexPath = Join-Path $TargetPath "index.html"
    $themePath = Join-Path $TargetPath "mg-pbx-atlantis"
    $backupRoot = Join-Path $TargetPath "atlantis-theme-backups"
    $latestMetadataPath = Join-Path $backupRoot "latest-install.json"

    if (-not (Test-Path -LiteralPath $latestMetadataPath -PathType Leaf)) {
        throw "No Atlantis theme backup record was found in $backupRoot"
    }

    $metadata = Get-Content -LiteralPath $latestMetadataPath -Raw | ConvertFrom-Json
    $backupPath = [string]$metadata.backup_path
    $backupIndex = Join-Path $backupPath "index.html"
    if (-not (Test-Path -LiteralPath $backupIndex -PathType Leaf)) {
        throw "The recorded backup index.html is missing: $backupIndex"
    }

    $safetyPath = Join-Path $backupRoot ("rollback-safety-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    New-Item -ItemType Directory -Path $safetyPath -Force | Out-Null
    if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
        Copy-Item -LiteralPath $indexPath -Destination (Join-Path $safetyPath "index.html") -Force
    }
    if (Test-Path -LiteralPath $themePath -PathType Container) {
        Copy-Item -LiteralPath $themePath -Destination (Join-Path $safetyPath "mg-pbx-atlantis") -Recurse -Force
        Remove-Item -LiteralPath $themePath -Recurse -Force
    }

    Copy-Item -LiteralPath $backupIndex -Destination $indexPath -Force

    $previousTheme = Join-Path $backupPath "mg-pbx-atlantis"
    if (Test-Path -LiteralPath $previousTheme -PathType Container) {
        Copy-Item -LiteralPath $previousTheme -Destination $themePath -Recurse -Force
    }

    Add-Type -AssemblyName System.Windows.Forms
    $message = @"
The MG PBX Atlantis theme has been rolled back.

Restored backup:
$backupPath

Rollback safety copy:
$safetyPath

Refresh the MG PBX browser with Ctrl+F5 or rebuild the dashboard EXE.
"@
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        "MG PBX Atlantis Theme Rollback",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null

    Write-Host "MG PBX Atlantis theme rolled back." -ForegroundColor Green
    Write-Host "Restored: $backupPath"
    Write-Host "Safety:   $safetyPath"
}
catch {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "MG PBX Atlantis Theme Rollback Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    catch {
        Write-Error $_.Exception.Message
    }
    exit 1
}