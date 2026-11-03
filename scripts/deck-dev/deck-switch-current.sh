#!/usr/bin/env bash
# Activate an already prepared release. Never copy a pack or erase test evidence.
set -eu
TAG=${1:?Pass an existing release tag}
case "$TAG" in ''|*[!a-zA-Z0-9_-]*) echo 'Invalid release tag' >&2; exit 2;; esac
C=/tmp/retrocrt-deck-01a139ee.sock
ssh -S "$C" -o BatchMode=yes -o HostKeyAlias=steamdeck deck@192.168.1.6 "TAG=$TAG bash -s" <<'REMOTE'
set -eu
if pgrep -x crt-xr-engine.x >/dev/null; then
  echo 'Exit CRT XR before switching releases.' >&2
  exit 1
fi
cd ~/Applications/CRT-XR
test -f "releases/$TAG/crt-xr.pck"
test -x "releases/$TAG/crt-xr-engine.x86_64"
ln -sfn "releases/$TAG" current.new
mv -Tf current.new current
readlink current
REMOTE
