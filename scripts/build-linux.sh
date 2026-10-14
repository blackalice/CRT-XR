#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$root/build" "$root/dist"
touch "$root/build/.gdignore" "$root/dist/.gdignore"
cmake -S "$root/native" -B "$root/build/native" -DCMAKE_BUILD_TYPE=Release
cmake --build "$root/build/native" --parallel
ctest --test-dir "$root/build/native" --output-on-failure
mkdir -p "$root/dist/linux"
cp "$root/build/native/retrocrt-ipc-inventory" "$root/dist/linux/"
cp "$root/build/native/retrocrt-tracking-bridge" "$root/dist/linux/"
if [[ "${1:-}" == "--export" ]]; then
    godot="${GODOT_BIN:-godot}"
    "$godot" --headless --path "$root" --editor --import
    "$godot" --headless --path "$root" --export-release 'Linux x86_64' "$root/dist/linux/retrocrt.x86_64"
    cp "$root/scripts/launch-deck.sh" "$root/dist/linux/"
    if [[ -f "$root/cores/snes9x_libretro.so" ]]; then
        mkdir -p "$root/dist/linux/cores"
        cp "$root/cores/snes9x_libretro.so" "$root/cores/"*LICENSE* "$root/dist/linux/cores/"
        cp "$root/THIRD_PARTY.md" "$root/extensions/bin/godot-cpp-LICENSE.md" "$root/dist/linux/"
    fi
fi
