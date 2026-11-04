#!/usr/bin/env bash
# Records real play sessions on the Deck (scripts/diagnostics/live_trace.gd).
# See docs/DEVELOPMENT.md, "Recording a play-session trace".
#   play-trace.sh on      start tracing from the next CRT XR launch
#   play-trace.sh off     stop tracing (the running session keeps tracing until it quits)
#   play-trace.sh status  flag state and recorded sessions
#   play-trace.sh pull    copy traces to build/play-traces/ and summarise them
#   play-trace.sh clear   delete the traces on the Deck
# Run from WSL with the Deck SSH master open (see scripts/deck-dev).
set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck -o UserKnownHostsFile=/tmp/deck-known_hosts"
DECK=deck@192.168.1.6
DATA='/home/deck/.local/share/godot/app_userdata/CRT XR'
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
remote() { ssh -S "$C" $O "$DECK" "$@"; }
case "${1:-status}" in
  on)
    remote "touch \"$DATA/frame-trace.on\" && echo 'Tracing on from the next CRT XR launch.'"
    ;;
  off)
    remote "rm -f \"$DATA/frame-trace.on\"; echo 'Tracing off from the next CRT XR launch.'; pgrep -x crt-xr-engine.x >/dev/null && echo 'CRT XR is running: this session keeps tracing until it quits.' || true"
    ;;
  status)
    remote "test -e \"$DATA/frame-trace.on\" && echo 'Tracing: on' || echo 'Tracing: off'; if ls \"$DATA/traces\"/*.jsonl >/dev/null 2>&1; then ls -la \"$DATA/traces\" | tail -n +4; else echo 'No traces recorded.'; fi"
    ;;
  pull)
    mkdir -p "$ROOT/build/play-traces"
    scp -o ControlPath="$C" $O "$DECK:$(printf '%q' "$DATA")/traces/*.jsonl" "$ROOT/build/play-traces/"
    python3 "$ROOT/scripts/deck-dev/analyze-play-trace.py" "$ROOT"/build/play-traces/*.jsonl
    ;;
  clear)
    remote "rm -rf \"$DATA/traces\"; echo 'Traces deleted.'"
    ;;
  *) echo "usage: $0 on|off|status|pull|clear"; exit 2;;
esac
