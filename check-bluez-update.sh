#!/bin/bash
# Notify when Arch has a bluez update that is being skipped by IgnorePkg,
# so the local patched build never silently goes stale (security risk).
# Runs as a systemd user timer (bluez-update-check.timer).

set -u

REPO=$(pacman -Si bluez 2>/dev/null | awk '/^Version/ {print $3; exit}')
INST=$(pacman -Qi bluez 2>/dev/null | awk '/^Version/ {print $3; exit}')

if [[ -z $REPO || -z $INST ]]; then
	exit 0
fi

if [[ $REPO != "$INST" ]]; then
	MSG="bluez update available: repo $REPO, installed $INST (patched, IgnorePkg). Review https://github.com/bluez/bluez/releases and rebuild airpods-bluez-fix when both fixes are included."
	if omarchy-cmd-present omarchy-notification-send >/dev/null 2>&1; then
		omarchy-notification-send "$MSG"
	elif command -v notify-send >/dev/null 2>&1; then
		notify-send "bluez" "$MSG"
	else
		logger -t bluez-update-check "$MSG"
	fi
fi
