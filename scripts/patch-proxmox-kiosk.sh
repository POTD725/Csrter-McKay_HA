#!/usr/bin/env bash
set -Eeuo pipefail

# CARTER / McKAY Proxmox laptop display patch
# Installs a lightweight local kiosk without changing VM definitions.

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run this script as root on the Proxmox host."
  exit 1
fi

CONFIG_FILE="${1:-/opt/atlantis/config/site.conf}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Configuration not found: $CONFIG_FILE"
  echo "Copy config/site.example.conf to $CONFIG_FILE and fill in ATLANTIS_KIOSK_URL first."
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"
KIOSK_USER="${KIOSK_USER:-atlantis-display}"
KIOSK_URL="${ATLANTIS_KIOSK_URL:-}"

if [[ -z "$KIOSK_URL" || "$KIOSK_URL" == *ENTER_* ]]; then
  echo "ATLANTIS_KIOSK_URL is not complete in $CONFIG_FILE"
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/var/backups/atlantis-kiosk/$STAMP"
mkdir -p "$BACKUP_DIR"

backup_if_exists() {
  local item="$1"
  if [[ -e "$item" ]]; then
    cp -a "$item" "$BACKUP_DIR/"
  fi
}

backup_if_exists /etc/lightdm
backup_if_exists /etc/systemd/system/default.target
backup_if_exists /usr/local/bin/atlantis-kiosk

echo "$STAMP" > /var/backups/atlantis-kiosk/LAST_PATCH

echo "Installing the lightweight display stack..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  xserver-xorg \
  xinit \
  openbox \
  lightdm \
  chromium \
  unclutter \
  x11-xserver-utils \
  curl \
  ca-certificates

if ! id "$KIOSK_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$KIOSK_USER"
fi

install -d -m 0755 /opt/atlantis/config
install -d -m 0755 /var/lib/atlantis-kiosk
install -d -m 0755 /etc/lightdm/lightdm.conf.d
install -d -o "$KIOSK_USER" -g "$KIOSK_USER" -m 0755 "/home/$KIOSK_USER/.config/openbox"

cat > /usr/local/bin/atlantis-kiosk <<'KIOSK'
#!/usr/bin/env bash
set -u

CONFIG_FILE="/opt/atlantis/config/site.conf"
# shellcheck disable=SC1090
source "$CONFIG_FILE"
URL="${ATLANTIS_KIOSK_URL}"

xset s off || true
xset -dpms || true
xset s noblank || true
unclutter --idle 2 --root &

PROFILE="$HOME/.config/chromium-atlantis"
mkdir -p "$PROFILE"

while true; do
  if curl --silent --show-error --fail --max-time 5 "$URL" >/dev/null 2>&1; then
    chromium \
      --user-data-dir="$PROFILE" \
      --kiosk \
      --noerrdialogs \
      --disable-infobars \
      --disable-session-crashed-bubble \
      --autoplay-policy=no-user-gesture-required \
      --check-for-update-interval=31536000 \
      "$URL" || true
  else
    chromium \
      --user-data-dir="$PROFILE" \
      --kiosk \
      --noerrdialogs \
      --disable-infobars \
      "data:text/html,<html><body style='margin:0;background:%2303181d;color:%238ff7f0;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh'><div style='text-align:center'><h1>ATLANTIS SYSTEMS INITIALIZING</h1><p>Waiting for Home Assistant...</p></div></body></html>" || true
  fi
  sleep 5
done
KIOSK
chmod 0755 /usr/local/bin/atlantis-kiosk

cat > "/home/$KIOSK_USER/.config/openbox/autostart" <<'AUTOSTART'
/usr/local/bin/atlantis-kiosk &
AUTOSTART
chown -R "$KIOSK_USER:$KIOSK_USER" "/home/$KIOSK_USER/.config"

cat > /etc/lightdm/lightdm.conf.d/90-atlantis-kiosk.conf <<EOF
[Seat:*]
autologin-user=$KIOSK_USER
autologin-user-timeout=0
user-session=openbox
xserver-command=X -s 0 -dpms
EOF

systemctl enable lightdm
systemctl set-default graphical.target

echo
printf '%s\n' "Patch installed successfully." \
  "Reboot when convenient: reboot" \
  "Maintenance console: Ctrl+Alt+F2" \
  "Rollback script: scripts/rollback-proxmox-kiosk.sh" \
  "Backup: $BACKUP_DIR"
