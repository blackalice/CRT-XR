set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
TAG=$1; SRC=$2
D=/home/deck/Applications/CRT-XR/releases/$TAG
ssh -S $C $O deck@192.168.1.6 "pgrep -a crt-xr-engine | cut -c1-80 || echo 'app not running'; rm -rf $D; mkdir -p $D"
tar -cf - -C $SRC . | ssh -S $C $O deck@192.168.1.6 "tar -xf - -C $D"
ssh -S $C $O deck@192.168.1.6 "cd $D && chmod +x crt-xr.x86_64 crt-xr-engine.x86_64 crt-xr-tracking-bridge crt-xr-ipc-inventory launch-*.sh *.py Install-CRT-XR*.sh 2>/dev/null; echo \"files: \$(find . -type f | wc -l)\"; head -4 crt-xr.x86_64 | tail -1"
