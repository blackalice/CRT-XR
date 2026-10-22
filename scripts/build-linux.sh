#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$root/build" "$root/dist"
touch "$root/build/.gdignore" "$root/dist/.gdignore"
cmake -S "$root/native" -B "$root/build/native" -DCMAKE_BUILD_TYPE=Release
cmake --build "$root/build/native" --parallel
ctest --test-dir "$root/build/native" --output-on-failure
mkdir -p "$root/dist/linux"
cp "$root/build/native/crt-xr-ipc-inventory" "$root/dist/linux/"
cp "$root/build/native/crt-xr-tracking-bridge" "$root/dist/linux/"
if [[ "${1:-}" == "--export" ]]; then
    godot="${GODOT_BIN:-godot}"
    "$godot" --headless --path "$root" --editor --import
    "$godot" --headless --path "$root" --export-release 'Linux x86_64' "$root/dist/linux/crt-xr.x86_64"
    mv "$root/dist/linux/crt-xr.x86_64" "$root/dist/linux/crt-xr-engine.x86_64"
    cp "$root/scripts/linux-runtime.sh" "$root/dist/linux/crt-xr.x86_64"
    chmod +x "$root/dist/linux/crt-xr.x86_64" "$root/dist/linux/crt-xr-engine.x86_64"
    cp "$root/scripts/launch-deck.sh" "$root/dist/linux/"
    if compgen -G "$root/cores/*_libretro.so" > /dev/null; then
        mkdir -p "$root/dist/linux/cores"
        cp "$root/cores/"*_libretro.so "$root/cores/"*LICENSE* "$root/dist/linux/cores/"
        cp "$root/LICENSE" "$root/LICENSING.md" "$root/THIRD_PARTY.md" "$root/extensions/bin/godot-cpp-LICENSE.md" "$root/dist/linux/"
    fi
fi
