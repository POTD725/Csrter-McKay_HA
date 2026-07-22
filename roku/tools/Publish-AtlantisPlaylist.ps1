[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$HomeAssistantHost,

    [ValidateSet('daily', 'weekly', 'all')]
    [string]$Mode = 'all'
)

$ErrorActionPreference = 'Stop'
$shareRoot = "\\$HomeAssistantHost\config\www\atlantis_roku"

if (-not (Test-Path $shareRoot)) {
    throw "Cannot reach $shareRoot. Confirm Home Assistant Samba Share is running."
}

$extensions = @('.mp4', '.m4v', '.mov')
$folders = switch ($Mode) {
    'daily'  { @('daily', 'always') }
    'weekly' { @('weekly', 'always') }
    'all'    { @('daily', 'weekly', 'always') }
}

$items = [System.Collections.Generic.List[object]]::new()
foreach ($folder in $folders) {
    $path = Join-Path $shareRoot "videos\$folder"
    New-Item -ItemType Directory -Force -Path $path | Out-Null

    Get-ChildItem -Path $path -File |
        Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object Name |
        ForEach-Object {
            $encodedName = [Uri]::EscapeDataString($_.Name)
            $items.Add([ordered]@{
                title        = $_.BaseName
                url          = "http://${HomeAssistantHost}:8123/local/atlantis_roku/videos/$folder/$encodedName"
                streamFormat = 'mp4'
                folder       = $folder
            })
        }
}

$playlist = [ordered]@{
    title   = 'Atlantis Video Loop'
    mode    = $Mode
    loop    = $true
    shuffle = $false
    updated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    videos  = $items
}

$playlist | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $shareRoot 'playlist.json') -Encoding UTF8

Write-Host "Playlist published: $($items.Count) video(s), mode $Mode" -ForegroundColor Green
Write-Host "http://${HomeAssistantHost}:8123/local/atlantis_roku/playlist.json"
