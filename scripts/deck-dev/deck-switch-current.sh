set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
scp -o ControlPath=$C $O /mnt/d/git/XR-CRT/dist/deck-gamecube-20261103b/crt-xr.pck deck@192.168.1.6:/home/deck/Applications/CRT-XR/releases/$1/crt-xr.pck
ssh -S $C $O deck@192.168.1.6 "pgrep -a crt-xr-engine | cut -c1-60 || true; cd ~/Applications/CRT-XR && cmp releases/$1/crt-xr.pck releases/$1/crt-xr.pck && ln -sfn releases/$1 current.new && mv -T current.new current && readlink current; rm -rf /tmp/xdg-gc-switch /tmp/xdg-cc /tmp/gc-reload-saves /tmp/gamecube_*.gd /tmp/close_cost.gd /tmp/gdb-last-fault.py /tmp/gc-switch.out"
