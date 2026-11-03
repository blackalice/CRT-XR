#!/usr/bin/env bash
# Run one game under gdb without opening the player's settings or saves.
set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
S=/mnt/d/git/XR-CRT
MODE=${1:-switch}
case "$MODE" in switch|boot|state_stress|runtime|reload) ;; *) exit 2;; esac
REL=${3:-gamecube-restart-20261103}
case "$REL" in ''|*[!a-zA-Z0-9_-]*) exit 2;; esac
FIX=${2:-original}
case "$FIX" in original) ;; fixed)
  scp -o ControlPath=$C $O "$S/build/dolphin-linux/dolphin_libretro.so" deck@192.168.1.6:/tmp/crt-xr-dolphin-state-lock.so
  ;; *) exit 2;; esac
scp -o ControlPath=$C $O "$S/tests/gamecube_runtime.gd" "$S/tests/gamecube_boot.gd" "$S/tests/gamecube_switch.gd" "$S/tests/gamecube_state_stress.gd" "$S/tests/gamecube_reload.gd" deck@192.168.1.6:/tmp/
ssh -S "$C" $O deck@192.168.1.6 "MODE=$MODE FIX=$FIX REL=$REL bash -s" <<'REMOTE'
set -eu
if pgrep -x crt-xr-engine.x >/dev/null; then echo 'Exit the running app before testing'; exit 1; fi
RUN=$(mktemp -d /tmp/crt-xr-gc-fault-XXXXXX)
cd "$HOME/Applications/CRT-XR/releases/$REL"
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000
export XDG_DATA_HOME="$RUN/data" XDG_STATE_HOME="$RUN/state"
export CRT_XR_EXPERIMENTAL_GAMECUBE=1 LD_PRELOAD=libstdc++.so.6
if [ "$FIX" = fixed ]; then export CRT_XR_CORE=/tmp/crt-xr-dolphin-state-lock.so; fi
export CRT_XR_GAMECUBE_ROM='/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube/TimeSplitters - Future Perfect.iso'
export CRT_XR_GAMECUBE_SAVE="$RUN/saves"
export CRT_XR_GC_GAMES="${CRT_XR_GAMECUBE_ROM};/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube/Gotcha Force.rvz;/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube/Mario Golf - Toadstool Tour.iso"
# Against historical packs this bypasses their process-restart workaround.
export CRT_XR_NO_SELF_RESTART=1 CRT_XR_GC_DIRECT=menu CRT_XR_GC_ROUNDS=3
export CRT_XR_GC_CONTINUE=1
export CRT_XR_GC_MODE=swap CRT_XR_GC_FRAMES=0
mkdir -p "$CRT_XR_GAMECUBE_SAVE"
# Reproduce existing shader/cache state, but write only to the isolated copy.
cp -a "$HOME/.local/share/godot/app_userdata/CRT XR/saves/gamecube/dolphin/User" "$CRT_XR_GAMECUBE_SAVE/User"
mkdir -p "$XDG_DATA_HOME/godot/app_userdata/CRT XR/saves/gamecube/dolphin"
cp -a "$CRT_XR_GAMECUBE_SAVE/User" "$XDG_DATA_HOME/godot/app_userdata/CRT XR/saves/gamecube/dolphin/User"
echo "Evidence: $RUN"
timeout 180 gdb -q -batch \
  -ex 'set pagination off' -ex 'set print thread-events off' \
  -ex 'handle SIGSEGV nostop noprint pass' \
  -ex 'run' -ex 'bt 30' -ex 'x/12i $pc-12' -ex 'info proc mappings' \
  -ex 'thread apply all bt 6' \
  --args ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --display-driver x11 \
  --rendering-method gl_compatibility --resolution 1280x800 --windowed \
  --script "/tmp/gamecube_${MODE}.gd" > "$RUN/gdb.log" 2>&1 || true
grep -E '^PASS|^FAIL|DOLPHIN_RESULT|received signal|^#|^=>|^Thread ' "$RUN/gdb.log" | head -110
REMOTE
