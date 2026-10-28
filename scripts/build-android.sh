#!/usr/bin/env bash
# Android arm64 build steps, run inside the crt-xr-android image (Dockerfile.android):
#   extension  the GDExtension and its native tests, for arm64-v8a
#   export     a debug APK of the project (needs the extension)
#   all        both
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-all}"
jobs="${BUILD_JOBS:-6}"
# Godot 4.5.1's template defaults to API 24; CRT XR starts at Android 10.
api=29
: "${ANDROID_NDK_ROOT:?Run inside the crt-xr-android image}"

build_extension() {
    test "$(git -C "$root/tools/godot-cpp" rev-parse HEAD)" = e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77
    test "$(git -C "$root/tools/snes9x" rev-parse HEAD)" = 1bcc369e89f08243e0a462882fb1f3e42e51de3a
    mkdir -p "$root/extensions/bin" "$root/build"
    touch "$root/build/.gdignore"
    # Each core links its own C++ runtime statically; only the C libretro ABI
    # crosses library boundaries, so one shared runtime is not needed.
    cmake -S "$root/native/emulation" -B "$root/build/emulation-android" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$api" -DANDROID_STL=c++_static
    cmake --build "$root/build/emulation-android" --parallel "$jobs"
    "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf" -h "$root/extensions/bin/libcrt_xr_libretro.android.arm64.so" | grep -q AArch64
    echo "Android extension: extensions/bin/libcrt_xr_libretro.android.arm64.so"
}

# The preset's version/name is config/version in the digits-and-periods form
# Godot's Android export requires (0.1.0-beta.14.1 becomes 0.1.0.14.1), and
# version/code must follow it so every APK installs over the previous one: ((major*100+minor)*100+patch)*1000 + beta*10 + hotfix, with
# beta 99 for a final release. 0.1.0-beta.14.1 is 100141.
check_version_code() {
    python3 - "$root" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
version = re.search(r'^config/version="([^"]+)"', (root / "project.godot").read_text(), re.M).group(1)
match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)(?:-beta\.(\d+)(?:\.(\d+))?)?", version)
if not match: sys.exit(f"Cannot derive an Android version code from {version}")
major, minor, patch, beta, hotfix = (int(x) if x else None for x in match.groups())
code = ((major * 100 + minor) * 100 + patch) * 1000 + (99 if beta is None else beta) * 10 + (hotfix or 0)
preset = (root / "export_presets.cfg").read_text().split('name="Android"', 1)[1]
found = int(re.search(r"^version/code=(\d+)", preset, re.M).group(1))
if found != code: sys.exit(f"Android version/code is {found}; {version} needs {code} in export_presets.cfg")
numeric = version.replace("-beta.", ".")
name = re.search(r'^version/name="([^"]*)"', preset, re.M).group(1)
if name != numeric: sys.exit(f'Android version/name is "{name}"; set it to "{numeric}" in export_presets.cfg')
PY
}

# Prepared models and bakes, as the desktop exports copy them to assets/. Android
# reads them from res://android_assets (scripts/platform/platform.gd). The room
# bake's PNG is read as a raw image, so it is exported as is, not imported.
stage_assets() {
    local out="$root/android_assets"
    rm -rf "$out"
    mkdir -p "$out"
    copy() { if [[ -f "$root/build/$1" ]]; then mkdir -p "$out/$(dirname "$2")"; cp "$root/build/$1" "$out/$2"; else echo "Not staged (missing): build/$1"; fi; }
    copy crt-model/optimised/cabinet.scn optimised/cabinet.scn
    copy crt-model/ao/tvfront_ao.res ao/tvfront_ao.res
    copy crt-model/ao/tvback_ao.res ao/tvback_ao.res
    copy console/console.scn console/console.scn
    copy wood-table/table.scn wood-table/table.scn
    copy room-bake/bake.json room-bake/bake.json
    copy room-bake/table_contact_albedo.res room-bake/table_contact_albedo.res
    copy room-bake/floor_ao.png room-bake/floor_ao.png
    if [[ -f "$out/room-bake/floor_ao.png" ]]; then
        printf '[remap]\n\nimporter="keep"\n' > "$out/room-bake/floor_ao.png.import"
    fi
}

export_apk() {
    check_version_code
    test -f "$root/extensions/bin/libcrt_xr_libretro.android.arm64.so" || { echo "Build the extension first: $0 extension" >&2; exit 1; }
    local dir="$root/tools/godot-linux"
    local godot="$dir/Godot_v4.5.1-stable_linux.x86_64"
    if [[ ! -x "$godot" ]]; then
        mkdir -p "$dir"
        curl -sSfL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip
        echo "5bccbed65a94b82c7c319fdb15719ee8113a6e503976cc54e16f1c61fe95f3d74e5e40b8449b5bb89ff7f424574c20af01a4f5ef08b389e4dc338b245185b0b9  /tmp/godot.zip" | sha512sum -c -
        unzip -q -o /tmp/godot.zip -d "$dir"
        rm /tmp/godot.zip
    fi
    # Self-contained: settings, templates and keystores stay in tools/godot-linux.
    touch "$dir/_sc_"
    local data="$dir/editor_data"
    local templates="$data/export_templates/4.5.1.stable"
    mkdir -p "$templates" "$data/keystores"
    for name in android_debug.apk android_release.apk android_source.zip version.txt; do
        if [[ ! -f "$templates/$name" ]]; then
            unzip -q -o -j "$root/tools/export_templates.zip" "templates/$name" -d "$templates"
        fi
    done
    # Development signing only. Release signing uses a separately kept keystore.
    local keystore="$data/keystores/debug.keystore"
    if [[ ! -f "$keystore" ]]; then
        keytool -genkeypair -keystore "$keystore" -storepass android -keypass android -alias androiddebugkey \
            -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 10000 > /dev/null
    fi
    cat > "$data/editor_settings-4.5.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
export/android/debug_keystore = "$keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
    stage_assets
    trap 'rm -rf "$root/android_assets"' EXIT
    mkdir -p "$root/dist/android"
    local apk="$root/dist/android/CRT-XR-debug.apk"
    rm -f "$apk"
    "$godot" --headless --path "$root" --import > "$root/build/android-import.log" 2>&1 || true
    "$godot" --headless --path "$root" --export-debug Android "$apk" 2>&1 | tee "$root/build/android-export.log" | grep -E "ERROR|error|savepack" || true
    test -f "$apk" || { echo "Export failed; see build/android-export.log" >&2; exit 1; }
    local listing
    listing="$(unzip -l "$apk")"
    grep -q "lib/arm64-v8a/libcrt_xr_libretro.android.arm64.so" <<<"$listing" || { echo "APK lacks the extension" >&2; exit 1; }
    echo "Android debug APK: dist/android/CRT-XR-debug.apk ($(du -h "$apk" | cut -f1))"
}

case "$target" in
    extension) build_extension ;;
    export) export_apk ;;
    all) build_extension; export_apk ;;
    *) echo "Unknown target: $target" >&2; exit 2 ;;
esac
