#!/usr/bin/env bash
# Send a freshly exported pack to the Deck as a new release and make it current.
# Run in WSL after tools/connect-deck.ps1 has opened the SSH connection.
#   bash scripts/deck-dev/deck-send.sh <new-tag> [pack]   (pack: dist/ux-overhaul/crt-xr.pck)
# The new release starts as hard links of the current one (cores, engine, core-data),
# with its own copy of the pack and session scripts; the old release is kept.
set -eu
NEW=${1:?Pass a new release tag, e.g. ux-overhaul-20261115}
case "$NEW" in *[!a-zA-Z0-9_.-]*) echo 'Invalid release tag' >&2; exit 2;; esac
S=/mnt/d/git/XR-CRT
PACK=${2:-$S/dist/ux-overhaul/crt-xr.pck}
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck -o UserKnownHostsFile=$S/tools/deck-known_hosts"
H=deck@192.168.1.6
test -f "$PACK" || { echo "No pack at $PACK" >&2; exit 1; }
ssh -S $C $O $H "NEW=$NEW bash -s" <<'REMOTE'
set -eu
if pgrep -x crt-xr-engine.x >/dev/null || pgrep -f crt-xr-engine.x86_64 >/dev/null; then echo 'Exit CRT XR on the Deck first.' >&2; exit 1; fi
cd ~/Applications/CRT-XR/releases
BASE=$(basename "$(readlink -f ~/Applications/CRT-XR/current)")
test "$BASE" != "$NEW" || { echo "$NEW is already current" >&2; exit 1; }
rm -rf "$NEW"; cp -al "$BASE" "$NEW"
# Hard links share bytes with the old release: remove before writing new files.
rm -f "$NEW/crt-xr.pck" "$NEW/steam-session.py" "$NEW/linux-session.py" "$NEW/glasses-session.py"
echo "prepared $NEW from $BASE"
REMOTE
scp -o ControlPath=$C $O "$PACK" $S/scripts/steam-session.py $S/scripts/linux-session.py $S/scripts/glasses-session.py "$H:/home/deck/Applications/CRT-XR/releases/$NEW/"
ssh -S $C $O $H "NEW=$NEW bash -s" <<'REMOTE'
set -eu
cd ~/Applications/CRT-XR/releases/$NEW
sed -i 's/\r$//' steam-session.py linux-session.py glasses-session.py
chmod +x steam-session.py linux-session.py glasses-session.py
python3 -m py_compile steam-session.py linux-session.py glasses-session.py
cd ~/Applications/CRT-XR
ln -sfn "releases/$NEW" current.new && mv -Tf current.new current
echo "current -> $(readlink current)"
REMOTE
echo 'Done. Launch CRT XR from Steam on the Deck.'
