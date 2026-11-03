#!/usr/bin/env bash
set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
SHADERS=${1:-0}
case "$SHADERS" in 0|2) ;; *) exit 2;; esac
MIX=${2:-0}
case "$MIX" in 0|1) ;; *) exit 2;; esac
FULL=${3:-0}
case "$FULL" in 0|1) ;; *) exit 2;; esac
scp -o ControlPath=$C $O /mnt/d/git/XR-CRT/tests/gamecube_switch.gd deck@192.168.1.6:/tmp/
ssh -S "$C" $O deck@192.168.1.6 "SHADERS=$SHADERS MIX=$MIX FULL=$FULL bash -s" <<'REMOTE'
set -eu
if pgrep -x crt-xr-engine.x >/dev/null; then echo 'Exit CRT XR before testing'; exit 1; fi
cd ~/Applications/CRT-XR/releases/gamecube-corefix-20261103
RUN=$(mktemp -d /tmp/crt-xr-corefix-sbs-XXXXXX)
echo "Evidence: $RUN"
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 LD_PRELOAD=libstdc++.so.6
export XDG_DATA_HOME="$RUN/data" XDG_STATE_HOME="$RUN/state" CRT_XR_EXPERIMENTAL_GAMECUBE=1
R=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube
export CRT_XR_GC_GAMES="$R/TimeSplitters - Future Perfect.iso;$R/Gotcha Force.rvz;$R/Mario Golf - Toadstool Tour.iso;$R/Mario Party 4.iso;$R/"'WarioWare, Inc. - Mega Party Game$!.iso'
export CRT_XR_GC_DIRECT=menu CRT_XR_GC_ROUNDS=2 CRT_XR_GC_CONTINUE=1
export CRT_XR_GC_SHADERS=$SHADERS
export CRT_XR_GC_FULL_SBS=$FULL
if [ "$FULL" = 1 ]; then
  export CRT_XR_GC_GAMES="$R/TimeSplitters - Future Perfect.iso;$R/Gotcha Force.rvz;$R/Mario Golf - Toadstool Tour.iso"
fi
if [ "$MIX" = 1 ]; then
  E=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms
  export CRT_XR_GC_GAMES="$R/TimeSplitters - Future Perfect.iso;$E/dreamcast/Tech Romancer (USA).chd;$E/nes/Mega Man 2 (1989-06)(Capcom)(US).nes;$R/TimeSplitters - Future Perfect.iso"
  export CRT_XR_GC_ROUNDS=1
fi
timeout 240 ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --display-driver x11 \
  --rendering-method gl_compatibility --resolution 1280x800 --windowed \
  --script /tmp/gamecube_switch.gd -- --sbs --simulate > "$RUN/switch-sbs.log" 2>&1
grep -E '^PASS|^FAIL|SWITCH START|SWITCH COMPLETE' "$RUN/switch-sbs.log"
REMOTE
