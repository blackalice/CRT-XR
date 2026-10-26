"""Create complete source/build inputs alongside beta binaries, without local media or models."""
from pathlib import Path
import hashlib,io,json,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[1]
version=(ROOT/'project.godot').read_text(encoding='utf-8').split('config/version="',1)[1].split('"',1)[0]
output=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else ROOT/'build/release-source'/('CRT-XR-'+version+'-corresponding-source.tar.gz')
output.parent.mkdir(parents=True,exist_ok=True)
subprocess.run([sys.executable,str(ROOT/'scripts/check-core-sources.py')],check=True)
paths=set(subprocess.check_output(['git','ls-files','-c','-o','--exclude-standard','-z'],cwd=ROOT).decode().split('\0'))-{''}
files={name:ROOT/name for name in paths if (ROOT/name).is_file()}
for p in (ROOT/'cores/sources').glob('*.tar.gz'):files['cores/sources/'+p.name]=p
for p in (ROOT/'cores/sources').glob('*.patch'):files['cores/sources/'+p.name]=p
files['cores/core-builds.json']=ROOT/'cores/core-builds.json'
for p in (ROOT/'build/core-build-logs').glob('*.log'):files['build-materials/'+p.name]=p
assert len([p for p in files if p.startswith('cores/sources/')])>=5,'Missing core/binding/engine input archives'
for name in files:
 assert name.split('/')[0] not in ['sdk','tools','archive','dist','roms','saves','userdata'],name
 assert Path(name).suffix not in ['.dll','.so','.sfc','.nes','.sms','.gg','.srm','.mp3','.pem','.key'],name
recipe='''# Rebuilding the supplied source

Original CRT XR code is MIT; preserve all upstream notices. See docs/CORE-DISTRIBUTION.md for the in-process GPL core treatment and separate restricted cores.

This archive supplies the actual application/host source tree, exact core source snapshots, godot-cpp bindings, Godot engine source, core build logs and per-binary source/compiler/flag hashes. Native host code is in native/emulation; installation scripts are in scripts/installer. SOURCE-MANIFEST.json identifies every supplied input. Local TV/table model originals are separate artistic data, not bundled here; use creator URLs and preparation instructions in docs/DEVELOPMENT.md.

On Linux with Python 3.9+, Git, GCC/G++, CMake, Make and the MinGW-w64 POSIX compiler installed (see Dockerfile.emulation):

```sh
mkdir -p tools extensions/bin
for archive in cores/sources/*.tar.gz; do tar -xzf "$archive" -C tools; done
cmake -S native/emulation -B build/host-linux -DCMAKE_BUILD_TYPE=Release
cmake --build build/host-linux --parallel 6
cmake -S native/emulation -B build/host-windows -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$PWD/native/emulation/mingw.cmake"
cmake --build build/host-windows --parallel 6
cp tools/godot-cpp/LICENSE.md extensions/bin/godot-cpp-LICENSE.md
python3 scripts/build-release-cores.py all
bash scripts/build-linux.sh
python3 scripts/check-core-sources.py
```

The core builder uses SHA-verified supplied source archives when Git metadata is absent; no mutable nightly download is needed. It then applies the recorded patches under scripts/core-patches; copies and hashes of those patches are also supplied under cores/sources and in core-builds.json. Hashes identify exact inputs and outputs; future compilers are not promised bit-for-bit identical results. The recorded successful core build used Ubuntu 24.04/GCC 13 and MinGW GCC 13. Binary package notices and source access must accompany redistribution.

For Windows VITURE tracking, compile native/windows_tracking/bridge.cpp with MinGW POSIX and -std=c++17 -O2 -static -municode, linking ws2_32, setupapi and hid, as recorded in scripts/build-windows-tracking.ps1. No vendor headers or proprietary runtime are required to compile this bridge. Runtime VITURE SDK files are separately obtained by the user and are not in this source archive or binary packages. Windows exports require Python on Windows to apply the per-monitor DPI manifest with scripts/set-windows-dpi.py; retain the separate PCK.

To compile/export the application, use Godot 4.5.1 and its matching export templates. Official engine binaries and the engine source are MIT, with separate component notices under third_party/godot. The supplied Godot source folder contains its own platform build instructions; https://docs.godotengine.org/en/4.5/contributing/development/compiling/ covers engine builds. See docs/DEVELOPMENT.md for editor, test and export commands. Godot runtime packages and compatible system libraries are prerequisites, not fetched by this source archive.
'''
manifest={name:hashlib.sha256(p.read_bytes()).hexdigest() for name,p in sorted(files.items())}
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
info={'version':version,'base_commit':commit,'snapshot_sha256':hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest(),'files':manifest}
prefix='CRT-XR-'+version+'-source/'
with tarfile.open(output,'w:gz') as archive:
 for name,p in sorted(files.items()):
  data=p.read_bytes();entry=tarfile.TarInfo(prefix+name);entry.size=len(data);entry.mode=0o755 if name.endswith('.sh') else 0o644
  archive.addfile(entry,io.BytesIO(data))
 for name,data in [('REBUILD.md',recipe.encode()),('SOURCE-MANIFEST.json',(json.dumps(info,indent=2)+'\n').encode())]:
  entry=tarfile.TarInfo(prefix+name);entry.size=len(data);entry.mode=0o644;archive.addfile(entry,io.BytesIO(data))
print('Corresponding source:',output)
print('SHA-256:',hashlib.sha256(output.read_bytes()).hexdigest())
