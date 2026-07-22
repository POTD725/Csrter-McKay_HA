#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/config/site.conf"
TEMPLATE="$REPO_ROOT/config/site.example.conf"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run this script as root on CARTER."
  exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Template not found: $TEMPLATE"
  echo "Run git pull in the repository and try again."
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  cp "$TEMPLATE" "$CONFIG"
  echo "Created $CONFIG from the current template."
else
  cp -a "$CONFIG" "$CONFIG.before-eero-$STAMP"
  echo "Backup created: $CONFIG.before-eero-$STAMP"
fi

set_value() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}=" "$CONFIG"; then
    sed -i -E "s|^${key}=.*$|${key}=${value}|" "$CONFIG"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$CONFIG"
  fi
}

get_value() {
  local key="$1"
  sed -n -E "s|^${key}=(.*)$|\1|p" "$CONFIG" | tail -n 1
}

clear_if_stale_or_conflicting() {
  local key="$1"
  local value
  value="$(get_value "$key")"
  if [[ "$value" == 192.168.12.* || "$value" == "192.168.4.121" ]]; then
    set_value "$key" "ENTER_HERE"
    echo "Cleared stale or conflicting $key=$value"
  fi
}

set_value LAN_CIDR "192.168.4.0/22"
set_value GATEWAY_IP "192.168.4.1"
set_value DNS_IP "192.168.4.1"
set_value ROUTER_RESERVATION_FIRST "192.168.4.2"
set_value ROUTER_RESERVATION_LAST "192.168.6.222"
set_value CARTER_HOSTNAME "carter"
set_value CARTER_HOST_IP "192.168.4.121"
set_value CARTER_HOST_IP_STATUS "DHCP_PENDING_EERO_RESERVATION"
set_value PROXMOX_PREFIX "22"

clear_if_stale_or_conflicting MCKAY_HOST_IP
clear_if_stale_or_conflicting HOME_ASSISTANT_IP
clear_if_stale_or_conflicting PBX_IP

kiosk_url="$(get_value ATLANTIS_KIOSK_URL)"
if [[ -z "$kiosk_url" || "$kiosk_url" == *192.168.12.* || "$kiosk_url" == *192.168.4.121* ]]; then
  set_value ATLANTIS_KIOSK_URL "http://ENTER_HOME_ASSISTANT_IP:8123/ENTER_DASHBOARD_PATH"
  echo "Reset ATLANTIS_KIOSK_URL until the Home Assistant VM address is verified."
fi

echo
echo "Updated local network configuration:"
grep -E '^(LAN_CIDR|GATEWAY_IP|DNS_IP|ROUTER_RESERVATION_FIRST|ROUTER_RESERVATION_LAST|CARTER_HOST_IP|CARTER_HOST_IP_STATUS|MCKAY_HOST_IP|HOME_ASSISTANT_IP|PBX_IP|PROXMOX_PREFIX|ATLANTIS_KIOSK_URL)=' "$CONFIG" || true

echo
echo "CARTER remains reachable at: https://192.168.4.121:8006"
echo "Reserve 192.168.4.121 in eero before treating it as permanent."
echo "Discover and reserve separate Home Assistant and PBX VM addresses before filling their fields."
