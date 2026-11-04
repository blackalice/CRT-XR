C=/tmp/retrocrt-deck-01a139ee.sock
O="-o BatchMode=yes -o HostKeyAlias=steamdeck"
ssh -S $C $O deck@192.168.1.6 'bash -s' <<'REMOTE'
date
coredumpctl list --no-pager 2>/dev/null | grep -E "TIME|crt-xr" | tail -5
pgrep -a crt-xr-engine | cut -c1-100
echo "=== godot-steam.log tail"; tail -40 ~/.local/state/crt_xr/godot-steam.log | cut -c1-220
echo "=== journal"
journalctl --since "-45min" --no-pager 2>/dev/null | grep -E "traps:|segfault|terminated abnormally|signal [0-9]|Out of memory|oom|amdgpu.*(timeout|fault|reset|ring)|GPU|hang" | grep -v "Removed old" | cut -c1-230 | tail -20
REMOTE
