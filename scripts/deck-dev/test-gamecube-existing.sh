#!/usr/bin/env bash
set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
S=/mnt/d/git/XR-CRT
scp -o ControlPath=$C $O "$S/tests/gamecube_reload.gd" "$S/tests/gamecube_existing_resume.gd" deck@192.168.1.6:/tmp/
ssh -S "$C" $O deck@192.168.1.6 'bash -s' <<'REMOTE'
set -eu
if pgrep -x crt-xr-engine.x >/dev/null; then echo 'Exit CRT XR before testing'; exit 1; fi
cd ~/Applications/CRT-XR/releases/gamecube-corefix-20261103
RUN=$(mktemp -d /tmp/crt-xr-corefix-existing-XXXXXX)
echo "Evidence: $RUN"
export XDG_DATA_HOME="$RUN/data" XDG_STATE_HOME="$RUN/state" CRT_XR_EXPERIMENTAL_GAMECUBE=1 LD_PRELOAD=libstdc++.so.6
export CRT_XR_GAMECUBE_SAVE="$RUN/saves" CRT_XR_GC_FRAMES=0
R=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube
export CRT_XR_GAMECUBE_ROM="$R/TimeSplitters - Future Perfect.iso"
export CRT_XR_GC_GAMES="$CRT_XR_GAMECUBE_ROM;$R/Gotcha Force.rvz"
for mode in swap reopen; do
  CRT_XR_GC_MODE=$mode timeout 90 ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --headless \
    --script /tmp/gamecube_reload.gd > "$RUN/zero-then-boot-$mode.log" 2>&1
  grep -E '^PASS|^FAIL|RELOAD COMPLETE' "$RUN/zero-then-boot-$mode.log"
  if grep -q 'Suppressed popup: Warning - An error occurred' "$RUN/zero-then-boot-$mode.log"; then exit 1; fi
done
export CRT_XR_EXISTING_SAVE="$HOME/.local/share/godot/app_userdata/CRT XR/saves/gamecube/dolphin"
timeout 90 ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --headless \
  --script /tmp/gamecube_existing_resume.gd > "$RUN/existing-resume.log" 2>&1
grep -E '^PASS|^FAIL|^SKIP' "$RUN/existing-resume.log"
REMOTE
