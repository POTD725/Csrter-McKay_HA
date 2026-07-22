# Atlantis Roku Information Channel

This folder contains the secret-free source for the Roku information channel.

The video panel reads a JSON playlist from Home Assistant. Videos remain on the Home Assistant server, so the daily or weekly rotation can be changed without rebuilding the Roku channel.

## Home Assistant media folders

Create these folders under `/config/www/atlantis_roku/videos`:

```text
daily
weekly
always
```

Recommended format:

- MP4 container
- H.264 video
- AAC audio
- 720p or 1080p

Files in `/config/www` are available under Home Assistant's `/local` path. Keep this feature on the local network and do not place sensitive private recordings in a publicly reachable folder.

## Build

1. Copy `manifest.example` to `manifest`.
2. Replace `YOUR_HOME_ASSISTANT_IP` with the Home Assistant LAN address.
3. Run `tools/Publish-AtlantisPlaylist.ps1` on Windows after copying videos into the Home Assistant folders.
4. ZIP the contents of the `roku` folder, with `manifest`, `source`, and `components` at the ZIP root.
5. Sideload the ZIP through the Roku Developer Application Installer.

## Remote controls

- **OK**: pause or resume
- **Right**: next video
- **Star**: reload the playlist

The agenda and weather areas are placeholders until the Home Assistant dashboard data bridge is connected.
