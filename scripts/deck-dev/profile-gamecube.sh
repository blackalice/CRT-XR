#!/usr/bin/env bash
# Opt-in diagnostic PCK required: prepare a separate release containing the
# frame_profiled signal. Never replace the active release for a profiling run.
# Arguments: room on/off, tracking real/simulate, perf on/off, rounds, play frames,
# games all/timesplitters. JSONL is buffered until the test ends.
set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
ROOM=${1:-on}
TRACK=${2:-real}
SAMPLE=${3:-off}
case "$ROOM" in on|off) ;; *) exit 2;; esac
case "$TRACK" in real|simulate) ;; *) exit 2;; esac
case "$SAMPLE" in on|off) ;; *) exit 2;; esac
ROUNDS=${4:-4}
FRAMES=${5:-300}
SELECTION=${6:-all}
RELEASE=${CRT_XR_PROFILE_RELEASE:-gamecube-profile-20261103}
[[ "$RELEASE" =~ ^[a-zA-Z0-9_-]+$ ]] || exit 2
[[ "$ROUNDS" =~ ^[1-9][0-9]*$ && "$FRAMES" =~ ^[1-9][0-9]*$ ]] || exit 2
case "$SELECTION" in all|timesplitters) ;; *) exit 2;; esac
scp -o ControlPath=$C $O /mnt/d/git/XR-CRT/tests/gamecube_profile.gd deck@192.168.1.6:/tmp/
ssh -S "$C" $O deck@192.168.1.6 "ROOM=$ROOM TRACK=$TRACK SAMPLE=$SAMPLE ROUNDS=$ROUNDS FRAMES=$FRAMES SELECTION=$SELECTION RELEASE=$RELEASE bash -s" <<'REMOTE'
set -eu
if pgrep -x crt-xr-engine.x >/dev/null; then echo 'Exit CRT XR before profiling'; exit 1; fi
cd ~/Applications/CRT-XR/releases/"$RELEASE"
RUN=$(mktemp -d /tmp/crt-xr-gc-profile-XXXXXX)
echo "Evidence: $RUN"
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 LD_PRELOAD=libstdc++.so.6
export XDG_DATA_HOME="$RUN/data" XDG_STATE_HOME="$RUN/state" CRT_XR_EXPERIMENTAL_GAMECUBE=1
export CRT_XR_FRAME_TRACE="$RUN/frames.jsonl" CRT_XR_PROFILE_ROOM="$ROOM"
R=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube
export CRT_XR_GC_GAMES="$R/TimeSplitters - Future Perfect.iso;$R/Gotcha Force.rvz;$R/Mario Golf - Toadstool Tour.iso"
if [ "$SELECTION" = timesplitters ]; then export CRT_XR_GC_GAMES="$R/TimeSplitters - Future Perfect.iso"; fi
export CRT_XR_GC_ROUNDS="$ROUNDS" CRT_XR_PROFILE_FRAMES="$FRAMES"
EXTRA=()
if [ "$TRACK" = simulate ]; then EXTRA=(-- --simulate); fi
PREFIX=()
if [ "$SAMPLE" = on ]; then
  PREFIX=(perf record -o "$RUN/perf.data" --clockid CLOCK_REALTIME -e cpu-clock:u -F 99 --call-graph dwarf,4096 --)
fi
timeout 200 "${PREFIX[@]}" ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --display-driver x11 \
  --rendering-method gl_compatibility --resolution 1280x800 --windowed \
  --script /tmp/gamecube_profile.gd "${EXTRA[@]}" > "$RUN/profile.log" 2>&1
grep -E '^PASS|^FAIL|^PROFILE' "$RUN/profile.log"
REMOTE
