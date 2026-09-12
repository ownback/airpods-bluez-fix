#!/bin/bash
# Abort pacman transactions that would replace the locally patched bluez
# packages (AirPods Pro 3 crash fixes). The [Trigger] section of
# /etc/pacman.d/hooks/bluez-guard.hook makes pacman run this script whenever
# a transaction installs or upgrades any bluez* package, so this script does
# not need to inspect the target list.
#
# To deliberately allow a bluez upgrade once:
#   sudo touch /run/bluez-upgrade-allowed

if [[ -e /run/bluez-upgrade-allowed ]]; then
	exit 0
fi

echo "bluez-guard: transaction touches bluez (locally patched for AirPods) - aborting." >&2
echo "bluez-guard: if you intend this (e.g. installing your own build from airpods-bluez-fix):" >&2
echo "bluez-guard:   sudo touch /run/bluez-upgrade-allowed && retry the pacman command" >&2
echo "bluez-guard: if upstream bluez now contains both fixes, remove the guard hook instead." >&2
exit 1
