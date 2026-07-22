#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run this script as root on the Proxmox host."
  exit 1
fi

LAST_FILE=/var/backups/atlantis-kiosk/LAST_PATCH
if [[ ! -f "$LAST_FILE" ]]; then
  echo "No Atlantis kiosk backup marker was found."
  exit 1
fi

STAMP="$(cat "$LAST_FILE")"
BACKUP_DIR="/var/backups/atlantis-kiosk/$STAMP"

systemctl disable --now lightdm 2>/dev/null || true
systemctl set-default multi-user.target
rm -f /etc/lightdm/lightdm.conf.d/90-atlantis-kiosk.conf
rm -f /usr/local/bin/atlantis-kiosk

if [[ -d "$BACKUP_DIR/lightdm" ]]; then
  rm -rf /etc/lightdm
  cp -a "$BACKUP_DIR/lightdm" /etc/lightdm
fi

systemctl daemon-reload

echo "The laptop display has been returned to the normal text console target."
echo "The display packages were left installed so rollback does not remove shared dependencies."
echo "Reboot when convenient: reboot"
