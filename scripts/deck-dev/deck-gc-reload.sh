C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
REL=gamecube-native-20261103
scp -o ControlPath=$C $O /mnt/d/git/XR-CRT/tests/gamecube_reload.gd deck@192.168.1.6:/tmp/
for MODE in reopen; do for FR in 0 1 5 30; do
echo "######## $MODE frames=$FR"
ssh -S $C $O deck@192.168.1.6 "MODE=$MODE FR=$FR REL=$REL bash -s" <<'REMOTE'
R=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube
export DISPLAY=:0 XAUTHORITY=$(ls /run/user/1000/xauth_* 2>/dev/null | head -1)
rm -rf /tmp/gc-reload-saves /tmp/xdg-gc-switch; mkdir -p /tmp/gc-reload-saves /tmp/xdg-gc-switch
cd ~/Applications/CRT-XR/releases/$REL
export XDG_DATA_HOME=/tmp/xdg-gc-switch CRT_XR_EXPERIMENTAL_GAMECUBE=1 LD_PRELOAD=libstdc++.so.6 CRT_XR_GAMECUBE_SAVE=/tmp/gc-reload-saves CRT_XR_GC_MODE=$MODE CRT_XR_GC_FRAMES=$FR
export CRT_XR_GC_GAMES="$R/Gotcha Force.rvz;$R/Mario Golf - Toadstool Tour.iso;$R/TimeSplitters - Future Perfect.iso"
timeout 200 ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --rendering-method gl_compatibility --script /tmp/gamecube_reload.gd 2>&1 | grep -E "^(PASS|FAIL|RELOAD)" | cut -c1-120; echo "exit ${PIPESTATUS[0]}"
REMOTE
done; done
