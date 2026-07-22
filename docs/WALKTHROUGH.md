# CARTER / McKAY Installation Walkthrough

This is the end-to-end build order for the CARTER primary and McKAY standby platform. For a rebuild, follow the parts in order and do not jump ahead to the kiosk or PBX theme.

The public repository contains no passwords, encryption keys, product keys, backups, or licensed ISO files.

## Confirmed network baseline

| Item | Value |
|---|---:|
| eero LAN | `192.168.4.0/22` |
| eero gateway | `192.168.4.1` |
| DNS | `192.168.4.1` |
| Safe reservation range | `192.168.4.2` through `192.168.6.222` |
| CARTER Proxmox | `192.168.4.121` |
| CARTER web interface | `https://192.168.4.121:8006` |

The old `192.168.12.x` network is retired. Do not use `.12.20`, `.12.21`, `.12.201`, or `.12.1` anywhere in the new deployment.

CARTER Proxmox, Home Assistant, and MG PBX are separate systems and must have separate addresses. Home Assistant and PBX addresses remain unknown until they are discovered and reserved.

## Before making changes

- Create and download a fresh full Home Assistant backup.
- Keep the Home Assistant emergency backup key offline.
- Export or copy the current MG PBX project when one exists.
- Confirm you can open Proxmox at `https://192.168.4.121:8006`.
- Verify CARTER's Ethernet MAC in the eero app and reserve `192.168.4.121` for it.
- Record the exact CARTER and McKAY target disk serials.
- Do not rely only on disk names such as `sda` or `nvme0n1`.
- Keep all Windows and provider credentials out of the public repository.

## Part 0: Prepare the installation USB

Follow:

```text
docs\USB-SETUP-FROM-SCRATCH.md
```

The USB should contain:

- current Proxmox VE ISO;
- legitimate Windows 11 ISO;
- current VirtIO ISO;
- latest Home Assistant full backup `.tar`;
- repository or private deployment bundle;
- PBX export when available;
- private worksheet without unencrypted secrets.

Do not reinstall CARTER until the Home Assistant backup is confirmed on another device and on the USB.

## Part A: Prepare the repository and private configuration

1. Open the repository on the Windows preparation computer.
2. Choose **Code > Download ZIP**, or update the Git clone:

   ```powershell
   git pull
   ```

3. Copy:

   ```text
   config\site.example.conf
   ```

   to:

   ```text
   config\site.conf
   ```

4. Confirm these known values are present:

   ```text
   LAN_CIDR=192.168.4.0/22
   GATEWAY_IP=192.168.4.1
   DNS_IP=192.168.4.1
   ROUTER_RESERVATION_FIRST=192.168.4.2
   ROUTER_RESERVATION_LAST=192.168.6.222
   CARTER_HOST_IP=192.168.4.121
   PROXMOX_PREFIX=22
   ```

5. Leave McKAY, Home Assistant, and PBX addresses as `ENTER_HERE` until each address is verified.
6. Copy `config\private-info.example.ini` outside the public repository.
7. Fill private values only as each later step requires them.

## Part B: Install or rebuild CARTER Proxmox

1. Shut CARTER down cleanly.
2. Insert the prepared Atlantis USB.
3. Boot the USB in UEFI mode.
4. Select the Proxmox ISO in Ventoy.
5. Verify the internal target disk by model, capacity, and recorded serial.
6. Install Proxmox using:

   ```text
   Hostname: carter
   Address: 192.168.4.121/22
   Gateway: 192.168.4.1
   DNS: 192.168.4.1
   ```

7. Remove the USB when CARTER reboots.
8. Connect CARTER by Ethernet to the eero-side network.
9. Open:

   ```text
   https://192.168.4.121:8006
   ```

10. Sign in as `root`.
11. Update Proxmox before creating or restoring VMs.
12. Confirm at the CARTER console:

   ```bash
   ip -4 address show vmbr0
   ip route
   ```

The default route must point to `192.168.4.1`. Stop if CARTER receives a `192.168.12.x` address.

## Part C: Restore Home Assistant as VM 100

1. Create or import the Home Assistant OS VM as VM ID `100`.
2. Attach its network adapter to `vmbr0`.
3. Start VM `100`.
4. Open the Home Assistant welcome page using the address shown in the eero app.
5. Choose **Upload backup**.
6. Select the newest full backup from the USB or private bundle.
7. Enter the emergency backup key only when Home Assistant asks for it.
8. Restore the full backup.
9. Verify integrations, add-ons, dashboards, automations, cameras, and voice devices.
10. Do not assign `192.168.4.121` to Home Assistant. That address belongs to the Proxmox host.

## Part D: Discover and reserve the service addresses

Create four separate eero reservations:

1. CARTER Proxmox host
2. McKAY Proxmox host
3. Shared Home Assistant service address
4. Shared MG PBX service address

To inspect VMs on CARTER:

```bash
qm list
```

For guest-agent-aware VMs, try:

```bash
qm guest cmd 100 network-get-interfaces
qm guest cmd 110 network-get-interfaces
```

When Home Assistant does not report through the guest agent:

1. Open the eero app.
2. Open **Devices**.
3. Find the Home Assistant or newly connected wired device.
4. Compare its MAC with the VM network MAC shown in Proxmox.
5. Reserve the verified address.

Repeat for MG PBX. Then enter those verified values into `config\site.conf` and the private worksheet.

Every selected address must be:

- within `192.168.4.2` through `192.168.6.222`;
- unused by another device;
- different from `192.168.4.121`;
- different from every other reserved host or VM address.

## Part E: Create and install Windows 11 MG PBX as VM 110

The design uses VM ID `110`.

Recommended starting resources:

