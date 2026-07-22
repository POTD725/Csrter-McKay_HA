# CARTER / McKAY Home Assistant and PBX Platform

This repository contains the public, secret-free source for the CARTER primary and McKAY standby Proxmox deployment.

## Intended layout

- **CARTER**: active Proxmox host
- **McKAY**: standby Proxmox host
- **VM 100**: Home Assistant OS
- **VM 110**: Windows 11 MG PBX
- **Laptop display**: Atlantis Home Assistant information-screen kiosk
- **Roku TVs**: Atlantis information channel with a replaceable local video loop

## Confirmed network baseline

The active home network is the eero LAN, not the retired upstream `192.168.12.x` network.

| Item | Value |
|---|---:|
| LAN | `192.168.4.0/22` |
| Gateway and DNS | `192.168.4.1` |
| Safe reservation range | `192.168.4.2` through `192.168.6.222` |
| CARTER Proxmox | `192.168.4.121` |
| Proxmox web interface | `https://192.168.4.121:8006` |

CARTER's `192.168.4.121` address is currently the known address and must be reserved in eero before it is treated as permanent. Home Assistant and MG PBX require their own separate addresses. See `docs/NETWORK-PLAN.md`.

## Update the existing CARTER checkout

On CARTER, update the repository and safely repair the untracked local `site.conf` file:

```bash
cd /root/Carter-McKay_HA
git pull origin main
chmod +x scripts/Update-Local-Network-Config.sh
./scripts/Update-Local-Network-Config.sh
```

The updater creates a timestamped backup before changing `config/site.conf`. It preserves valid new VM addresses, but clears retired `192.168.12.x` values and prevents a VM from reusing CARTER's `192.168.4.121` address.

## Start here

For a complete rebuild, begin with:

```text
docs\USB-SETUP-FROM-SCRATCH.md
```

On Windows, double-click:

```text
START-USB-SETUP.cmd
```

Then:

1. Prepare and verify the Atlantis installation USB.
2. Download or clone this repository on the Windows preparation computer.
3. Copy `config/site.example.conf` to `config/site.conf` and fill in the remaining values.
4. Copy `config/private-info.example.ini` to a private location outside this repository.
5. Read `docs/WALKTHROUGH.md` from top to bottom.
6. Run `scripts/Build-Private-Deployment.ps1` to create the private local deployment bundle.
7. Apply `scripts/patch-proxmox-kiosk.sh` only after CARTER Proxmox, Home Assistant, and the PBX VM are stable.

Do not enter any retired `192.168.12.x` address into the new deployment.

## MG PBX Atlantis command interface

The repository includes a secret-free, original Atlantis-inspired theme for the Windows MG PBX dashboard:

```text
MG-PBX-Atlantis-Theme\Install-Atlantis-Theme.bat
```

The installer locates the local MG PBX dashboard, creates a timestamped backup, installs the interface stylesheet and script, and supports one-click rollback. Open `MG-PBX-Atlantis-Theme\preview.html` to see the design without changing the PBX.

The theme changes presentation only. It does not modify extensions, trunks, routing, recordings, credentials, firewall rules, Proxmox networking, or Home Assistant.

## Files that must never be committed

This repository is public. Never upload:

- Home Assistant backups or emergency encryption keys
- Windows product keys or Windows ISO files
- SIP, Twilio, No-IP, PBX, or Home Assistant credentials
- Private certificates or SSH keys
- PBX database exports containing passwords
- Completed private worksheets or generated deployment bundles

The included `.gitignore` blocks the standard private locations, but every commit still needs review.

## Important limitation

The repository stores scripts, templates, themes, and documentation. Licensed operating-system media and private backups are supplied locally when the private deployment bundle or USB is built. Generated private bundles are not intended for GitHub.

## Current stage

The maintained repository provides:

- corrected eero network templates and validation
- a safe updater for the local untracked `site.conf`
- a start-from-scratch USB preparation guide
- a current network plan
- Proxmox laptop kiosk patch and rollback scripts
- Windows PBX preparation script
- MG PBX Atlantis command-interface theme and rollback tool
- application and package manifests
- private bundle builder
- Roku information channel source
- end-to-end installation walkthrough

The older generated ZIP packages can be kept offline as migration references, but the source files in this repository are the maintained version going forward.
