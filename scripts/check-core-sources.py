"""Verify every shipped core binary against its recorded source build inputs."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
cores=ROOT/'cores'
record=json.loads((cores/'core-builds.json').read_text(encoding='utf-8'))
builds=record['builds']
CORES=['snes9x','nestopia','genesis_plus_gx','gambatte','mgba','mednafen_pce_fast','mednafen_lynx','mednafen_ngp','stella','vecx']
# Desktop records are always required; Android's are optional until it ships, but
# then complete.
platforms=['linux','windows']+(['android-arm64'] if any(b['platform']=='android-arm64' for b in builds) else [])
expected={(c,p) for c in CORES for p in platforms}
assert {(b['core'],b['platform']) for b in builds}==expected and len(builds)==len(expected),'Incomplete core build evidence'
def binary_name(core,platform):
 if platform=='android-arm64':return 'android-arm64/lib'+core+'_libretro.so'
 return core+'_libretro.'+('so' if platform=='linux' else 'dll')
evidence=ROOT/'third_party/cores/release-builds.json'
if evidence.exists():
 assert json.loads(evidence.read_text(encoding='utf-8'))['builds']==builds,'Source-only rebuild evidence is stale'
for b in builds:
 binary=cores/binary_name(b['core'],b['platform'])
 # An exported platform folder has only that platform's binaries.
 if binary.exists():
  assert b['origin']=='Local source build'
  assert hashlib.sha256(binary.read_bytes()).hexdigest()==b['binary_sha256'],str(binary)
 source=cores/b['source_archive']
 assert source.resolve().is_relative_to(cores.resolve())
 assert hashlib.sha256(source.read_bytes()).hexdigest()==b['source_sha256'],str(source)
 for patch in b.get('patches',[]):
  path=cores/patch['path']
  assert path.resolve().is_relative_to(cores.resolve())
  assert hashlib.sha256(path.read_bytes()).hexdigest()==patch['sha256'],str(path)
 assert b['compiler'] and b['cxx_compiler'] and b['make_arguments'] and b['source_commit']
for name in ['Snes9x-LICENSE.txt','Genesis-Plus-GX-LICENSE.txt','libchdr-LICENSE.txt','LZMA-SDK-LICENSE.txt','zstd-LICENSE.txt','zlib-LICENSE.txt','Nestopia-LICENSE.txt','Gambatte-LICENSE.txt','mGBA-LICENSE.txt','Beetle-PCE-FAST-LICENSE.txt','Beetle-LYNX-LICENSE.txt','Beetle-NGP-LICENSE.txt','Stella-LICENSE.txt','Vecx-LICENSE.md','libretro-header-LICENSE.txt']:
 assert (cores/name).is_file(),name
print('Recorded core binaries, all %d source-build records (%s) and complete core source archive hashes verified.' % (len(builds),', '.join(platforms)))
