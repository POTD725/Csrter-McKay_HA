# CARTER / McKAY Home Assistant and PBX Platform

This repository contains the public, secret-free source for the CARTER primary and McKAY standby Proxmox deployment.

## Intended layout

- **CARTER**: active Proxmox host
- **McKAY**: standby Proxmox host
- **VM 100**: Home Assistant OS
- **VM 110**: Windows 11 MG PBX
- **Laptop display**: Atlantis Home Assistant information-screen kiosk
- **Roku TVs**: Atlantis information channel with a replaceable local video loop

## Start here

1. Download or clone this repository on a Windows computer.
2. Copy `config/site.example.conf` to `config/site.conf` and fill in the network values.
3. Copy `config/private-info.example.ini` to a private location outside this repository and fill it in only when required.
4. Read `docs/WALKTHROUGH.md` from top to bottom.
5. Run `scripts/Build-Private-Deployment.ps1` to create the private local deployment bundle.
6. Apply `scripts/patch-proxmox-kiosk.sh` only after CARTER Proxmox, Home Assistant, and the PBX VM are stable.

## Files that must never be committed

This repository is public. Never upload:

- Home Assistant backups or emergency encryption keys
- Windows product keys or Windows ISO files
- SIP, Twilio, No-IP, PBX, or Home Assistant credentials
- Private certificates or SSH keys
- PBX database exports containing passwords

The included `.gitignore` blocks the standard private locations, but it is still your responsibility to review every commit.

## Important limitation

The repository stores scripts, templates, and documentation. Licensed operating-system media and private backups are supplied locally when the private deployment bundle is built. The generated private bundle is not intended for GitHub.

## Current stage

The first repository upload provides:

- safe configuration templates
- Proxmox laptop kiosk patch and rollback scripts
- Windows PBX preparation script
- application and package manifests
- private bundle builder
- simple installation walkthrough

The older generated ZIP packages can be kept offline as migration references, but the source files in this repository should become the maintained version going forward.
