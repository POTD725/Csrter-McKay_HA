[CmdletBinding()]
param(
    [string]$DriveLetter
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Read-OptionalFile([string]$Prompt) {
    $path = Read-Host "$Prompt (leave blank to skip)"
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    $path = $path.Trim('"')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "File not found: $path"
    }
    return (Resolve-Path -LiteralPath $path).Path
}

function Read-OptionalFolder([string]$Prompt) {
    $path = Read-Host "$Prompt (leave blank to skip)"
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    $path = $path.Trim('"')
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        throw "Folder not found: $path"
    }
    return (Resolve-Path -LiteralPath $path).Path
}

function Copy-SelectedFile([string]$Source, [string]$Destination) {
    if (-not $Source) { return }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-Host "Copied: $Source" -ForegroundColor Green
}

Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  ATLANTIS USB CONTENT PREPARATION' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'This helper does not format the USB and does not install Ventoy.' -ForegroundColor Yellow
Write-Host 'Install Ventoy first by following Docs\USB-SETUP-FROM-SCRATCH.md.' -ForegroundColor Yellow
Write-Host ''

if ([string]::IsNullOrWhiteSpace($DriveLetter)) {
    $DriveLetter = Read-Host 'USB drive letter, for example E'
}

$DriveLetter = $DriveLetter.Trim().TrimEnd(':')
if ($DriveLetter -notmatch '^[A-Za-z]$') {
    throw "Invalid drive letter: $DriveLetter"
}

$drive = "$($DriveLetter.ToUpper()):"
$root = "$drive\"
if (-not (Test-Path $root -PathType Container)) {
    throw "Drive not found: $drive"
}

$volume = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'"
if (-not $volume) { throw "Could not inspect drive $drive" }

$sizeGb = if ($volume.Size) { [math]::Round($volume.Size / 1GB, 1) } else { 0 }
$freeGb = if ($volume.FreeSpace) { [math]::Round($volume.FreeSpace / 1GB, 1) } else { 0 }

Write-Host "Selected drive: $drive"
Write-Host "Volume label: $($volume.VolumeName)"
Write-Host "Capacity: $sizeGb GB"
Write-Host "Free space: $freeGb GB"
Write-Host ''
Write-Host 'No existing files will be intentionally deleted, but files with the same names may be replaced.' -ForegroundColor Yellow
$confirmation = Read-Host "Type PREPARE-$($DriveLetter.ToUpper()) to continue"
if ($confirmation -cne "PREPARE-$($DriveLetter.ToUpper())") {
    Write-Host 'USB preparation cancelled.'
    exit 0
}

$folders = @(
    'ATLANTIS',
    'ATLANTIS\Backups\HomeAssistant',
    'ATLANTIS\Backups\PBX',
    'ATLANTIS\Config',
    'ATLANTIS\Docs',
    'ATLANTIS\Repository\Carter-McKay_HA',
    'ATLANTIS\Checksums',
    'ISO\Proxmox',
    'ISO\Windows',
    'ISO\VirtIO'
)
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $folder) | Out-Null
}

$repoDestination = Join-Path $root 'ATLANTIS\Repository\Carter-McKay_HA'
if ($repoRoot.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Warning 'The repository is already running from the selected USB. Repository copy was skipped to avoid recursive copying.'
}
else {
    robocopy $repoRoot $repoDestination /E /R:2 /W:2 /XD '.git' 'output' 'node_modules' '__pycache__' | Out-Host
    if ($LASTEXITCODE -ge 8) { throw "Repository copy failed with robocopy exit code $LASTEXITCODE" }
}

Copy-Item (Join-Path $repoRoot 'docs\USB-SETUP-FROM-SCRATCH.md') (Join-Path $root 'ATLANTIS\Docs') -Force
Copy-Item (Join-Path $repoRoot 'docs\WALKTHROUGH.md') (Join-Path $root 'ATLANTIS\Docs') -Force
Copy-Item (Join-Path $repoRoot 'docs\NETWORK-PLAN.md') (Join-Path $root 'ATLANTIS\Docs') -Force
Copy-Item (Join-Path $repoRoot 'config\private-info.example.ini') (Join-Path $root 'ATLANTIS\Config\FILL-IN-PRIVATE-INFO.ini') -Force

$proxmoxIso = Read-OptionalFile 'Proxmox VE ISO path'
$windowsIso = Read-OptionalFile 'Windows 11 ISO path'
$virtioIso = Read-OptionalFile 'VirtIO ISO path'
$haBackup = Read-OptionalFile 'Home Assistant full backup .tar path'
$pbxFolder = Read-OptionalFolder 'MG PBX export/project folder path'

Copy-SelectedFile $proxmoxIso (Join-Path $root 'ISO\Proxmox')
Copy-SelectedFile $windowsIso (Join-Path $root 'ISO\Windows')
Copy-SelectedFile $virtioIso (Join-Path $root 'ISO\VirtIO')
Copy-SelectedFile $haBackup (Join-Path $root 'ATLANTIS\Backups\HomeAssistant')

if ($pbxFolder) {
    $pbxDestination = Join-Path $root 'ATLANTIS\Backups\PBX'
    robocopy $pbxFolder $pbxDestination /E /R:2 /W:2 /XD '.git' 'node_modules' '__pycache__' | Out-Host
    if ($LASTEXITCODE -ge 8) { throw "PBX copy failed with robocopy exit code $LASTEXITCODE" }
}

$checksumFile = Join-Path $root 'ATLANTIS\Checksums\SHA256SUMS.txt'
Get-ChildItem $root -File -Recurse |
    Where-Object FullName -ne $checksumFile |
    ForEach-Object {
        $relative = $_.FullName.Substring($root.Length)
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $relative"
    } | Set-Content $checksumFile -Encoding ASCII

@"
ATLANTIS USB
============
Prepared: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Network: 192.168.4.0/22
Gateway/DNS: 192.168.4.1
CARTER Proxmox: 192.168.4.121
Safe reservation range: 192.168.4.2 through 192.168.6.222

Read ATLANTIS\Docs\USB-SETUP-FROM-SCRATCH.md before rebooting CARTER.
Verify that the Home Assistant backup exists and has a nonzero size.
The retired 192.168.12.x addresses must not be used.
"@ | Set-Content (Join-Path $root 'ATLANTIS\START-HERE.txt') -Encoding UTF8

Write-Host ''
Write-Host 'Atlantis USB content preparation is complete.' -ForegroundColor Green
Write-Host "Start here: $root`ATLANTIS\START-HERE.txt"
Write-Host 'Ventoy installation and boot testing are separate steps in the USB guide.' -ForegroundColor Yellow
