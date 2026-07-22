[CmdletBinding()]
param(
    [string]$SiteConfig = "$PSScriptRoot\..\config\site.conf"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SiteConfig)) {
    Write-Host 'The filled site.conf file was not found.' -ForegroundColor Yellow
    Write-Host 'Copy config\site.example.conf to config\site.conf and fill in the values first.'
    exit 1
}

$config = @{}
Get-Content $SiteConfig | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
        $name, $value = $line.Split('=', 2)
        $config[$name.Trim()] = $value.Trim()
    }
}

$carterIp = $config['CARTER_HOST_IP']
if ([string]::IsNullOrWhiteSpace($carterIp) -or $carterIp -like '*ENTER*') {
    $carterIp = Read-Host 'CARTER Proxmox host IP'
}

$kioskUrl = $config['ATLANTIS_KIOSK_URL']
if ([string]::IsNullOrWhiteSpace($kioskUrl) -or $kioskUrl -like '*ENTER*') {
    throw 'ATLANTIS_KIOSK_URL is incomplete in site.conf.'
}

foreach ($tool in @('ssh.exe', 'scp.exe')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is unavailable. Install the Windows OpenSSH Client optional feature first."
    }
}

Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  CURRENT CARTER DISPLAY PATCH' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host "CARTER: $carterIp"
Write-Host "Dashboard: $kioskUrl"
Write-Host ''
Write-Host 'This patch installs a lightweight local display on the Proxmox host.' -ForegroundColor Yellow
Write-Host 'It does not edit VM 100 or VM 110 and does not stop either VM.'
$confirm = Read-Host 'Type APPLY to continue'
if ($confirm -cne 'APPLY') {
    Write-Host 'Patch cancelled.'
    exit 0
}

$remoteRoot = '/opt/atlantis'
$patchScript = Join-Path $PSScriptRoot 'patch-proxmox-kiosk.sh'
$rollbackScript = Join-Path $PSScriptRoot 'rollback-proxmox-kiosk.sh'

& ssh.exe "root@$carterIp" "mkdir -p $remoteRoot/config $remoteRoot/bin"
if ($LASTEXITCODE -ne 0) { throw 'Could not connect to CARTER over SSH.' }

& scp.exe $SiteConfig "root@${carterIp}:$remoteRoot/config/site.conf"
if ($LASTEXITCODE -ne 0) { throw 'Could not copy site.conf.' }

& scp.exe $patchScript "root@${carterIp}:$remoteRoot/bin/patch-proxmox-kiosk.sh"
if ($LASTEXITCODE -ne 0) { throw 'Could not copy the kiosk patch.' }

& scp.exe $rollbackScript "root@${carterIp}:$remoteRoot/bin/rollback-proxmox-kiosk.sh"
if ($LASTEXITCODE -ne 0) { throw 'Could not copy the rollback script.' }

& ssh.exe "root@$carterIp" "chmod 700 $remoteRoot/bin/*.sh && $remoteRoot/bin/patch-proxmox-kiosk.sh $remoteRoot/config/site.conf"
if ($LASTEXITCODE -ne 0) { throw 'The CARTER kiosk patch returned an error.' }

Write-Host ''
Write-Host 'The CARTER display patch is installed.' -ForegroundColor Green
Write-Host 'Reboot CARTER from the Proxmox interface when you are ready for the laptop screen to switch to kiosk mode.'
Write-Host 'Rollback command on CARTER:'
Write-Host '  /opt/atlantis/bin/rollback-proxmox-kiosk.sh'
