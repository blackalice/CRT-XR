"""Build/package the opt-in Deck PPSSPP (PSP) core inside Dockerfile.ppsspp.

docker build -f Dockerfile.ppsspp -t crt-xr-ppsspp .
docker run --rm -v <repo>:/work -w /work crt-xr-ppsspp python3 scripts/build-ppsspp-deck.py
Clones tools/ppsspp at the pinned release (with submodules) when it is missing.
FFmpeg is configured and compiled from the ffmpeg submodule's source; the
prebuilt libraries that submodule ships are never linked. --package-only
records an existing build. This test core is separate from the validated
cross-platform release-core set.
"""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys,tarfile,tempfile

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'tools/ppsspp'
URL='https://github.com/hrydgard/ppsspp.git'
TAG='v1.20.4'
REVISION='fa50bb1976065c4f8b1b47af227d367fe9771555'
BUILD=ROOT/'build/ppsspp-linux'
FFMPEG=ROOT/'build/ppsspp-ffmpeg'
FFMPEG_PREFIX=FFMPEG/'src/linux/x86_64' # where ffmpeg/linux_x86-64.sh installs
# Prebuilt per-platform FFmpeg libraries and test/Apple-only submodules: not
# sources of this core, so they stay out of the source archive.
FFMPEG_PREBUILT=['android','blackberry','ios','linux','macosx','symbian','tvos','Windows','Windows10','wiiu']
ARCHIVE_SKIP=['pspautotests','ios/MoltenVK','SDL/macOS']
FLAGS=['-DCMAKE_BUILD_TYPE=Release','-DLIBRETRO=ON','-DUSE_SYSTEM_LIBPNG=OFF','-DUSE_DISCORD=OFF',
 '-DUSE_CCACHE=OFF','-DHEADLESS=OFF','-DUNITTEST=OFF','-DFFMPEG_DIR='+FFMPEG_PREFIX.as_posix(),
 # Export only the Libretro API: the app preloads the system libstdc++, which
 # would otherwise interpose on the copy linked in here and crash the core.
 '-DCMAKE_SHARED_LINKER_FLAGS=-static-libstdc++ -static-libgcc -Wl,--exclude-libs,ALL -Wl,--version-script='+(SOURCE/'libretro/link.T').as_posix()]
# ppsspp-unload-during-boot: retro_unload_game while the loader thread still
# boots waits for it (PSP_CancelBoot) instead of shutting down under it.
PATCHES=['ppsspp-unload-during-boot.patch']
ASSET_SKIP={'debugger'} # web debugger UI, unused by the libretro core
# The repository is bind-mounted from Windows, so its owner differs.
ENV=dict(os.environ,GIT_CONFIG_COUNT='1',GIT_CONFIG_KEY_0='safe.directory',GIT_CONFIG_VALUE_0='*')

def git(repo,*args):
 return subprocess.check_output(['git','-c','core.autocrlf=false','-C',str(repo),*args],text=True,env=ENV).strip()

def run(*args,cwd=ROOT):
 subprocess.run(list(args),cwd=cwd,check=True,env=ENV)

def output(*args):
 return subprocess.check_output(list(args),cwd=ROOT,text=True,env=ENV)

def digest(path):
 return hashlib.sha256(path.read_bytes()).hexdigest()

def submodules(repo,commit,prefix=''):
 """(path prefix, commit, checkout) for repo and every nested submodule."""
 found=[(prefix,commit,repo)]
 for line in git(repo,'ls-tree','-r',commit).splitlines():
  meta,path=line.split('\t',1)
  mode,kind,child=meta.split()
  if kind!='commit': continue
  checkout=repo/path
  assert git(checkout,'rev-parse','HEAD')==child,prefix+path
  assert not git(checkout,'status','--porcelain','--untracked-files=no','--ignore-submodules=all'),prefix+path
  found+=submodules(checkout,child,prefix+path+'/')
 return found

def checkout():
 if not (SOURCE/'.git').exists():
  run('git','-c','core.autocrlf=false','clone','--branch',TAG,'--recurse-submodules','--shallow-submodules',URL,str(SOURCE))
 assert git(SOURCE,'rev-parse','HEAD')==REVISION,'tools/ppsspp is not at '+TAG
 patches=[ROOT/'scripts/core-patches'/name for name in PATCHES]
 expected='\n'.join(patch.read_text().strip() for patch in patches)
 changes=git(SOURCE,'diff','--ignore-submodules=all',REVISION)
 assert not changes or changes==expected,'Unexpected PPSSPP source changes'
 if not changes:
  for patch in patches: git(SOURCE,'apply',str(patch))
 assert git(SOURCE,'diff','--ignore-submodules=all',REVISION)==expected,'PPSSPP patch mismatch'
 return patches

