"""Build/package the opt-in Deck LRPS2 (PlayStation 2) core inside Dockerfile.dolphin.

docker build -f Dockerfile.dolphin -t crt-xr-dolphin .
docker run --rm -v <repo>:/work -w /work crt-xr-dolphin python3 scripts/build-lrps2-deck.py
Clones tools/lrps2 at the pinned commit when it is missing and applies the
recorded patches. The Dolphin image's GCC 12, CMake and Ninja build it; LRPS2
needs nothing else (no submodules, its game database is built in). Vulkan is
off: the host offers OpenGL only. --package-only records an existing build.
This test core is separate from the validated cross-platform release-core set.
"""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys,tarfile,tempfile

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'tools/lrps2'
URL='https://github.com/libretro/ps2.git'
REVISION='88098c430d1e20f7541e4160b9a17e1f90d83446'
BUILD=ROOT/'build/lrps2-linux'
# lrps2-image-maps: map the main and code maps over an arena in the core's own
# .bss, always in reach and at one address for every game (upstream #186 removed
# its .bss fallback; the recompilers then abort in a crowded address space).
# lrps2-vtlb-moved-map: the VTLB tables cached across games are carved again
# when the main map was placed elsewhere for the next game (the core stays
# loaded, so a stale cache pointed into unmapped memory and vtlb_Init crashed).
PATCHES=['lrps2-image-maps.patch','lrps2-vtlb-moved-map.patch']
FLAGS=['-DCMAKE_BUILD_TYPE=Release','-DLIBRETRO=ON','-DUSE_VULKAN=OFF']
# The repository is bind-mounted from Windows, so its owner differs.
ENV=dict(os.environ,GIT_CONFIG_COUNT='1',GIT_CONFIG_KEY_0='safe.directory',GIT_CONFIG_VALUE_0='*')

def git(repo,*args):
 return subprocess.check_output(['git','-c','core.autocrlf=false','-C',str(repo),*args],text=True,env=ENV).strip()

def run(*args):
 subprocess.run(list(args),cwd=ROOT,check=True,env=ENV)

def output(*args):
 return subprocess.check_output(list(args),cwd=ROOT,text=True,env=ENV)

def digest(path):
 return hashlib.sha256(path.read_bytes()).hexdigest()

def checkout(patches):
 if not SOURCE.exists():
  run('git','clone','--filter=blob:none',URL,str(SOURCE))
  run('git','-C',str(SOURCE),'checkout','--detach',REVISION)
 assert git(SOURCE,'rev-parse','HEAD')==REVISION,'tools/lrps2 is not at '+REVISION
 expected='\n'.join(patch.read_text().strip() for patch in patches)
 changes=git(SOURCE,'diff',REVISION)
 assert not changes or changes==expected,'Unexpected LRPS2 source changes'
 if not changes:
  for patch in patches: git(SOURCE,'apply',str(patch))
 assert git(SOURCE,'diff',REVISION)==expected,'LRPS2 patch mismatch'

def elf_report(binary):
 dynamic=output('readelf','-d',str(binary))
 symbols=output('objdump','-T',str(binary))
 def highest(prefix):
  found={tuple(int(p) for p in v.split('.')) for v in re.findall(prefix+r'_([0-9.]+[0-9])',symbols)}
  return prefix+'_'+'.'.join(map(str,max(found))) if found else None
 return {'needed':re.findall(r'\(NEEDED\)\s+Shared library: \[([^\]]+)\]',dynamic),
  'max_glibc':highest('GLIBC'),'max_glibcxx':highest('GLIBCXX'),'max_cxxabi':highest('CXXABI'),
  'retro_exports':sorted(set(re.findall(r'\b(retro_[a-z_]+)$',symbols,re.M)))}

def main():
 patches=[ROOT/'scripts/core-patches'/name for name in PATCHES]
 checkout(patches)
 if '--package-only' not in sys.argv:
  run('cmake','-S',str(SOURCE),'-B',str(BUILD),'-G','Ninja',*FLAGS)
  run('cmake','--build',str(BUILD),'--target','pcsx2_libretro','--parallel',os.environ.get('BUILD_JOBS','8'))
 cores=ROOT/'cores'; (cores/'sources').mkdir(parents=True,exist_ok=True)
 archive=cores/'sources'/f'lrps2-{REVISION}.tar.gz'
 for patch in patches: shutil.copy2(patch,cores/'sources'/patch.name)
 with tempfile.TemporaryDirectory() as temporary:
  part=Path(temporary)/'lrps2.tar'
  git(SOURCE,'archive','--format=tar','--prefix=lrps2/','--output='+str(part),REVISION)
  with tarfile.open(part) as source_tar,tarfile.open(archive,'w:gz') as combined:
   for member in source_tar:
    combined.addfile(member,source_tar.extractfile(member) if member.isfile() else None)
 binary=cores/'pcsx2_libretro.so'
 shutil.copy2(BUILD/'bin/pcsx2_libretro.so',binary)
 run('strip','--strip-unneeded',str(binary))
 shutil.copy2(SOURCE/'COPYING.GPLv3',cores/'LRPS2-LICENSE.txt')
 record={'core':'pcsx2 (LRPS2)','platform':'linux','status':'Experimental Deck test build',
  'source_url':URL,'source_commit':REVISION,
  'source_archive':archive.relative_to(cores).as_posix(),'source_sha256':digest(archive),
  'patches':[{'path':'sources/'+patch.name,'sha256':digest(patch)} for patch in patches],
  'binary_sha256':digest(binary),'compiler':output('g++-12','--version').splitlines()[0],
  'cmake_flags':FLAGS,'elf':elf_report(binary)}
 for destination in [cores/'lrps2-test-build.json',ROOT/'third_party/cores/lrps2-test-build.json']:
  destination.write_text(json.dumps(record,indent=2)+'\n')
 print('Packaged experimental LRPS2 core, pinned source archive and patch',flush=True)

if __name__=='__main__': main()