- 2 virtual CPU cores
- 4 GB RAM
- 64 GB or larger virtual disk
- UEFI firmware
- TPM 2.0
- VirtIO SCSI disk controller
- VirtIO network adapter

Installation order:

1. Attach the Windows 11 ISO and VirtIO ISO to VM `110`.
2. Start the VM and begin Windows installation.
3. When no disk appears, choose **Load driver** and load the VirtIO storage driver.
4. Complete Windows 11 installation.
5. Install VirtIO guest tools from the driver ISO.
6. Run Windows Update until no important updates remain.
7. Reserve the verified PBX VM address in eero.
8. Copy the repository or private bundle into the VM.
9. Open an elevated PowerShell window.
10. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Prepare-Windows-PBX.ps1 -PbxSource "PATH_TO_YOUR_PBX_EXPORT"
   ```

11. Verify one of these startup files exists in `C:\Atlantis\PBX`:

   - `start-pbx.ps1`
   - `start-pbx.cmd`
   - `start-pbx.bat`
   - `server.js`
   - `app.py`
   - `main.py`
   - `package.json` with a working `npm start` script

12. Restart Windows and confirm the PBX starts automatically.
13. Run:

   ```text
   C:\Atlantis\PBX-STATUS.cmd
   ```

## Part F: Build the private one-file completion bundle

After all four addresses are verified and reserved:

1. Open PowerShell in the repository folder.
2. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Private-Deployment.ps1
   ```

3. Accept the confirmed defaults when they still match:

   ```text
   LAN: 192.168.4.0/22
   Gateway: 192.168.4.1
   DNS: 192.168.4.1
   Reservation first: 192.168.4.2
   Reservation last: 192.168.6.222
   CARTER: 192.168.4.121
   ```

4. Enter the verified McKAY, Home Assistant, and PBX addresses.
5. Enter both target disk serials.
6. Select the ISOs, backup, and PBX folder when prompted. Blank entries may be supplied later.
7. Store the generated bundle on an encrypted USB drive or another private location.
8. Never upload the generated bundle to this public repository.

The builder rejects duplicate service addresses and addresses outside the safe eero range.

## Part G: Patch the CARTER laptop display

Do this only after Home Assistant and the PBX VM are stable.

1. Confirm `ATLANTIS_KIOSK_URL` in `config\site.conf` opens the desired dashboard.
2. Double-click:

   ```text
   RUN-CURRENT-CARTER-PATCH.cmd
   ```

3. Review the displayed CARTER address and dashboard URL.
4. Type `APPLY` when asked.
5. Enter the CARTER root password when SSH requests it.
6. Reboot CARTER from the Proxmox web interface.
7. The laptop screen should load the Atlantis information display.

### Maintenance access

Press:

```text
Ctrl + Alt + F2
```

to open a text console.

### Roll back the display patch

```bash
/opt/atlantis/bin/rollback-proxmox-kiosk.sh
reboot
```

The rollback restores the normal text-console boot target and leaves installed display packages in place.

## Part H: Prepare McKAY standby

1. Install Proxmox on McKAY using its own verified reservation.
2. Do not give McKAY the CARTER host address.
3. Keep standby Home Assistant and PBX VMs stopped during normal CARTER operation.
4. Copy recent backups to McKAY.
5. Document a controlled failover procedure.
6. Only during failover may the standby service VMs reuse the shared Home Assistant and PBX addresses.

## Final verification checklist

### CARTER

- Proxmox opens at `https://192.168.4.121:8006`.
- Default route points to `192.168.4.1`.
- VM `100` starts correctly.
- VM `110` starts correctly.
- Proxmox, Home Assistant, and PBX have different addresses.
- Laptop kiosk is installed only after both VMs are stable.

### Home Assistant

- Full backup restored successfully.
- Dashboard opens at the reserved HA address.
- Calendar and weather load.
- Automations do not run twice.
- Backup emergency key is stored offline.

### MG PBX

- Windows starts normally.
- VirtIO drivers are installed.
- PBX automatic-start task runs.
- Internal extensions can call each other.
- Inbound and outbound calling work.
- Only the active PBX registers with the provider.

### McKAY

- Host is reachable at its own reservation.
- Standby HA and PBX VMs remain stopped.
- Recent backups are available.
- A planned failover test is documented.

## Troubleshooting

### CARTER receives the wrong network

Run:

```bash
ip -4 address show vmbr0
ip route
```

CARTER must be on the eero-side `192.168.4.0/22` network. If it receives `192.168.12.x`, check the Ethernet path and confirm it connects to the eero LAN, not the upstream router LAN.

### Home Assistant and Proxmox seem to have the same address

They cannot share an address. `192.168.4.121` belongs to CARTER Proxmox. Use the eero device list and the VM MAC to discover the separate Home Assistant address.

### CARTER still shows the text prompt after the kiosk patch

```bash
systemctl status lightdm
systemctl get-default
cat /etc/lightdm/lightdm.conf.d/90-atlantis-kiosk.conf
```

The default target should be `graphical.target`.

### The kiosk says Home Assistant is initializing forever

- Confirm VM `100` is running.
- Confirm the exact dashboard URL from another computer.
- Confirm CARTER can reach the reserved Home Assistant IP.
- Correct `ATLANTIS_KIOSK_URL` in `/opt/atlantis/config/site.conf`.
- Restart LightDM:

  ```bash
  systemctl restart lightdm
  ```

### Windows PBX does not start automatically

```powershell
Get-ScheduledTask -TaskName 'MG PBX Automatic Startup'
Get-ScheduledTaskInfo -TaskName 'MG PBX Automatic Startup'
```

Then inspect:

```text
C:\Atlantis\Logs
C:\Atlantis\PBX
```

### A private value appears in Git

Do not push. Remove the value, rotate any exposed credential, verify `.gitignore`, and inspect the staged files before committing.
