# Atlantis Installation USB: Start From Scratch

This guide prepares one reusable USB drive for rebuilding CARTER and later McKAY. It keeps the installer media, drivers, backups, repository, and private worksheet together without placing secrets in GitHub.

## What the USB is for

The USB can carry:

- the current Proxmox VE installer ISO;
- a legitimate Windows 11 ISO;
- the VirtIO driver ISO;
- the latest Home Assistant full backup;
- the CARTER / McKAY repository or private deployment bundle;
- the MG PBX export or project folder;
- checksums and a private fill-in worksheet.

The USB does not contain product keys, passwords, SIP credentials, or the Home Assistant emergency key unless you deliberately place an encrypted private bundle on it.

## Confirmed network baseline

- eero LAN: `192.168.4.0/22`
- gateway and DNS: `192.168.4.1`
- first safe reservation: `192.168.4.2`
- last reported reservation address: `192.168.6.222`
- CARTER Proxmox current address: `192.168.4.121`
- old `192.168.12.x` addresses: retired

Before reinstalling CARTER, create an eero reservation for its verified Ethernet MAC so it continues receiving `192.168.4.121` after the rebuild.

## Required equipment

- A Windows 10 or Windows 11 preparation computer
- One USB drive, preferably 64 GB or larger
- A reliable Ethernet connection to the eero network
- The latest Home Assistant full backup and its emergency key stored separately
- A second storage location for anything currently on the USB

## Phase 1: Protect the current system

Before erasing or reinstalling anything:

1. In Home Assistant, create a new full backup.
2. Download the `.tar` backup to the Windows preparation computer.
3. Store the Home Assistant emergency key separately from the USB.
4. Export or copy the current MG PBX project if it exists.
5. In Proxmox, record the CARTER disk serial and VM IDs.
6. In the eero app, verify CARTER's Ethernet MAC and reserve `192.168.4.121` for it.
7. Confirm Proxmox opens at `https://192.168.4.121:8006` before continuing.

Do not proceed until the Home Assistant backup has been copied off CARTER.

## Phase 2: Download the official installation files

On the Windows preparation computer, download:

1. The current Proxmox VE ISO from the official Proxmox download page.
2. The Windows 11 ISO from Microsoft's official software download page.
3. The current VirtIO Windows driver ISO from the official virtio-win project.
4. The latest Ventoy Windows ZIP from the official Ventoy site.
5. This repository as a ZIP, or update a Git clone with `git pull`.

Avoid third-party ISO mirrors. Keep the original filenames because they make later troubleshooting easier.

## Phase 3: Install Ventoy on the USB

**This erases the selected USB drive.** Verify the drive by size and model before pressing Install.

1. Extract the Ventoy Windows ZIP.
2. Right-click `Ventoy2Disk.exe` and choose **Run as administrator**.
3. Select the correct USB drive.
4. Open **Option > Partition Style** and choose `GPT` for the CARTER UEFI laptop.
5. Click **Install**.
6. Confirm both warning prompts.
7. Wait until Ventoy reports success.
8. Close Ventoy and reconnect the USB if Windows does not immediately show its large data partition.

Do not format the Ventoy data partition when Windows asks unless Ventoy installation failed and you are intentionally starting over.

## Phase 4: Create the Atlantis USB folders

On the large Ventoy data partition, create:

```text
\ATLANTIS
\ATLANTIS\Backups\HomeAssistant
\ATLANTIS\Backups\PBX
\ATLANTIS\Config
\ATLANTIS\Docs
\ATLANTIS\Repository
\ATLANTIS\Checksums
\ISO\Proxmox
\ISO\Windows
\ISO\VirtIO
```

## Phase 5: Copy the files

Copy the files into these locations:

```text
Proxmox ISO      -> \ISO\Proxmox
Windows 11 ISO   -> \ISO\Windows
VirtIO ISO       -> \ISO\VirtIO
HA backup .tar   -> \ATLANTIS\Backups\HomeAssistant
PBX export       -> \ATLANTIS\Backups\PBX
Repository       -> \ATLANTIS\Repository\Carter-McKay_HA
```

Copy `config\private-info.example.ini` to:

```text
\ATLANTIS\Config\FILL-IN-PRIVATE-INFO.ini
```

Fill in only non-secret values at first. Keep passwords, product keys, SIP credentials, and the Home Assistant emergency key off the unencrypted USB.

## Phase 6: Record the known network values

In the USB's private worksheet, record:

```text
LAN CIDR: 192.168.4.0/22
Gateway: 192.168.4.1
DNS: 192.168.4.1
Safe reservation range: 192.168.4.2 through 192.168.6.222
CARTER Proxmox: 192.168.4.121
```

Leave McKAY, Home Assistant, and MG PBX addresses blank until each device is discovered and separately reserved. The Proxmox host and its VMs cannot share an address.

## Phase 7: Verify the USB before rebooting CARTER

Confirm the USB contains all of these:

- one bootable Proxmox ISO;
- the Windows 11 ISO;
- the VirtIO ISO;
- the newest Home Assistant `.tar` backup;
- the repository;
- the private worksheet;
- the PBX export, when available.

Open the Home Assistant backup folder and verify the `.tar` file has a nonzero size. Do not rely only on the filename.

## Phase 8: Boot CARTER from the USB

1. Shut CARTER down cleanly.
2. Insert the Atlantis USB.
3. Turn CARTER on and open its UEFI boot menu.
4. Choose the USB entry labeled `UEFI` or `Ventoy`.
5. In Ventoy, select the Proxmox ISO.
6. Start the normal graphical Proxmox installer.

Do not select the internal disk until its model and capacity match the recorded CARTER target disk. The Proxmox installation erases the selected target disk.

## Phase 9: Network settings during Proxmox installation

Use the eero network, not the retired upstream network:

```text
Hostname: carter
Address: 192.168.4.121/22
Gateway: 192.168.4.1
DNS: 192.168.4.1
```

Use `carter` plus a local domain only if the installer requires a fully qualified hostname. Do not enter `192.168.12.20`, `192.168.12.21`, or `192.168.12.201`.

## Phase 10: First boot verification

After installation:

1. Remove the USB when CARTER restarts.
2. Connect CARTER by Ethernet to the eero-side network.
3. Confirm the console shows `192.168.4.121`.
4. From another eero-connected device, open:

   ```text
   https://192.168.4.121:8006
   ```

5. Sign in as `root` using the Proxmox password created during installation.
6. Update Proxmox before creating or restoring VMs.
7. Restore Home Assistant as VM `100`.
8. Create Windows MG PBX as VM `110`.
9. Discover and reserve separate VM addresses before editing the Atlantis kiosk URL.

## Stop points

Stop and investigate before continuing when:

- the USB model or size does not match the intended USB;
- the Proxmox installer shows the wrong target disk;
- CARTER receives a `192.168.12.x` address;
- the eero reservation for `192.168.4.121` belongs to another MAC;
- the Home Assistant backup is missing or zero bytes;
- Home Assistant and Proxmox appear to have the same address.

After the USB is prepared and verified, continue with `WALKTHROUGH.md`.