def build_ffmpeg(ffmpeg_commit):
 source=FFMPEG/'src'
 if source.exists(): shutil.rmtree(source)
 source.mkdir(parents=True)
 with tempfile.TemporaryDirectory() as temporary:
  part=Path(temporary)/'ffmpeg.tar'
  git(SOURCE/'ffmpeg','archive','--format=tar','--output='+str(part),ffmpeg_commit,'.',
   *[':(exclude)'+name for name in FFMPEG_PREBUILT])
  with tarfile.open(part) as archive: archive.extractall(source)
 assert not FFMPEG_PREFIX.exists()
 jobs=os.environ.get('BUILD_JOBS','8')
 subprocess.run(['sh','linux_x86-64.sh'],cwd=source,check=True,env=dict(ENV,MAKEFLAGS='-j'+jobs))
 for name in ['avcodec','avformat','avutil','swresample','swscale']:
  assert (FFMPEG_PREFIX/'lib'/('lib'+name+'.a')).is_file(),name

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
 patches=checkout()
 inputs=submodules(SOURCE,REVISION)
 ffmpeg_commit=next(commit for prefix,commit,_ in inputs if prefix=='ffmpeg/')
 if '--package-only' not in sys.argv:
  if not FFMPEG_PREFIX.exists(): build_ffmpeg(ffmpeg_commit)
  run('cmake','-S',str(SOURCE),'-B',str(BUILD),'-G','Ninja',*FLAGS)
  run('cmake','--build',str(BUILD),'--target','ppsspp_libretro','--parallel',os.environ.get('BUILD_JOBS','8'))
 cores=ROOT/'cores'; (cores/'sources').mkdir(parents=True,exist_ok=True)
 archive=cores/'sources'/f'ppsspp-{REVISION}.tar.gz'
 skipped=[p+'/' for p in ARCHIVE_SKIP]
 with tempfile.TemporaryDirectory() as temporary,tarfile.open(archive,'w:gz') as combined:
  for index,(prefix,commit,repo) in enumerate(inputs):
   if any(prefix.startswith(s) for s in skipped): continue
   part=Path(temporary)/(str(index)+'.tar')
   excludes=[':(exclude)'+name for name in FFMPEG_PREBUILT] if prefix=='ffmpeg/' else []
   git(repo,'archive','--format=tar','--prefix=ppsspp/'+prefix,'--output='+str(part),commit,'.',*excludes)
   with tarfile.open(part) as source_tar:
    for member in source_tar:
     combined.addfile(member,source_tar.extractfile(member) if member.isfile() else None)
 binary=cores/'ppsspp_libretro.so'
 shutil.copy2(BUILD/'lib/ppsspp_libretro.so',binary)
 run('strip','--strip-unneeded',str(binary))
 data=ROOT/'core-data/ppsspp/PPSSPP'
 if data.exists(): shutil.rmtree(data)
 shutil.copytree(SOURCE/'assets',data,ignore=lambda folder,names:[n for n in names if Path(folder)==SOURCE/'assets' and n in ASSET_SKIP])
 (ROOT/'core-data/.gdignore').touch()
 shutil.copy2(SOURCE/'LICENSE.TXT',cores/'PPSSPP-LICENSE.txt')
 shutil.copy2(SOURCE/'ffmpeg/COPYING.LGPLv2.1',cores/'PPSSPP-FFmpeg-LICENSE.txt')
 for patch in patches: shutil.copy2(patch,cores/'sources'/patch.name)
 record={'core':'ppsspp','platform':'linux','status':'Experimental Deck test build',
  'patches':[{'path':'sources/'+patch.name,'sha256':digest(patch)} for patch in patches],
  'source_url':URL,'source_tag':TAG,'source_commit':REVISION,
  'source_archive':archive.relative_to(cores).as_posix(),'source_sha256':digest(archive),
  'source_archive_excludes':ARCHIVE_SKIP+['ffmpeg/'+name for name in FFMPEG_PREBUILT],
  'binary_sha256':digest(binary),'compiler':output('g++-12','--version').splitlines()[0],
  'ffmpeg':'built from the ffmpeg submodule source by ffmpeg/linux_x86-64.sh (static, LGPL)',
  'cmake_flags':FLAGS,'elf':elf_report(binary),
  'submodules':{prefix.rstrip('/'):commit for prefix,commit,_ in inputs if prefix},
  'system_files':{p.relative_to(data).as_posix():digest(p) for p in sorted(data.rglob('*')) if p.is_file()}}
 for destination in [cores/'ppsspp-test-build.json',ROOT/'third_party/cores/ppsspp-test-build.json']:
  destination.write_text(json.dumps(record,indent=2)+'\n')
 print('Packaged experimental PPSSPP core, pinned source archive and system assets',flush=True)

if __name__=='__main__': main()
