C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
scp -o ControlPath=$C $O /mnt/d/git/XR-CRT/tests/gamecube_restart.gd deck@192.168.1.6:/tmp/
ssh -S $C $O deck@192.168.1.6 'bash -s' <<'REMOTE'
R=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube
export DISPLAY=:0 XAUTHORITY=$(ls /run/user/1000/xauth_* 2>/dev/null | head -1)
cd ~/Applications/CRT-XR/releases/gamecube-restart-20261103
export XDG_DATA_HOME=/tmp/xdg-restart CRT_XR_EXPERIMENTAL_GAMECUBE=1 LD_PRELOAD=libstdc++.so.6
export CRT_XR_GC_A="$R/Gotcha Force.rvz" CRT_XR_GC_B="$R/Mario Golf - Toadstool Tour.iso"
rm -rf /tmp/xdg-restart; mkdir -p /tmp/xdg-restart
ENG="./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --rendering-method gl_compatibility --script /tmp/gamecube_restart.gd"
echo "######## supervised (exit code + file)"
rm -f /tmp/restart-args.txt
CRT_XR_RESTART_FILE=/tmp/restart-args.txt timeout 200 $ENG -- --test-restart 2>&1 | grep -E "^(PASS|FAIL|FIRST)"
echo "exit code: ${PIPESTATUS[0]}"; echo "file:"; cat /tmp/restart-args.txt
echo "######## relaunch with those arguments"
mapfile -t EXTRA < /tmp/restart-args.txt
timeout 200 $ENG -- --test-restart "${EXTRA[@]}" 2>&1 | grep -E "^(PASS|FAIL)"
echo "######## self-relaunch (no supervisor)"
unset CRT_XR_RESTART_FILE
rm -rf /tmp/xdg-restart; mkdir -p /tmp/xdg-restart
timeout 200 $ENG -- --test-restart 2>&1 | grep -E "^(PASS|FAIL|FIRST)"
echo "first process exit: ${PIPESTATUS[0]}"
sleep 25
echo "--- after self-relaunch, processes:"; pgrep -a crt-xr-engine | cut -c1-110 || echo none
REMOTE
