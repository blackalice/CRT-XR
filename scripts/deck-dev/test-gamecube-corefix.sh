#!/usr/bin/env bash
# Run all core-fix regressions against the prepared release, with isolated saves.
set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
ssh -S "$C" $O deck@192.168.1.6 'bash -s' <<'REMOTE'
set -eu
if pgrep -x crt-xr-engine.x >/dev/null; then echo 'Exit CRT XR before testing'; exit 1; fi
cd ~/Applications/CRT-XR/releases/gamecube-corefix-20261103
RUN=$(mktemp -d /tmp/crt-xr-corefix-tests-XXXXXX)
echo "Evidence: $RUN"
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 LD_PRELOAD=libstdc++.so.6
export XDG_DATA_HOME="$RUN/data" XDG_STATE_HOME="$RUN/state" CRT_XR_EXPERIMENTAL_GAMECUBE=1
export CRT_XR_GAMECUBE_SAVE="$RUN/saves"
R=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube
export CRT_XR_GAMECUBE_ROM="$R/TimeSplitters - Future Perfect.iso"
export CRT_XR_GC_GAMES="$R/TimeSplitters - Future Perfect.iso;$R/Gotcha Force.rvz;$R/Mario Golf - Toadstool Tour.iso"
mkdir -p "$CRT_XR_GAMECUBE_SAVE"
for mode in swap reopen; do
  for frames in 0 1 30; do
    echo "Reload: mode=$mode frames=$frames"
    CRT_XR_GC_MODE=$mode CRT_XR_GC_FRAMES=$frames timeout 90 ./crt-xr-engine.x86_64 \
      --main-pack ./crt-xr.pck --headless --script /tmp/gamecube_reload.gd > "$RUN/reload-$mode-$frames.log" 2>&1
    grep -E '^PASS|^FAIL|RELOAD COMPLETE' "$RUN/reload-$mode-$frames.log"
    if grep -q 'Suppressed popup: Warning - An error occurred' "$RUN/reload-$mode-$frames.log"; then exit 1; fi
  done
done
timeout 90 ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --headless \
  --script /tmp/gamecube_state_stress.gd > "$RUN/state.log" 2>&1
grep -E '^PASS|^FAIL' "$RUN/state.log"
# Fresh boots, then Continue the saves created by the earlier switches, all in
# one process and with the full CRT room. A process restart would fail this test.
export CRT_XR_GC_DIRECT=menu CRT_XR_GC_ROUNDS=3 CRT_XR_GC_CONTINUE=1
timeout 180 ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --display-driver x11 \
  --rendering-method gl_compatibility --resolution 1280x800 --windowed \
  --script /tmp/gamecube_switch.gd > "$RUN/switch.log" 2>&1
grep -E '^PASS|^FAIL|SWITCH COMPLETE' "$RUN/switch.log"
REMOTE
