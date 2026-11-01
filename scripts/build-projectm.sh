#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
platform="${1:-linux}"
[[ "$platform" == linux || "$platform" == windows ]]
mkdir -p "$root/tools" "$root/build" "$root/extensions/bin"
source="$root/tools/projectm"
if [[ ! -d "$source/.git" ]]; then
 git clone --depth 1 --branch v4.1.8 --recurse-submodules --shallow-submodules https://github.com/projectM-visualizer/projectm.git "$source"
fi
test "$(git -C "$source" rev-parse HEAD)" = 4967dc003e5206d7df3ff447287f7609c47d2343
if git -C "$source" apply --check "$root/third_party/projectm/offscreen.patch" 2>/dev/null; then
 git -C "$source" apply "$root/third_party/projectm/offscreen.patch"
else
 git -C "$source" apply --reverse --check "$root/third_party/projectm/offscreen.patch"
fi
options=()
if [[ "$platform" == windows ]]; then
 glew="$root/tools/glew-2.2.0"
 if [[ ! -f "$glew/src/glew.c" ]]; then
  curl -fL https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz -o "$root/build/glew.tgz"
  tar -xf "$root/build/glew.tgz" -C "$root/tools"
 fi
 x86_64-w64-mingw32-gcc-posix -O2 -DGLEW_STATIC -I"$glew/include" -c "$glew/src/glew.c" -o "$root/build/glew.o"
 x86_64-w64-mingw32-ar rcs "$root/build/libglew32.a" "$root/build/glew.o"
 options+=("-DCMAKE_TOOLCHAIN_FILE=$root/native/emulation/mingw.cmake" "-DGLEW_INCLUDE_DIR=$glew/include" "-DGLEW_STATIC_LIBRARY_RELEASE=$root/build/libglew32.a" -DGLEW_USE_STATIC_LIBS=ON -DCMAKE_CXX_FLAGS=-DGLEW_STATIC -DCMAKE_CXX_STANDARD_LIBRARIES=-lopengl32 "-DCMAKE_SHARED_LINKER_FLAGS=-static-libgcc -static-libstdc++ -static")
fi
cmake -S "$source" -B "$root/build/projectm-$platform" -DCMAKE_BUILD_TYPE=Release -DENABLE_SYSTEM_PROJECTM_EVAL=OFF -DENABLE_PLAYLIST=OFF "${options[@]}"
cmake --build "$root/build/projectm-$platform" -j"${BUILD_JOBS:-8}"
if [[ "$platform" == windows ]]; then
 find "$root/build/projectm-$platform" -name 'libprojectM-4.dll' -exec cp {} "$root/extensions/bin/projectM-4.dll" ";"
else
 find "$root/build/projectm-$platform" -name 'libprojectM-4.so.*' -type f -exec cp {} "$root/extensions/bin/libprojectM-4.so" ";"
fi
# Corresponding source, including modified files, all vendored sources and build instructions.
mkdir -p "$root/build/projectm-sources"
tar --exclude=.git -czf "$root/build/projectm-sources/projectm-4.1.8-patched.tar.gz" -C "$root/tools" projectm
if [[ "$platform" == windows ]]; then tar --exclude=.git -czf "$root/build/projectm-sources/glew-2.2.0.tar.gz" -C "$root/tools" glew-2.2.0; fi
cp "$root/scripts/build-projectm.sh" "$root/third_party/projectm/offscreen.patch" "$root/build/projectm-sources/"
