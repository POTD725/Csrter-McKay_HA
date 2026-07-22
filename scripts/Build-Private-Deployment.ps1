[CmdletBinding()]
param(
    [string]$OutputRoot = "$PSScriptRoot\..\output"
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "Carter-McKay-Private-Deployment-$stamp"
$bundleRoot = Join-Path $OutputRoot $bundleName

function Read-Required([string]$Prompt) {
    do { $value = Read-Host $Prompt } while ([string]::IsNullOrWhiteSpace($value))
    return $value.Trim()
}

function Copy-OptionalFile([string]$Prompt, [string]$DestinationFolder) {
    $path = Read-Host "$Prompt (leave blank to add later)"
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    $path = $path.Trim('"')
    if (-not (Test-Path $path -PathType Leaf)) { throw "File not found: $path" }
    New-Item -ItemType Directory -Force -Path $DestinationFolder | Out-Null
    Copy-Item -LiteralPath $path -Destination $DestinationFolder -Force
    return (Split-Path $path -Leaf)
}

function Copy-OptionalFolder([string]$Prompt, [string]$DestinationFolder) {
    $path = Read-Host "$Prompt (leave blank to add later)"
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    $path = $path.Trim('"')
    if (-not (Test-Path $path -PathType Container)) { throw "Folder not found: $path" }
    New-Item -ItemType Directory -Force -Path $DestinationFolder | Out-Null
    robocopy $path $DestinationFolder /MIR /R:2 /W:2 /XD '.git' 'node_modules' '__pycache__' | Out-Host
    if ($LASTEXITCODE -ge 8) { throw "Robocopy failed with exit code $LASTEXITCODE" }
    return (Split-Path $path -Leaf)
}

Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  CARTER / McKAY PRIVATE DEPLOYMENT BUILDER' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'This creates a private local bundle. Do not upload its output to GitHub.' -ForegroundColor Yellow
Write-Host ''

$carterIp = Read-Required 'CARTER Proxmox host IP'
$mckayIp = Read-Required 'McKAY Proxmox host IP'
$haIp = Read-Required 'Shared Home Assistant service IP'
$pbxIp = Read-Required 'Shared MG PBX service IP'
$reservationFirst = Read-Required 'Router reservation block first address'
$reservationLast = Read-Required 'Router reservation block last address'
$carterDiskSerial = Read-Required 'CARTER target disk serial'
$mckayDiskSerial = Read-Required 'McKAY target disk serial'
$dashboardPath = Read-Host 'Home Assistant dashboard path [atlantis-information/0]'
if ([string]::IsNullOrWhiteSpace($dashboardPath)) { $dashboardPath = 'atlantis-information/0' }

New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null
$folders = @(
    'Config', 'Private', 'Media\Windows', 'Media\VirtIO',
    'Migration-Data\HomeAssistant', 'Migration-Data\PBX',
    'Scripts', 'Docs', 'Checksums'
)
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path (Join-Path $bundleRoot $folder) | Out-Null
}

Copy-Item (Join-Path $repoRoot 'scripts\*') (Join-Path $bundleRoot 'Scripts') -Recurse -Force
Copy-Item (Join-Path $repoRoot 'docs\*') (Join-Path $bundleRoot 'Docs') -Recurse -Force
Copy-Item (Join-Path $repoRoot 'manifests') $bundleRoot -Recurse -Force
Copy-Item (Join-Path $repoRoot 'MG-PBX-Atlantis-Theme') $bundleRoot -Recurse -Force
Copy-Item (Join-Path $repoRoot 'README.md') $bundleRoot -Force

$siteTemplate = Get-Content (Join-Path $repoRoot 'config\site.example.conf') -Raw
$site = $siteTemplate `
    -replace 'CARTER_HOST_IP=ENTER_HERE', "CARTER_HOST_IP=$carterIp" `
    -replace 'MCKAY_HOST_IP=ENTER_HERE', "MCKAY_HOST_IP=$mckayIp" `
    -replace 'HOME_ASSISTANT_IP=ENTER_HERE', "HOME_ASSISTANT_IP=$haIp" `
    -replace 'PBX_IP=ENTER_HERE', "PBX_IP=$pbxIp" `
    -replace 'ROUTER_RESERVATION_FIRST=ENTER_HERE', "ROUTER_RESERVATION_FIRST=$reservationFirst" `
    -replace 'ROUTER_RESERVATION_LAST=ENTER_HERE', "ROUTER_RESERVATION_LAST=$reservationLast" `
    -replace 'TARGET_DISK_FILTER_VALUE=ENTER_HERE', "TARGET_DISK_FILTER_VALUE=$carterDiskSerial" `
    -replace 'http://ENTER_HOME_ASSISTANT_IP:8123/ENTER_DASHBOARD_PATH', "http://${haIp}:8123/$dashboardPath"
