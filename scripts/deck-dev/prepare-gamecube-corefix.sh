#!/usr/bin/env bash
# A new release directory only; never overwrite a running or hard-linked pack.
set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
S=/mnt/d/git/XR-CRT
D=/home/deck/Applications/CRT-XR/releases/gamecube-corefix-20261103
ssh -S "$C" $O deck@192.168.1.6 'bash -s' <<'REMOTE'
set -eu
base=/home/deck/Applications/CRT-XR/releases
target="$base/gamecube-corefix-20261103"
test ! -e "$target"
cp -al "$base/gamecube-restart-20261103" "$target"
cd "$target"
# Unlink these copies before replacing them: the old release stays intact.
rm crt-xr.pck crt_xr_libretro.linux.x86_64.so steam-session.py linux-session.py glasses-session.py cores/dolphin_libretro.so cores/dolphin-test-build.json
REMOTE
scp -o ControlPath=$C $O "$S/dist/pck-only/crt-xr.pck" "$S/extensions/bin/crt_xr_libretro.linux.x86_64.so" \
  "$S/scripts/steam-session.py" "$S/scripts/linux-session.py" "$S/scripts/glasses-session.py" "deck@192.168.1.6:$D/"
scp -o ControlPath=$C $O "$S/cores/dolphin_libretro.so" "$S/cores/dolphin-test-build.json" "deck@192.168.1.6:$D/cores/"
scp -o ControlPath=$C $O "$S/scripts/core-patches/dolphin-runtime.patch" "deck@192.168.1.6:$D/cores/sources/"
ARCHIVE=dolphin-b93001ed50c8b34e6ead4eed713c2005a80386e4.tar.gz
ssh -S "$C" $O deck@192.168.1.6 "test ! -f $D/cores/sources/$ARCHIVE || rm $D/cores/sources/$ARCHIVE"
scp -o ControlPath=$C $O "$S/cores/sources/$ARCHIVE" "deck@192.168.1.6:$D/cores/sources/"
scp -o ControlPath=$C $O "$S/tests/gamecube_reload.gd" "$S/tests/gamecube_switch.gd" "$S/tests/gamecube_state_stress.gd" "$S/tests/gamecube_boot.gd" deck@192.168.1.6:/tmp/
ssh -S "$C" $O deck@192.168.1.6 "cd $D && chmod +x steam-session.py linux-session.py glasses-session.py && python3 -m py_compile steam-session.py linux-session.py glasses-session.py && sha256sum cores/dolphin_libretro.so crt-xr.pck crt_xr_libretro.linux.x86_64.so"
