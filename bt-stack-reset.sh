#!/bin/bash
# Reset the Bluetooth stack and verify the AirPods audio paths actually work.
# Recovers a wedged eSCO/SCO path (mic captures silence, "Failure in Bluetooth
# audio transport" in the wireplumber journal) without a reboot.
#
# Usage: bt-stack-reset.sh [quick|full|replug]   (default: quick)
#
# After it finishes, self-verify or run your own test:
#   wpctl status          # AirPods sink, AAC active
#   timeout 5 parecord ... # probe, see README

set -u

MAC=AA:68:25:03:19:D8
BLUEZ_CARD=bluez_card.AA_68_25_03_19_D8
MODE=${1:-quick}

log() { echo "[bt-reset] $*"; }

require_root() {
	if [[ $EUID -ne 0 ]]; then
		exec sudo "$0" "$@"
	fi
}

connected() {
	bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Connected: yes'
}

aac_ok() {
	pactl list cards 2>/dev/null | awk '/bluez_card/{f=1} f&&/Active Profile/{print}' | grep -q 'a2dp-sink'
}

reconnect() {
	log "reconnecting AirPods"
	bluetoothctl disconnect "$MAC" >/dev/null 2>&1
	sleep 2
	bluetoothctl connect "$MAC" >/dev/null 2>&1
	sleep 6
}

case $MODE in
quick)
	log "quick reset: restart bluetooth.service, reconnect"
	bluetoothctl disconnect "$MAC" >/dev/null 2>&1
	require_root systemctl restart bluetooth
	sleep 3
	reconnect
	;;
full)
	log "full reset: controller power cycle + stack restart"
	require_root bash -c '
		bluetoothctl disconnect '"$MAC"' >/dev/null 2>&1
		btmgmt power off
		sleep 1
		btmgmt power on
		sleep 2
		systemctl restart bluetooth
	'
	sleep 3
	reconnect
	;;
replug)
	log "replug reset: reload btusb kernel module (worst case before re-pairing)"
	require_root bash -c '
		bluetoothctl disconnect '"$MAC"' >/dev/null 2>&1
		systemctl stop bluetooth
		modprobe -r btusb btintel btbcm btbcm btmtk 2>/dev/null
		sleep 2
		modprobe btusb
		sleep 2
		systemctl start bluetooth
	'
	sleep 4
	reconnect
	;;
*)
	echo "usage: $0 [quick|full|replug]" >&2
	exit 2
	;;
esac

# Bring the card back to the high-quality profile and re-check.
sleep 2
if connected; then
	if ! aac_ok; then
		pactl set-card-profile "$BLUEZ_CARD" a2dp-sink 2>/dev/null ||
			pactl set-card-profile "bluez_card.${MAC//:/_}" a2dp-sink 2>/dev/null
	fi
fi

if aac_ok; then
	log "OK: card profile is a2dp-sink (AAC path live)"
	exit 0
elif connected; then
	log "WARN: AirPods connected but A2DP not active — try: $0 full"
	exit 1
else
	log "FAIL: AirPods did not reconnect — try: $0 full (then replug, then re-pair)"
	exit 1
fi
