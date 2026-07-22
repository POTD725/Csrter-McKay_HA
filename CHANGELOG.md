# Change and Fix Ledger

## 2026-07-22 initial source import

### Consolidated deployment structure

- Added a public, secret-free repository structure.
- Added separate public and private configuration templates.
- Added a private local one-file deployment builder.
- Added SHA-256 generation for the private bundle.
- Added explicit drop zones for Windows ISO, VirtIO ISO, Home Assistant backup, and PBX export.

### Network configuration repairs

- Replaced hard-coded low IP assumptions with fill-in reservation range fields.
- Added separate fields for CARTER, McKAY, shared Home Assistant, and shared PBX addresses.
- Preserved the design where McKAY service VMs remain stopped until failover.
- Added target-disk serial fields to avoid unsafe drive-letter or device-name assumptions.

### Proxmox host display upgrade

- Added a lightweight Chromium/Openbox/LightDM kiosk patch.
- Added a Home Assistant startup-wait screen.
- Added automatic Chromium restart.
- Disabled display blanking and sleep for the information screen.
- Added a one-click Windows-to-CARTER SSH patch launcher.
- Added a rollback path that restores the normal text console target.
- Kept the kiosk patch separate from VM 100 and VM 110.

### Windows 11 MG PBX completion

- Added an application manifest for Python 3.11, Node.js LTS, Git, 7-Zip, Visual C++ runtime, and WebView2.
- Preserved Defender, Windows Update, Remote Desktop, OpenSSH, PowerShell, networking, and system frameworks.
- Added dedicated PBX, log, backup, and installer-drop folders.
- Added automatic PBX startup through Task Scheduler.
- Added recognition for PowerShell, CMD, Node, Python, and npm startup entry points.
- Added a local PBX status command.

### Home Assistant and Roku display

- Added Roku SceneGraph source for the Atlantis information channel.
- Added replaceable daily, weekly, and always video rotations.
- Added a PowerShell playlist publisher for Home Assistant-hosted media.
- Kept Disney+ and Prime Video outside the embedded video window because those services run as separate Roku applications.

### Privacy and repository safety

- Added exclusions for ISO files, HA backups, PBX exports, generated bundles, passwords, keys, and certificates.
- Added a private information worksheet with spaces for values needed later in the process.
- Added repeated warnings that the repository is public and completed private worksheets must not be committed.

## Historical builder problems accounted for

The consolidated source structure is designed to avoid or surface the failures encountered during earlier generated builds, including:

- Windows drive path handling and D-drive source locations
- WSL exit-code propagation
- Linux mount-path creation and missing operand errors
- live prompt visibility during long ISO operations
- Proxmox package/repository ordering
- accidental use of router addresses outside the permitted reservation block
- repeated re-entry of IP addresses
- unsafe target-disk selection by generic device name

The older generated hotfix ZIPs remain migration references. Their fixes should be maintained in readable source here rather than accumulated as opaque patch archives.
