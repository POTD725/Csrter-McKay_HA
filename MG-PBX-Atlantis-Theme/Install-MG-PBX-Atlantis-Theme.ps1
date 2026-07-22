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
        throw "Installation cancelled. No dashboard folder was selected."
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
        (Join-Path $env:USERPROFILE "Documents\Codex\2026-06-30\wou\outputs\grandstream_dp750_dp720_package"),
        (Join-Path $env:LOCALAPPDATA "MG_PBX"),
        (Join-Path $env:LOCALAPPDATA "Grandstream_DP750_DP720_Dashboard")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate "index.html") -PathType Leaf)) {
            return $candidate
        }
    }

    if (Test-Path -LiteralPath "C:\Atlantis\PBX" -PathType Container) {
        $found = Get-ChildItem -LiteralPath "C:\Atlantis\PBX" -Filter "index.html" -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) {
            return $found.Directory.FullName
        }
    }

    return ""
}

function Remove-ExistingThemeBlock([string]$Html) {
    $pattern = '(?s)\s*<!-- MG-PBX-ATLANTIS-THEME:START -->.*?<!-- MG-PBX-ATLANTIS-THEME:END -->\s*'
    return [regex]::Replace($Html, $pattern, "`r`n")
}

function Inject-ThemeBlock([string]$Html) {
    $block = @"

<!-- MG-PBX-ATLANTIS-THEME:START -->
<link id="mgpbx-atlantis-style" rel="stylesheet" href="mg-pbx-atlantis/atlantis-theme.css?v=1.0.0">
<script id="mgpbx-atlantis-script" defer src="mg-pbx-atlantis/atlantis-theme.js?v=1.0.0"></script>
<!-- MG-PBX-ATLANTIS-THEME:END -->
"@

    $clean = Remove-ExistingThemeBlock $Html
    if ($clean -match '(?i)</head>') {
        return [regex]::Replace($clean, '(?i)</head>', ($block + "`r`n</head>"), 1)
    }

    if ($clean -match '(?i)<body[^>]*>') {
        return [regex]::Replace($clean, '(?i)(<body[^>]*>)', ('$1' + $block), 1)
    }

    return $block + "`r`n" + $clean
}

try {
    if (-not (Test-Administrator)) {
        Restart-Elevated
        exit 0
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    $themeSource = Join-Path $scriptRoot "theme"
    if (-not (Test-Path -LiteralPath (Join-Path $themeSource "atlantis-theme.css") -PathType Leaf)) {
        throw "Theme files are missing. Extract the full package before running the installer."
    }

    if (-not $TargetPath) {
        $TargetPath = Find-DefaultTarget
    }
    if (-not $TargetPath) {
        $TargetPath = Select-DashboardFolder
    }

    $TargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
    $indexPath = Join-Path $TargetPath "index.html"
    if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "The selected folder does not contain index.html. Please select the MG PBX dashboard folder.",
            "MG PBX Atlantis Theme",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        $TargetPath = Select-DashboardFolder
        $TargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
        $indexPath = Join-Path $TargetPath "index.html"
        if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
            throw "The selected folder still does not contain index.html."
        }
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupRoot = Join-Path $TargetPath "atlantis-theme-backups"
    $backupPath = Join-Path $backupRoot $timestamp
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backupPath "index.html") -Force

    $themeDestination = Join-Path $TargetPath "mg-pbx-atlantis"
    if (Test-Path -LiteralPath $themeDestination -PathType Container) {
        Copy-Item -LiteralPath $themeDestination -Destination (Join-Path $backupPath "mg-pbx-atlantis") -Recurse -Force
        Remove-Item -LiteralPath $themeDestination -Recurse -Force
    }

    New-Item -ItemType Directory -Path $themeDestination -Force | Out-Null
    Copy-Item -Path (Join-Path $themeSource "*") -Destination $themeDestination -Recurse -Force

    $html = [System.IO.File]::ReadAllText($indexPath)
    $updatedHtml = Inject-ThemeBlock $html
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($indexPath, $updatedHtml, $utf8NoBom)

    $metadata = [ordered]@{
        theme = "MG PBX Atlantis Command Interface"
        version = "1.0.0"
        installed_at = (Get-Date).ToString("o")
        target_path = $TargetPath
        backup_path = $backupPath
        index_path = $indexPath
    }
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $themeDestination ".install.json") -Encoding UTF8
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $backupRoot "latest-install.json") -Encoding UTF8

    Add-Type -AssemblyName System.Windows.Forms
    $message = @"
MG PBX Atlantis theme installed successfully.

Dashboard:
$TargetPath

Backup:
$backupPath

Refresh the MG PBX browser with Ctrl+F5 or rebuild the dashboard EXE.
"@
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        "MG PBX Atlantis Theme",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null

    Write-Host "MG PBX Atlantis theme installed." -ForegroundColor Green
    Write-Host "Dashboard: $TargetPath"
    Write-Host "Backup:    $backupPath"
}
catch {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "MG PBX Atlantis Theme Installation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    catch {
        Write-Error $_.Exception.Message
    }
    exit 1
}