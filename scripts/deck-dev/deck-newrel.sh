set -eu
C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
BASE=$1; NEW=$2
S=/mnt/d/git/XR-CRT
ssh -S $C $O deck@192.168.1.6 "cd ~/Applications/CRT-XR/releases && rm -rf $NEW && cp -al $BASE $NEW && cd $NEW && rm -f crt-xr.pck steam-session.py linux-session.py glasses-session.py && echo prepared; pgrep -a crt-xr-engine | cut -c1-90 || echo 'no app running'"
D=deck@192.168.1.6:/home/deck/Applications/CRT-XR/releases/$NEW
scp -o ControlPath=$C $O $S/dist/pck-only/crt-xr.pck $S/scripts/steam-session.py $S/scripts/linux-session.py $S/scripts/glasses-session.py $D/
ssh -S $C $O deck@192.168.1.6 "cd ~/Applications/CRT-XR/releases/$NEW && chmod +x steam-session.py linux-session.py glasses-session.py 2>/dev/null; sed -i 's/\r\$//' steam-session.py linux-session.py glasses-session.py; python3 -m py_compile steam-session.py linux-session.py glasses-session.py && echo wrappers-ok; ls -la crt-xr.pck | cut -c1-60"
