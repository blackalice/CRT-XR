C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
REL=${1:-gamecube-native-20261103}
scp -o ControlPath=$C $O /mnt/d/git/XR-CRT/tests/gamecube_switch.gd /mnt/d/git/XR-CRT/build/gdb-last-fault.py deck@192.168.1.6:/tmp/
ssh -S $C $O deck@192.168.1.6 "REL=$REL DIRECT=${DIRECT:-0} MIX=${MIX:-0} bash -s" <<'REMOTE'
R=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms/gamecube
export DISPLAY=:0
export XAUTHORITY=$(ls /run/user/1000/xauth_* 2>/dev/null | head -1)
rm -rf /tmp/xdg-gc-switch; mkdir -p /tmp/xdg-gc-switch
cd ~/Applications/CRT-XR/releases/$REL
export XDG_DATA_HOME=/tmp/xdg-gc-switch CRT_XR_EXPERIMENTAL_GAMECUBE=1 LD_PRELOAD=libstdc++.so.6
export CRT_XR_GC_GAMES="$R/Gotcha Force.rvz;$R/Mario Golf - Toadstool Tour.iso;$R/TimeSplitters - Future Perfect.iso;$R/Super Smash Brothers Melee.rvz"
if [ "$MIX" = 1 ]; then E=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms; export CRT_XR_GC_GAMES="$E/dreamcast/Tech Romancer (USA).chd;$R/Gotcha Force.rvz;$E/megacd/Sonic CD (USA).chd;$R/Mario Golf - Toadstool Tour.iso;$E/dreamcast/Tech Romancer (USA).chd"; fi
if [ "$MIX" = 2 ]; then E=/run/media/deck/b0a23cb2-34f3-436b-9674-6c94738bd5f1/Emulation/roms; export CRT_XR_GC_GAMES="$R/Mario Golf - Toadstool Tour.iso;$E/dreamcast/Tech Romancer (USA).chd;$E/nes/Mega Man 2 (1989-06)(Capcom)(US).nes;$R/Mario Golf - Toadstool Tour.iso;$R/Gotcha Force.rvz"; fi
export CRT_XR_NO_SELF_RESTART=1
export CRT_XR_GC_ROUNDS=${ROUNDS:-2} CRT_XR_GC_DIRECT=${DIRECT:-0}
timeout 420 ./crt-xr-engine.x86_64 --main-pack ./crt-xr.pck --rendering-method gl_compatibility --script /tmp/gamecube_switch.gd > /tmp/gc-switch.out 2>&1
echo "exit: $?"
grep -v -E "^\[Thread|^\[New Thread|DVDRead|^\[Libretro\]" /tmp/gc-switch.out | cut -c1-220 | tail -45
REMOTE
