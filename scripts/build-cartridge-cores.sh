#!/usr/bin/env bash
# Run in the existing Dockerfile.emulation compiler environment.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-all}"
jobs="${BUILD_JOBS:-6}"
mkdir -p "$root/cores/sources" "$root/build"
for spec in nestopia:06a8949e0b3cf60e3a38a374b1426bf40fccb9a0 genesis-plus-gx:393f70cd64c7334564c19a424c383f53986c13f4; do
    name="${spec%%:*}"; revision="${spec#*:}"
    test "$(git -C "$root/tools/$name" rev-parse HEAD)" = "$revision"
    # Include complete source snapshots alongside the core licence notices.
    git -C "$root/tools/$name" archive --format=tar.gz --prefix="$name/" HEAD > "$root/cores/sources/$name-$revision.tar.gz"
    for platform in linux windows; do
        if [[ "$target" != all && "$target" != "$platform" ]]; then continue; fi
        source="$root/build/$name-$revision-$platform"
        mkdir -p "$source"
        if [[ ! -f "$source/.extracted" ]]; then
            git -C "$root/tools/$name" archive HEAD | tar -x -C "$source"
            touch "$source/.extracted"
        fi
        options=("-j$jobs" "GIT_VERSION= ${revision:0:7}")
        if [[ "$name" == nestopia ]]; then
            makefile=libretro/Makefile; library=nestopia
        else
            makefile=Makefile.libretro; library=genesis_plus_gx
            options+=(HAVE_CDROM=0 HAVE_CHD=0)
        fi
        if [[ "$platform" == windows ]]; then
            options+=(platform=win CC=x86_64-w64-mingw32-gcc-posix CXX=x86_64-w64-mingw32-g++-posix 'LDFLAGS=-static -static-libgcc -static-libstdc++')
            extension=dll
        else
            options+=(platform=unix)
            extension=so
        fi
        make -C "$source" -f "$makefile" "${options[@]}"
        cp "$source/${library}_libretro.$extension" "$root/cores/"
    done
done
cp "$root/tools/nestopia/COPYING" "$root/cores/Nestopia-LICENSE.txt"
cp "$root/tools/genesis-plus-gx/LICENSE.txt" "$root/cores/Genesis-Plus-GX-LICENSE.txt"
python3 - "$root" "$target" <<'PY'
from pathlib import Path
import hashlib, json, sys
root, target = Path(sys.argv[1]), sys.argv[2]
path = root / 'cores/core-builds.json'
manifest = json.loads(path.read_text()) if path.exists() else {'builds': []}
platforms = ['linux', 'windows'] if target == 'all' else [target]
manifest['builds'] = [b for b in manifest['builds'] if b['platform'] not in platforms]
for core, revision in [('nestopia', '06a8949e0b3cf60e3a38a374b1426bf40fccb9a0'),
                       ('genesis_plus_gx', '393f70cd64c7334564c19a424c383f53986c13f4')]:
    for platform in platforms:
        binary = root / 'cores' / (core + '_libretro.' + ('dll' if platform == 'windows' else 'so'))
        manifest['builds'].append({'core': core, 'platform': platform, 'source_commit': revision,
            'origin': 'Local source build using scripts/build-cartridge-cores.sh',
            'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest()})
manifest['origin'] = 'Per-core provenance is recorded in builds; local rebuilds replace corresponding official-build entries.'
path.write_text(json.dumps(manifest, indent=2) + '\n')
PY
