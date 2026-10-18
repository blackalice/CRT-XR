$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'build/windows-tracking'
New-Item -ItemType Directory -Force $out | Out-Null
# Uses the MinGW POSIX cross compiler installed in WSL Ubuntu; no vendor headers needed.
$linuxRoot = (& wsl -d Ubuntu -- wslpath -a ($root.Replace('\','/'))).Trim()
& wsl -d Ubuntu -- x86_64-w64-mingw32-g++-posix -std=c++17 -O2 -static -municode "$linuxRoot/native/windows_tracking/bridge.cpp" -o "$linuxRoot/build/windows-tracking/crt-xr-windows-tracking.exe" -lws2_32 -lsetupapi -lhid
if ($LASTEXITCODE -ne 0) { throw 'Windows tracking bridge build failed.' }
