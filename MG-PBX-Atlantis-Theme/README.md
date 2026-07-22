# MG PBX Atlantis Command Interface

This package adds an original Atlantis-inspired command-console appearance to the local MG PBX web dashboard.

It is intentionally **secret-free**. No SIP credentials, extension passwords, Twilio information, certificates, Windows product keys, or Home Assistant backup data are included.

## What changes

The installer adds three references to the PBX dashboard's `index.html` and copies a small theme folder beside it:

- `atlantis-theme.css`
- `atlantis-theme.js`
- `mg-pbx-atlantis.svg`

The JavaScript adds a compact command header, clock, interface status, and optional interface tones. The CSS restyles common dashboard panels, tables, buttons, forms, alerts, navigation elements, and cards without changing PBX data or telephony settings.

## One-click installation

1. Extract this repository on the Windows MG PBX virtual machine.
2. Open this folder.
3. Double-click `Install-Atlantis-Theme.bat`.
4. The installer first looks for `C:\Atlantis\PBX\index.html`.
5. If it is not found, choose the folder containing your MG PBX `index.html`.
6. Confirm the preview, then relaunch MG PBX or refresh its browser window with `Ctrl+F5`.

The installer creates a timestamped backup under:

```text
<MG PBX folder>\atlantis-theme-backups\YYYYMMDD-HHMMSS
```

## One-click rollback

Double-click `Uninstall-Atlantis-Theme.bat`. The uninstaller restores the newest installer backup and leaves the backup archive in place.

## Preview before installation

Open `preview.html` in Microsoft Edge. It uses demonstration extensions and fake system information only.

## Supported dashboard types

The theme works best with static HTML dashboards and local web frontends whose main entry point is `index.html`. It deliberately uses broad, defensive selectors so it can style:

- vanilla HTML dashboards
- Bootstrap-style layouts
- card-based dashboards
- tables and extension rosters
- status widgets
- common form controls

If MG PBX is later converted to React, Vue, or another framework, the same CSS and JavaScript can be loaded from the application's root template.

## Manual installation

Copy the `theme` folder into the PBX dashboard and add the following before `</head>`:

```html
<!-- MG-PBX-ATLANTIS-THEME:START -->
<link rel="stylesheet" href="theme/atlantis-theme.css">
<script defer src="theme/atlantis-theme.js"></script>
<!-- MG-PBX-ATLANTIS-THEME:END -->
```

If you copy the files to a different folder name, update the two paths.

## Design notes

The package uses original CSS gradients, geometric borders, concentric-ring artwork, and system fonts. It does not copy television screenshots, logos, proprietary fonts, or production artwork.