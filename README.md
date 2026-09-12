# Patched BlueZ for AirPods Pro 3 on Arch/Omarchy

A rebuild of the Arch Linux `bluez` package with two crash fixes applied, so
AirPods Pro 3 actually appear as an A2DP audio device instead of crashing
`bluetoothd`. Built from the official Arch PKGBUILD.

## The two bugs

### Bug 1 — A2DP cache-loading regression (fixed upstream, not yet in a release)

BlueZ commit `912f5efb0dd9` ("a2dp: Fix handling of codec capability storage",
in 5.87) added a broken loop bound (`i >= 2` with `i` starting at 0) in
`load_remote_sep()` in `profiles/audio/a2dp.c`. The loop body never runs, so
every cached remote SEP is discarded, `bluetoothd` logs

```
Unable to load LastUsed: rseid N not found
```

and then segfaults. With no SEPs loaded, no A2DP endpoint is ever exposed and
the AirPods never appear as a sink/source.

Fixed upstream in `3f0cffa8df578a9ec2a133f896113c8a02eef250` ("a2dp: Fix
loading of remote SEP from cache", merged 2026-07-10). Our
`0001-a2dp-Fix-loading-of-remote-SEP-from-cache.patch` is exactly that commit,
cherry-picked on top of the 5.87 tag. Drop this patch as soon as Arch ships a
bluez release containing it.

### Bug 2 — GATT service discovery NULL / use-after-free (local fix)

`bluetoothd` also segfaults in `src/shared/gatt-client.c`,
`discovery_op_complete()`:

```c
if ((!success && err == 0) && gatt_db_service_get_active(attr))
```

`attr` (from `svc->data` in the pending-services queue) can be NULL when a
GATT service-discovery operation is aborted mid-flight (e.g. by a
disconnect), and in the worst case it is non-NULL but already freed (a
genuine use-after-free in the discovery-cancellation path). This fires when
the AirPods' LE connection is opened/closed repeatedly — exactly what the
Omarchy `soup.airpods` bar widget does when it opens its Apple AAP (L2CAP
PSM 0x1001) channel.

Two patches fix this:

- `0002-gatt-client-null-guard-discovery-op.patch` — defensive NULL-guard
  in `discovery_op_complete()` for the NULL-`attr` case.
- `0003-gatt-db-notify-removal-of-inactive-services.patch` — the real fix
  for the use-after-free. `gatt_db_service_destroy()` only fired the
  service-removed notification for services that had been set active, so
  any discovery op holding a *non-active* service in its `pending_svcs`
  list was left with a dangling pointer whenever the database was cleared
  under it (`gatt_db_clear_range()` from `service_changed_failure()`,
  disconnect cleanup, etc.). The next `discovery_op_complete()` then called
  `gatt_db_service_get_active()` on freed memory. The patch makes the
  destroy path always notify, keeping every observer's pending list in
  sync. This should be submitted upstream to bluez.

Reference for the same bug class fixed before:
https://patchwork.kernel.org/project/bluetooth/patch/20201105224923.377-1-sonnysasaka@chromium.org/

## Status (2026-09-12)

- Works with bluez 5.87 + all three patches: AirPods Pro 3 connect, A2DP
  sink/source appear, audio plays, mic works via HFP profile switching.
- `soup.airpods` plugin currently DISABLED; the GATT UAF fix (0003) needs
  live validation with the plugin re-enabled before it can be trusted.
  Soak-test plan: enable plugin, connect/disconnect repeatedly with music
  playing, watch `journalctl -u bluetooth` for segfaults.

## Build and install

```bash
git clone https://github.com/<USER>/airpods-bluez-fix.git
cd airpods-bluez-fix
makepkg -si
sudo systemctl restart bluetooth
```

`makepkg -si` builds all eight split packages (`bluez`, `bluez-libs`,
`bluez-utils`, `bluez-cups`, `bluez-deprecated-tools`, `bluez-hid2hci`,
`bluez-mesh`, `bluez-obex`) and installs them. No `--noextract`,
`--skipchecksums` or manual source edits needed — the patches are proper
files in the `source=()` array, so clean rebuilds always work.

## Never regress: keeping pacman from overwriting the patches

The packages are held with `IgnorePkg` in `/etc/pacman.conf`:

```
IgnorePkg = bluez bluez-libs bluez-utils bluez-cups bluez-deprecated-tools bluez-hid2hci bluez-mesh bluez-obex
```

`pacman -Syu` will then print `warning: bluez: ignoring package upgrade`
instead of silently replacing the patched binaries.

On top of that, two safety nets are installed:

1. `check-bluez-update.sh` + a systemd user timer (`bluez-update-check`),
   which compares the repo version with the installed one once a day and
   sends a desktop notification when Arch has a new bluez that you are
   deliberately skipping (so security fixes never get missed).
2. A pacman `PreTransaction` hook (`bluez-guard.hook` ->
   `/etc/pacman.d/hooks/bluez-guard.hook`, script in
   `/usr/local/bin/bluez-guard`) which **aborts** any transaction that
   installs/upgrades any bluez* package unless you explicitly allow it:

   ```bash
   sudo touch /run/bluez-upgrade-allowed   # allow once (self-expiring, tmpfs)
   ```

   Note: this also blocks reinstalling your OWN build, so after a
   rebuild do:

   ```bash
   sudo touch /run/bluez-upgrade-allowed && makepkg -si && sudo rm /run/bluez-upgrade-allowed
   ```

## When Arch ships a new bluez

1. Check whether the release already contains both fixes
   (`3f0cffa8df578a9ec2a133f896113c8a02eef250` and a fix for the
   gatt-client.c discovery abort UAF). If yes: remove the `IgnorePkg` line
   from `/etc/pacman.conf`, delete the guard hook, upgrade, and retire this
   repo.
2. If not: bump `pkgver`/`pkgrel` in the PKGBUILD if the patch context
   changed, rebuild (`makepkg -si`), reinstall.

## WirePlumber configuration shipped here

- `51-bluez-safe-codecs.conf` — system-level codec restriction
  (currently SBC only; relax to `[ sbc aac ]` once stable, the AirPods
  support AAC).
- `bluetooth-a2dp-autoconnect.conf` — user-level auto-connect of A2DP
  profiles (goes to `~/.config/wireplumber/wireplumber.conf.d/`).

Note: `/etc/wireplumber/...` is overridden per-user by
`~/.config/wireplumber/...` for the same setting keys; keep that in mind
when changing either file.

## Why not upstream?

- Bug 1 is already fixed upstream; only packaging lags.
- Bug 2's UAF is not yet fixed upstream. The NULL-guard patch is a local
  stopgap; the real fix (cancel in-flight GATT discovery ops on cleanup)
  should be developed and submitted to https://github.com/bluez/bluez
