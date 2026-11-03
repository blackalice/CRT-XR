"""Build/package the opt-in Deck Dolphin core inside Dockerfile.dolphin.

docker build -f Dockerfile.dolphin -t crt-xr-dolphin .
docker run --rm -v <repo>:/work -w /work crt-xr-dolphin python3 scripts/build-dolphin-deck.py
Initialize the listed submodules first. --package-only records an existing build.
This test core is separate from the validated cross-platform release-core set.
"""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys,tarfile,tempfile

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'tools/dolphin'
REVISION='b93001ed50c8b34e6ead4eed713c2005a80386e4'
MODULES=['Externals/'+p for p in [
 'cpp-optparse/cpp-optparse','fmt/fmt','imgui/imgui','implot/implot',
 'glslang/glslang','tinygltf/tinygltf','pugixml/pugixml','enet/enet',
 'xxhash/xxHash','bzip2/bzip2','zstd/zstd','zlib-ng/zlib-ng',
 'minizip-ng/minizip-ng','lz4/lz4','libspng/libspng','libusb/libusb',
 'SFML/SFML','curl/curl','hidapi/hidapi-src','watcher/watcher','cpp-ipc/cpp-ipc']]
FLAGS=['-DCMAKE_BUILD_TYPE=Release','-DLIBRETRO=ON','-DENABLE_VULKAN=OFF',
 '-DUSE_MGBA=OFF','-DUSE_SYSTEM_LIBS=OFF','-DENABLE_X11=OFF','-DENABLE_EGL=ON','-DENABLE_HWDB=OFF']

def git(repo,*args):
 return subprocess.check_output(['git','-c','safe.directory=*','-c','core.autocrlf=true','-C',str(repo),*args],text=True).strip()

def build_tool(*args):
 command=list(args)
 if os.name=='nt':
  command=['docker','run','--rm','-v',str(ROOT)+':/work','-w','/work','crt-xr-dolphin',*command]
 return subprocess.check_output(command,cwd=ROOT,text=True)

def digest(path):
 return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
 assert git(SOURCE,'rev-parse','HEAD')==REVISION
 patch=ROOT/'scripts/core-patches/dolphin-no-gba-player.patch'
 changes=git(SOURCE,'diff','--ignore-submodules=all',REVISION)
 if not changes:
  git(SOURCE,'apply',str(patch))
 else:
  assert changes==patch.read_text().strip(),'Unexpected Dolphin source changes'
 inputs=[('',REVISION,SOURCE)]
 for module in MODULES:
  commit=git(SOURCE,'ls-tree',REVISION,module).split()[2]
  assert git(SOURCE/module,'rev-parse','HEAD')==commit,module
  assert not git(SOURCE/module,'diff','--ignore-submodules=all','--name-only',commit),module
  inputs.append((module+'/',commit,SOURCE/module))
 build=ROOT/'build/dolphin-linux'
 if '--package-only' not in sys.argv:
  subprocess.run(['cmake','-S',str(SOURCE),'-B',str(build),'-G','Ninja',*FLAGS],check=True)
  subprocess.run(['cmake','--build',str(build),'--target','dolphin_libretro','--parallel',os.environ.get('BUILD_JOBS','8')],check=True)
 cores=ROOT/'cores'; (cores/'sources').mkdir(parents=True,exist_ok=True)
 archive=cores/'sources'/f'dolphin-{REVISION}.tar.gz'
 shutil.copy2(patch,cores/'sources'/patch.name)
 with tempfile.TemporaryDirectory() as temporary,tarfile.open(archive,'w:gz') as combined:
  for index,(prefix,commit,repo) in enumerate(inputs):
   part=Path(temporary)/(str(index)+'.tar')
   git(repo,'archive','--format=tar','--prefix=dolphin/'+prefix,'--output='+str(part),commit)
   with tarfile.open(part) as source_tar:
    for member in source_tar:
     combined.addfile(member,source_tar.extractfile(member) if member.isfile() else None)
 binary=cores/'dolphin_libretro.so'
 shutil.copy2(build/'dolphin_libretro.so',binary)
 build_tool('strip','--strip-unneeded',binary.relative_to(ROOT).as_posix())
 data=ROOT/'core-data/dolphin-emu/Sys'
 shutil.copytree(SOURCE/'Data/Sys',data,dirs_exist_ok=True)
 (ROOT/'core-data/.gdignore').touch()
 shutil.copy2(SOURCE/'COPYING',cores/'Dolphin-LICENSE.txt')
 shutil.copytree(SOURCE/'LICENSES',cores/'Dolphin-LICENSES',dirs_exist_ok=True)
 record={'core':'dolphin','platform':'linux','status':'Experimental Deck test build',
  'source_url':'https://github.com/libretro/dolphin','source_commit':REVISION,
  'source_archive':archive.relative_to(cores).as_posix(),'source_sha256':digest(archive),
  'patches':[{'path':'sources/'+patch.name,'sha256':digest(patch)}],
  'binary_sha256':digest(binary),'compiler':build_tool('g++-12','--version').splitlines()[0],
  'cmake_flags':FLAGS,'submodules':{prefix.rstrip('/'):commit for prefix,commit,_ in inputs if prefix},
  'sys_files':{p.relative_to(data).as_posix():digest(p) for p in sorted(data.rglob('*')) if p.is_file()}}
 for destination in [cores/'dolphin-test-build.json',ROOT/'third_party/cores/dolphin-test-build.json']:
  destination.write_text(json.dumps(record,indent=2)+'\n')
 print('Packaged experimental Dolphin core, pinned source archive and Sys data',flush=True)

if __name__=='__main__': main()
