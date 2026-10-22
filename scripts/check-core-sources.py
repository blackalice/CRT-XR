"""Verify every shipped core binary against its recorded source build inputs."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
cores=ROOT/'cores'
record=json.loads((cores/'core-builds.json').read_text(encoding='utf-8'))
builds=record['builds']
expected={(c,p) for c in ['snes9x','nestopia','genesis_plus_gx','gambatte','mgba','mednafen_pce_fast','mednafen_lynx','mednafen_ngp','stella','vecx'] for p in ['linux','windows']}
assert {(b['core'],b['platform']) for b in builds}==expected and len(builds)==20,'Incomplete core build evidence'
evidence=ROOT/'third_party/cores/release-builds.json'
if evidence.exists():
 assert json.loads(evidence.read_text(encoding='utf-8'))['builds']==builds,'Source-only rebuild evidence is stale'
for b in builds:
 binary=cores/(b['core']+'_libretro.'+('so' if b['platform']=='linux' else 'dll'))
 # An exported platform folder has only that platform's binaries.
 if binary.exists():
  assert b['origin']=='Local source build'
  assert hashlib.sha256(binary.read_bytes()).hexdigest()==b['binary_sha256'],str(binary)
 source=cores/b['source_archive']
 assert source.resolve().is_relative_to(cores.resolve())
 assert hashlib.sha256(source.read_bytes()).hexdigest()==b['source_sha256'],str(source)
 assert b['compiler'] and b['cxx_compiler'] and b['make_arguments'] and b['source_commit']
for name in ['Snes9x-LICENSE.txt','Genesis-Plus-GX-LICENSE.txt','Nestopia-LICENSE.txt','Gambatte-LICENSE.txt','mGBA-LICENSE.txt','Beetle-PCE-FAST-LICENSE.txt','Beetle-LYNX-LICENSE.txt','Beetle-NGP-LICENSE.txt','Stella-LICENSE.txt','Vecx-LICENSE.md','libretro-header-LICENSE.txt']:
 assert (cores/name).is_file(),name
print('Recorded core binaries, all twenty source-build records and complete core source archive hashes verified.')
