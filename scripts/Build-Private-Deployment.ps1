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

function Read-WithDefault([string]$Prompt, [string]$DefaultValue) {
    $value = Read-Host "$Prompt [$DefaultValue]"
    if ([string]::IsNullOrWhiteSpace($value)) { return $DefaultValue }
    return $value.Trim()
}

function Assert-IPv4([string]$Name, [string]$Value) {
    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($Value, [ref]$parsed) -or
        $parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "$Name is not a valid IPv4 address: $Value"
    }
}

function Convert-IPv4ToUInt32([string]$Address) {
    $bytes = ([System.Net.IPAddress]::Parse($Address)).GetAddressBytes()
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function Assert-InRange([string]$Name, [string]$Value, [string]$First, [string]$Last) {
    $number = Convert-IPv4ToUInt32 $Value
    $firstNumber = Convert-IPv4ToUInt32 $First
    $lastNumber = Convert-IPv4ToUInt32 $Last
    if ($number -lt $firstNumber -or $number -gt $lastNumber) {
        throw "$Name ($Value) is outside the safe eero reservation range $First through $Last."
    }
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
Write-Host 'Confirmed eero baseline: 192.168.4.0/22, gateway 192.168.4.1.'
Write-Host 'The retired 192.168.12.x addresses are not valid for this deployment.' -ForegroundColor Yellow
Write-Host ''

$lanCidr = Read-WithDefault 'LAN CIDR' '192.168.4.0/22'
$gatewayIp = Read-WithDefault 'eero gateway IP' '192.168.4.1'
$dnsIp = Read-WithDefault 'DNS IP' '192.168.4.1'
$reservationFirst = Read-WithDefault 'First safe eero reservation address' '192.168.4.2'
$reservationLast = Read-WithDefault 'Last eero reservation address' '192.168.6.222'
$carterIp = Read-WithDefault 'CARTER Proxmox host IP' '192.168.4.121'
$mckayIp = Read-Required 'McKAY Proxmox host IP'
$haIp = Read-Required 'Shared Home Assistant service IP'
$pbxIp = Read-Required 'Shared MG PBX service IP'
$carterDiskSerial = Read-Required 'CARTER target disk serial'
$mckayDiskSerial = Read-Required 'McKAY target disk serial'
$dashboardPath = Read-Host 'Home Assistant dashboard path [atlantis-information/0]'
if ([string]::IsNullOrWhiteSpace($dashboardPath)) { $dashboardPath = 'atlantis-information/0' }

foreach ($entry in @{
    'Gateway IP' = $gatewayIp
    'DNS IP' = $dnsIp
    'Reservation first' = $reservationFirst
    'Reservation last' = $reservationLast
    'CARTER IP' = $carterIp
    'McKAY IP' = $mckayIp
    'Home Assistant IP' = $haIp
    'MG PBX IP' = $pbxIp
}.GetEnumerator()) {
    Assert-IPv4 $entry.Key $entry.Value
}

if ($gatewayIp -ne '192.168.4.1') {
    Write-Warning "The gateway differs from the confirmed eero gateway 192.168.4.1: $gatewayIp"
}

$serviceAddresses = @($carterIp, $mckayIp, $haIp, $pbxIp)
if (($serviceAddresses | Select-Object -Unique).Count -ne $serviceAddresses.Count) {
    throw 'CARTER, McKAY, Home Assistant, and MG PBX must each have a different address.'
}

Assert-InRange 'CARTER IP' $carterIp $reservationFirst $reservationLast
Assert-InRange 'McKAY IP' $mckayIp $reservationFirst $reservationLast
Assert-InRange 'Home Assistant IP' $haIp $reservationFirst $reservationLast
Assert-InRange 'MG PBX IP' $pbxIp $reservationFirst $reservationLast

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
    -replace '(?m)^LAN_CIDR=.*$', "LAN_CIDR=$lanCidr" `
    -replace '(?m)^GATEWAY_IP=.*$', "GATEWAY_IP=$gatewayIp" `
    -replace '(?m)^DNS_IP=.*$', "DNS_IP=$dnsIp" `
    -replace '(?m)^CARTER_HOST_IP=.*$', "CARTER_HOST_IP=$carterIp" `
    -replace '(?m)^CARTER_HOST_IP_STATUS=.*$', 'CARTER_HOST_IP_STATUS=RESERVED' `
    -replace '(?m)^MCKAY_HOST_IP=.*$', "MCKAY_HOST_IP=$mckayIp" `
    -replace '(?m)^HOME_ASSISTANT_IP=.*$', "HOME_ASSISTANT_IP=$haIp" `
    -replace '(?m)^PBX_IP=.*$', "PBX_IP=$pbxIp" `
    -replace '(?m)^ROUTER_RESERVATION_FIRST=.*$', "ROUTER_RESERVATION_FIRST=$reservationFirst" `
    -replace '(?m)^ROUTER_RESERVATION_LAST=.*$', "ROUTER_RESERVATION_LAST=$reservationLast" `
    -replace '(?m)^TARGET_DISK_FILTER_VALUE=.*$', "TARGET_DISK_FILTER_VALUE=$carterDiskSerial" `
    -replace '(?m)^ATLANTIS_KIOSK_URL=.*$', "ATLANTIS_KIOSK_URL=http://${haIp}:8123/$dashboardPath"
$site | Set-Content (Join-Path $bundleRoot 'Config\site.conf') -Encoding UTF8

@"
# McKAY-specific disk selection override
TARGET_DISK_FILTER_KEY=ID_SERIAL_SHORT
TARGET_DISK_FILTER_VALUE=$mckayDiskSerial
"@ | Set-Content (Join-Path $bundleRoot 'Config\mckay-disk.conf') -Encoding UTF8

$privateTemplate = Get-Content (Join-Path $repoRoot 'config\private-info.example.ini') -Raw
$private = $privateTemplate `
    -replace '(?m)^local_url\s*=.*$', "local_url = http://${haIp}:8123" `
    -replace '(?m)^carter_ip\s*=.*$', "carter_ip = $carterIp" `
    -replace '(?m)^mckay_ip\s*=.*$', "mckay_ip = $mckayIp" `
    -replace '(?m)^carter_disk_serial\s*=.*$', "carter_disk_serial = $carterDiskSerial" `
    -replace '(?m)^mckay_disk_serial\s*=.*$', "mckay_disk_serial = $mckayDiskSerial" `
    -replace '(?m)^carter_host_ip\s*=.*$', "carter_host_ip = $carterIp" `
    -replace '(?m)^mckay_host_ip\s*=.*$', "mckay_host_ip = $mckayIp" `
    -replace '(?m)^home_assistant_ip\s*=.*$', "home_assistant_ip = $haIp" `
    -replace '(?m)^pbx_ip\s*=.*$', "pbx_ip = $pbxIp"
$private | Set-Content (Join-Path $bundleRoot 'Private\FILL-IN-PRIVATE-INFO.ini') -Encoding UTF8

$windowsIso = Copy-OptionalFile 'Windows 11 ISO path' (Join-Path $bundleRoot 'Media\Windows')
$virtioIso = Copy-OptionalFile 'VirtIO driver ISO path' (Join-Path $bundleRoot 'Media\VirtIO')
$haBackup = Copy-OptionalFile 'Home Assistant full backup .tar path' (Join-Path $bundleRoot 'Migration-Data\HomeAssistant')
$pbxExport = Copy-OptionalFolder 'MG PBX export/project folder path' (Join-Path $bundleRoot 'Migration-Data\PBX')

@"
CARTER / McKAY PRIVATE BUNDLE CONTENTS
======================================
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
LAN: $lanCidr
Gateway/DNS: $gatewayIp / $dnsIp
Safe reservation range: $reservationFirst through $reservationLast
CARTER host: $carterIp
McKAY host: $mckayIp
Home Assistant service: $haIp
MG PBX service: $pbxIp
Windows ISO: $windowsIso
VirtIO ISO: $virtioIso
Home Assistant backup: $haBackup
PBX export: $pbxExport
MG PBX theme: MG-PBX-Atlantis-Theme\Install-Atlantis-Theme.bat

Open Docs\USB-SETUP-FROM-SCRATCH.md first, then Docs\WALKTHROUGH.md.
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