$site | Set-Content (Join-Path $bundleRoot 'Config\site.conf') -Encoding UTF8

@"
# McKAY-specific disk selection override
TARGET_DISK_FILTER_KEY=ID_SERIAL_SHORT
TARGET_DISK_FILTER_VALUE=$mckayDiskSerial
"@ | Set-Content (Join-Path $bundleRoot 'Config\mckay-disk.conf') -Encoding UTF8

$privateTemplate = Get-Content (Join-Path $repoRoot 'config\private-info.example.ini') -Raw
$private = $privateTemplate `
    -replace 'http://ENTER_HA_IP:8123', "http://${haIp}:8123" `
    -replace 'carter_ip = ENTER_HERE', "carter_ip = $carterIp" `
    -replace 'mckay_ip = ENTER_HERE', "mckay_ip = $mckayIp" `
    -replace 'home_assistant_ip = ENTER_HERE', "home_assistant_ip = $haIp" `
    -replace 'pbx_ip = ENTER_HERE', "pbx_ip = $pbxIp" `
    -replace 'carter_disk_serial = ENTER_HERE', "carter_disk_serial = $carterDiskSerial" `
    -replace 'mckay_disk_serial = ENTER_HERE', "mckay_disk_serial = $mckayDiskSerial"
$private | Set-Content (Join-Path $bundleRoot 'Private\FILL-IN-PRIVATE-INFO.ini') -Encoding UTF8

$windowsIso = Copy-OptionalFile 'Windows 11 ISO path' (Join-Path $bundleRoot 'Media\Windows')
$virtioIso = Copy-OptionalFile 'VirtIO driver ISO path' (Join-Path $bundleRoot 'Media\VirtIO')
$haBackup = Copy-OptionalFile 'Home Assistant full backup .tar path' (Join-Path $bundleRoot 'Migration-Data\HomeAssistant')
$pbxExport = Copy-OptionalFolder 'MG PBX export/project folder path' (Join-Path $bundleRoot 'Migration-Data\PBX')

@"
CARTER / McKAY PRIVATE BUNDLE CONTENTS
======================================
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
CARTER host: $carterIp
McKAY host: $mckayIp
Home Assistant service: $haIp
MG PBX service: $pbxIp
Windows ISO: $windowsIso
VirtIO ISO: $virtioIso
Home Assistant backup: $haBackup
PBX export: $pbxExport
MG PBX theme: MG-PBX-Atlantis-Theme\Install-Atlantis-Theme.bat

Open Docs\WALKTHROUGH.md and complete the phases in order.
Keep this entire bundle private.
"@ | Set-Content (Join-Path $bundleRoot 'START-HERE.txt') -Encoding UTF8

$hashFile = Join-Path $bundleRoot 'Checksums\SHA256SUMS.txt'
Get-ChildItem $bundleRoot -File -Recurse | Where-Object FullName -ne $hashFile | ForEach-Object {
    $relative = $_.FullName.Substring($bundleRoot.Length + 1)
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $relative"
} | Set-Content $hashFile -Encoding ASCII

$archive = Join-Path $OutputRoot "$bundleName.7z"
$sevenZip = @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "$env:ProgramFiles(x86)\7-Zip\7z.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $sevenZip -and (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Host 'Installing 7-Zip for large ISO-safe packaging...'
    winget.exe install --id 7zip.7zip -e --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
    $sevenZip = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "$env:ProgramFiles(x86)\7-Zip\7z.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if ($sevenZip) {
    & $sevenZip a -t7z -mx=5 -mhe=on $archive $bundleRoot
    if ($LASTEXITCODE -ne 0) { throw "7-Zip failed with exit code $LASTEXITCODE" }
    Write-Host "Private one-file bundle created: $archive" -ForegroundColor Green
}
else {
    Write-Warning '7-Zip is unavailable. The prepared private folder was created, but the one-file archive was not.'
}

Write-Host "Prepared folder: $bundleRoot"
Write-Host 'Do not commit the output folder or archive to the public repository.' -ForegroundColor Yellow