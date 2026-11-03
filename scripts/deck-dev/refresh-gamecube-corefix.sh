#!/usr/bin/env bash
set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
S=/mnt/d/git/XR-CRT
D=/home/deck/Applications/CRT-XR/releases/gamecube-corefix-20261103
ssh -S "$C" $O deck@192.168.1.6 "cd $D && if pgrep -x crt-xr-engine.x >/dev/null; then exit 1; fi; rm crt-xr.pck crt_xr_libretro.linux.x86_64.so cores/dolphin_libretro.so cores/dolphin-test-build.json cores/sources/dolphin-runtime.patch cores/sources/dolphin-b93001ed50c8b34e6ead4eed713c2005a80386e4.tar.gz"
scp -o ControlPath=$C $O "$S/extensions/bin/crt_xr_libretro.linux.x86_64.so" "$S/dist/pck-only/crt-xr.pck" "deck@192.168.1.6:$D/"
scp -o ControlPath=$C $O "$S/cores/dolphin_libretro.so" "$S/cores/dolphin-test-build.json" "deck@192.168.1.6:$D/cores/"
scp -o ControlPath=$C $O "$S/scripts/core-patches/dolphin-runtime.patch" "$S/cores/sources/dolphin-b93001ed50c8b34e6ead4eed713c2005a80386e4.tar.gz" "deck@192.168.1.6:$D/cores/sources/"
scp -o ControlPath=$C $O "$S/tests/gamecube_reload.gd" "$S/tests/gamecube_switch.gd" "$S/tests/gamecube_state_stress.gd" deck@192.168.1.6:/tmp/
