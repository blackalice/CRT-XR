#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-all}"
jobs="${BUILD_JOBS:-6}"
test "$(git -C "$root/tools/godot-cpp" rev-parse HEAD)" = e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77
test "$(git -C "$root/tools/snes9x" rev-parse HEAD)" = 1bcc369e89f08243e0a462882fb1f3e42e51de3a
mkdir -p "$root/extensions/bin" "$root/cores" "$root/build"
touch "$root/cores/.gdignore" "$root/build/.gdignore"
for platform in linux windows; do
    if [[ "$target" != all && "$target" != "$platform" ]]; then continue; fi
    options=()
    if [[ "$platform" == windows ]]; then options+=("-DCMAKE_TOOLCHAIN_FILE=$root/native/emulation/mingw.cmake"); fi
    cmake -S "$root/native/emulation" -B "$root/build/emulation-$platform" -DCMAKE_BUILD_TYPE=Release "${options[@]}"
    cmake --build "$root/build/emulation-$platform" --parallel "$jobs"
    # Separate object directories avoid mixing Windows and Linux core objects.
    source="$root/build/snes9x-$platform"
    mkdir -p "$source"
    if [[ ! -f "$source/libretro/Makefile" ]]; then
        git -C "$root/tools/snes9x" archive HEAD | tar -x -C "$source"
    fi
    if [[ "$platform" == linux ]]; then
        make --silent -C "$source/libretro" -j"$jobs" platform=unix LTO= CXX='g++ -std=c++17'
        core="$source/libretro/snes9x_libretro.so"
    else
        make --silent -C "$source/libretro" -j"$jobs" platform=win CC=x86_64-w64-mingw32-gcc-posix CXX='x86_64-w64-mingw32-g++-posix -std=c++17' LTO= LDFLAGS='-static -static-libgcc -static-libstdc++'
        core="$source/libretro/snes9x_libretro.dll"
    fi
    # The test build only seeds cores/; build-release-cores.py owns the recorded release binaries.
    if [[ ! -f "$root/cores/$(basename "$core")" ]]; then cp "$core" "$root/cores/"; fi
    python3 "$root/tests/make_probe_rom.py" "$root/build/crt-xr-probe.sfc"
    if [[ "$platform" == linux ]]; then
        "$root/build/emulation-linux/crt-xr-host-test" "$root/build/emulation-linux/libcrt_xr_mock_core.so" "$core" "$root/build/crt-xr-probe.sfc" "$root/build" "$root/build/emulation-linux/libcrt_xr_mock_fullpath_core.so"
    fi
done
cp "$root/tools/snes9x/LICENSE" "$root/cores/Snes9x-LICENSE.txt"
cp "$root/tools/snes9x/filter/snes_ntsc-license.txt" "$root/cores/snes_ntsc-LICENSE.txt"
cp "$root/tools/snes9x/jma/license.txt" "$root/cores/JMA-LICENSE.txt"
cp "$root/tools/snes9x/filter/xbrz-license.txt" "$root/cores/xbrz-LICENSE.txt"
cp "$root/tools/godot-cpp/LICENSE.md" "$root/extensions/bin/godot-cpp-LICENSE.md"
python3 - "$root" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
notice = (root / "tools/snes9x/libretro/libretro.h").read_text().split("*/", 1)[0] + "*/\n"
(root / "cores/libretro-header-LICENSE.txt").write_text(notice)
PY
