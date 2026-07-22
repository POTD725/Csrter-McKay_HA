# CARTER / McKAY Installation Walkthrough

This guide covers two paths:

1. **Patch the current CARTER laptop** so its built-in screen displays the Atlantis information dashboard instead of the text prompt.
2. **Build the private completion bundle** containing your Windows 11 ISO, VirtIO drivers, Home Assistant backup, PBX export, configuration, scripts, and checksums.

The public repository contains no passwords, encryption keys, product keys, backups, or licensed ISO files.

## Before making changes

- Confirm CARTER Home Assistant and the PBX VM are backed up.
- Confirm you can sign into the Proxmox web interface from another computer.
- Record the exact current IP addresses for CARTER, McKAY, Home Assistant, and the PBX.
- Open the router or eero reservation page and record the permitted reservation range.
- Record each target disk serial. Do not rely only on names such as `sda` or `nvme0n1`.
- Keep the Home Assistant emergency backup key offline.
- Keep all Windows and provider credentials out of the public repository.

## Part A: Download and prepare the repository

1. Open the repository on GitHub.
2. Choose **Code > Download ZIP**, or clone it with Git.
3. Extract it to a private working folder on Windows.
4. Copy:

   ```text
   config\site.example.conf
   ```

   to:

   ```text
   config\site.conf
   ```

5. Open `config\site.conf` in Notepad and replace every `ENTER_HERE` value.
6. Copy `config\private-info.example.ini` to a private location outside the repository.
7. Fill private values only as each later step requires them.

## Part B: Patch the current CARTER laptop display

This patch installs a very small graphical environment directly on the Proxmox host. It does not edit VM 100 or VM 110.

1. Make sure SSH is enabled on CARTER and that you know the Proxmox root password.
2. Confirm `ATLANTIS_KIOSK_URL` in `config\site.conf` opens the desired Home Assistant dashboard.
3. Double-click:

   ```text
   RUN-CURRENT-CARTER-PATCH.cmd
   ```

4. Review the displayed CARTER address and dashboard URL.
5. Type `APPLY` when asked.
6. Enter the CARTER root password when SSH requests it.
7. When the script finishes, reboot CARTER from the Proxmox web interface.
8. The laptop screen should load the Atlantis information display.

### Maintenance access

Press:

```text
Ctrl + Alt + F2
```

to open a text console.

### Roll back the display patch

From the CARTER console or an SSH session, run:

```bash
/opt/atlantis/bin/rollback-proxmox-kiosk.sh
reboot
```

The rollback restores the normal text-console boot target. It leaves the installed display packages in place to avoid removing anything another package may use.

## Part C: Build the private one-file completion bundle

1. Gather these items on the Windows preparation computer:
   - legitimate Windows 11 Pro or Enterprise ISO;
   - current VirtIO driver ISO;
   - newest full Home Assistant backup `.tar` file;
   - Home Assistant emergency backup key;
   - current MG PBX project or export folder;
   - CARTER and McKAY target disk serials;
   - router reservation range and selected addresses.
2. Open PowerShell in the repository folder.
3. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Private-Deployment.ps1
   ```

4. Enter the requested network and disk information.
5. Select each ISO, backup, and PBX folder when prompted. Blank entries may be supplied later.
6. The builder creates:
   - a private staging folder;
   - populated `site.conf` and McKAY disk override;
   - a private fill-in worksheet;
   - scripts and documentation;
   - SHA-256 checksums;
   - one encrypted-header `.7z` bundle when 7-Zip is available.
7. Store the resulting bundle on an encrypted USB drive or another private location.
8. Never upload the generated bundle to this public repository.

## Part D: Create and install the Windows 11 PBX VM

The existing design uses VM ID `110` for Windows 11 MG PBX.

Recommended starting resources:

- 2 virtual CPU cores
- 4 GB RAM
- 64 GB or larger virtual disk
- UEFI firmware
- TPM 2.0
- VirtIO SCSI disk controller
- VirtIO network adapter

Installation order:

1. Attach the Windows 11 ISO and VirtIO ISO to VM 110.
2. Start the VM and begin Windows installation.
3. When no disk appears, choose **Load driver** and load the VirtIO storage driver.
4. Complete Windows 11 installation.
5. Install the VirtIO guest tools from the driver ISO.
6. Run Windows Update until no important updates remain.
7. Copy the repository or the private bundle into the VM.
8. Open an elevated PowerShell window.
9. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Prepare-Windows-PBX.ps1 -PbxSource "PATH_TO_YOUR_PBX_EXPORT"
   ```

10. The script installs or updates the required application set, enables local maintenance access, creates the PBX folders, and registers the automatic-start task.
11. Verify that one of these startup files exists in `C:\Atlantis\PBX`:
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

    to inspect startup, SSH, and listening ports.

## Part E: Restore Home Assistant

1. Start VM 100 on CARTER.
2. Open the Home Assistant welcome page.
3. Choose **Upload backup**.
4. Select the full backup from the private bundle.
5. Enter the emergency backup key only when Home Assistant asks for it.
6. Restore the full backup.
7. Verify integrations, add-ons, dashboards, automations, cameras, and voice devices.
8. Confirm the Atlantis dashboard URL in `site.conf` is correct.
9. Restart the CARTER kiosk after the dashboard works.

## Part F: Network reservations

Create four router reservations:

1. CARTER Proxmox host
2. McKAY Proxmox host
3. Shared Home Assistant service address
4. Shared MG PBX service address

McKAY standby VMs must remain stopped during normal CARTER operation. They reuse the shared VM addresses only during failover.

Never choose an address merely because it looks convenient. It must fall inside the router's permitted reservation block and must not already be assigned.

## Part G: Final verification checklist

### CARTER

- Proxmox web interface opens.
- VM 100 starts automatically.
- VM 110 starts automatically.
- Laptop screen opens the Atlantis dashboard.
- `Ctrl + Alt + F2` opens maintenance console.

### Home Assistant

- Dashboard opens at the configured URL.
- Calendar and weather load.
- Automations do not run twice.
- Backup encryption key is stored offline.

### MG PBX

- Windows starts normally.
- VirtIO drivers are installed.
- PBX automatic-start task runs.
- Internal extensions can call each other.
- Inbound and outbound calling work.
- Only the active PBX registers with the provider.

### McKAY

- Host is reachable.
- Standby HA and PBX VMs remain stopped.
- Recent backups are available.
- A planned failover test has been documented.

## Troubleshooting

### CARTER still shows the text prompt

Run on CARTER:

```bash
systemctl status lightdm
systemctl get-default
cat /etc/lightdm/lightdm.conf.d/90-atlantis-kiosk.conf
```

The default target should be `graphical.target`.

### The kiosk says Home Assistant is initializing forever

- Confirm VM 100 is running.
- Confirm the exact dashboard URL from another computer.
- Confirm CARTER can reach the Home Assistant IP.
- Correct `ATLANTIS_KIOSK_URL` in `/opt/atlantis/config/site.conf`.
- Restart LightDM:

```bash
systemctl restart lightdm
```

### Windows PBX does not start automatically

Open an elevated PowerShell window and run:

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
