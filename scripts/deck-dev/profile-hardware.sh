#!/usr/bin/env bash
# Profile hardware cores with isolated saves. Does not change the active release.
set -eu
RELEASE=${1:?isolated release required}
FRAMES=${2:-900}
# Optional: games relative to the SD card's Emulation/roms, separated by ";".
GAMES=${3:-}
[[ "$RELEASE" =~ ^[a-zA-Z0-9_.-]+$ && "$FRAMES" =~ ^[1-9][0-9]*$ && "$GAMES" != *"'"* ]] || exit 2
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
scp -o ControlPath="$C" $O /mnt/d/git/XR-CRT/tests/gamecube_profile.gd deck@192.168.1.6:/tmp/
ssh -S "$C" $O deck@192.168.1.6 "RELEASE=$RELEASE FRAMES=$FRAMES GAMES='$GAMES' bash -s" <<'REMOTE'
set -eu
if pgrep -x crt-xr-engine.x >/dev/null; then echo 'Exit CRT XR before profiling'; exit 1; fi
cd ~/Applications/CRT-XR/releases/"$RELEASE"
RUN=$(mktemp -d /tmp/crt-xr-hardware-profile-XXXXXX)
echo "Evidence: $RUN"
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 LD_PRELOAD=libstdc++.so.6
export XDG_DATA_HOME="$RUN/data" XDG_STATE_HOME="$RUN/state" CRT_XR_EXPERIMENTAL_GAMECUBE=1
export CRT_XR_FRAME_TRACE="$RUN/frames.jsonl" CRT_XR_PROFILE_ROOM=on
R=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms
export CRT_XR_GC_GAMES="$R/dreamcast/Tech Romancer (USA).chd;$R/n64/GoldenEye 007 (USA).z64;$R/n64/F-Zero X (USA).z64"
if [ -n "$GAMES" ]; then
  LIST=""; IFS=";"; for g in $GAMES; do LIST="$LIST${LIST:+;}$R/$g"; done; unset IFS
  export CRT_XR_GC_GAMES="$LIST"
fi
export CRT_XR_GC_ROUNDS=2 CRT_XR_PROFILE_FRAMES="$FRAMES"
timeout 240 ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --display-driver x11 \
  --rendering-method gl_compatibility --resolution 1280x800 --windowed \
  --script /tmp/gamecube_profile.gd > "$RUN/profile.log" 2>&1
grep -E '^PASS|^FAIL|^PROFILE' "$RUN/profile.log"
REMOTE
