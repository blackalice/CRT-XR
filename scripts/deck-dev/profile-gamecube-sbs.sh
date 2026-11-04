#!/usr/bin/env bash
# Full-SBS (two 1920x1080 eyes) GameCube profile with isolated saves, plus a
# 10 Hz sampler of GPU busy, GPU/CPU clocks and APU power. Never changes the
# active release. Arguments: release, play frames, game selection, room on/off.
set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck -o UserKnownHostsFile=/tmp/deck-known_hosts"
RELEASE=${1:?release required}
FRAMES=${2:-900}
SELECTION=${3:-all}
ROOM=${4:-on}
SNAP=${5:-0}
PRESS=${6:-}
DATA=${7:-}
SHADERS=${8:-}
ROUNDS=${9:-1}
[[ "$RELEASE" =~ ^[a-zA-Z0-9_.-]+$ && "$FRAMES" =~ ^[1-9][0-9]*$ && "$SNAP" =~ ^[0-9]+$ && "$PRESS" =~ ^[0-9a-z:,]*$ && "$DATA" =~ ^[a-z0-9-]*$ && "$SHADERS" =~ ^(|0|1|2|3|default)$ && "$ROUNDS" =~ ^[1-9]$ ]] || exit 2
case "$SELECTION" in all|timesplitters|fzero|mkdd|pair) ;; *) exit 2;; esac
case "$ROOM" in on|off) ;; *) exit 2;; esac
scp -o ControlPath=$C $O /mnt/d/git/XR-CRT/tests/gamecube_profile.gd deck@192.168.1.6:/tmp/
ssh -S "$C" $O deck@192.168.1.6 "RELEASE=$RELEASE FRAMES=$FRAMES SELECTION=$SELECTION ROOM=$ROOM SNAP=$SNAP PRESS=$PRESS DATA=$DATA SHADERS=$SHADERS ROUNDS=$ROUNDS bash -s" <<'REMOTE'
set -eu
if pgrep -x crt-xr-engine.x >/dev/null; then echo 'Exit CRT XR before profiling'; exit 1; fi
cd ~/Applications/CRT-XR/releases/"$RELEASE"
RUN=$(mktemp -d /tmp/crt-xr-gc-sbs-XXXXXX)
echo "Evidence: $RUN"
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 LD_PRELOAD=libstdc++.so.6
# DATA names a persistent isolated profile (never the real saves) so a later
# run can resume the automatic state left in a 3D scene.
if [ -n "$DATA" ]; then P=/home/deck/.cache/crt-xr-profile-data/$DATA; mkdir -p "$P"; else P=$RUN; fi
export XDG_DATA_HOME="$P/data" XDG_STATE_HOME="$P/state" CRT_XR_EXPERIMENTAL_GAMECUBE=1
export CRT_XR_FRAME_TRACE="$RUN/frames.jsonl" CRT_XR_PROFILE_ROOM="$ROOM" CRT_XR_GC_FULL_SBS=1
mkdir -p "$RUN/snaps"
export CRT_XR_PROFILE_SNAP="$SNAP" CRT_XR_PROFILE_SNAP_DIR="$RUN/snaps" CRT_XR_PROFILE_PRESS="$PRESS"
R=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube
case "$SELECTION" in
  all) export CRT_XR_GC_GAMES="$R/TimeSplitters - Future Perfect.iso;$R/F-Zero GX.iso;$R/Mario Kart - Double Dash!!.iso";;
  timesplitters) export CRT_XR_GC_GAMES="$R/TimeSplitters - Future Perfect.iso";;
  fzero) export CRT_XR_GC_GAMES="$R/F-Zero GX.iso";;
  pair) export CRT_XR_GC_GAMES="$R/TimeSplitters - Future Perfect.iso;$R/F-Zero GX.iso";;
  mkdd) export CRT_XR_GC_GAMES="$R/Mario Kart - Double Dash!!.iso";;
esac
export CRT_XR_GC_SHADERS="$SHADERS" CRT_XR_GC_ROUNDS="$ROUNDS" CRT_XR_PROFILE_FRAMES="$FRAMES"
GPU=$(ls -d /sys/class/drm/card[0-9]/device | head -1)
HW=$(ls -d $GPU/hwmon/hwmon* | head -1)
( while true; do
    printf '%s %s %s %s %s\n' "$(date +%s.%N)" "$(cat $GPU/gpu_busy_percent)" \
      "$(grep '\*' $GPU/pp_dpm_sclk | awk '{print $2}')" \
      "$(awk '{s+=$1} END {print int(s/NR/1000)}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq)" \
      "$(cat $HW/power1_average 2>/dev/null || cat $HW/power1_input 2>/dev/null || echo 0)"
    sleep 0.1
  done ) > "$RUN/sampler.txt" &
SAMPLER=$!
timeout 600 ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --display-driver x11 \
  --rendering-method gl_compatibility --resolution 1280x800 --windowed \
  --script /tmp/gamecube_profile.gd -- --sbs --simulate > "$RUN/profile.log" 2>&1 &
APP=$!
# Per-thread CPU every 5 s: shows whether one Dolphin thread is saturated.
( sleep 3; while kill -0 $APP 2>/dev/null; do
    PID=$(pgrep -x crt-xr-engine.x | head -1)
    [ -n "$PID" ] && { echo "@ $(date +%s.%N)"; top -H -b -n1 -d1 -p "$PID" | sed -n '8,20p'; }
    sleep 5
  done ) > "$RUN/threads.txt" 2>&1 &
THREADS=$!
wait $APP || true
kill $SAMPLER $THREADS 2>/dev/null || true
grep -E '^PASS|^FAIL|^PROFILE phase|^PROFILE_CARD' "$RUN/profile.log"
REMOTE
