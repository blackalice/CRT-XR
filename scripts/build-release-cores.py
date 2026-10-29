"""Build release cores from exact git objects, with per-binary source/toolchain evidence.
Run with Linux Python 3.9+: python3 scripts/build-release-cores.py [all|linux|windows] [core ...].
Naming cores rebuilds only those; the other cores keep their binaries and records.
Requires make, CMake, GCC/G++, and MinGW-w64 POSIX cross-compilers for Windows.
"""
from pathlib import Path
import datetime, hashlib, json, os, shutil, subprocess, sys, tempfile, tarfile
ROOT=Path(__file__).resolve().parents[1]
# Per-core recipes: source directory holding the makefile ("" = archive root), makefile,
# optional extra make arguments, the produced library base name when it differs from the
# core name, and the licence files to retain from the exact archive.
SPECS=[
 {'core':'snes9x','repository':'snes9x','revision':'1bcc369e89f08243e0a462882fb1f3e42e51de3a','directory':'libretro','makefile':'Makefile',
  'cxx_extra':' -std=c++17','args':['LTO='],
  'licenses':[['LICENSE','Snes9x-LICENSE.txt'],['filter/snes_ntsc-license.txt','snes_ntsc-LICENSE.txt'],['jma/license.txt','JMA-LICENSE.txt'],['filter/xbrz-license.txt','xbrz-LICENSE.txt']]},
 {'core':'nestopia','repository':'nestopia','revision':'06a8949e0b3cf60e3a38a374b1426bf40fccb9a0','directory':'libretro','makefile':'Makefile',
  'patches':['nestopia-boot-background.patch'],
  'licenses':[['COPYING','Nestopia-LICENSE.txt']]},
 # Genesis Plus GX carries Mega Drive, Master System, Game Gear and Sega CD images.
 # HAVE_CDROM is libretro-common physical-drive (cdrom://) access, not Sega CD emulation;
 # it stays off on both platforms. CHD reads Sega CD discs through the bundled
 # libchdr, LZMA, zlib and zstd sources in libretro/deps.
 {'core':'genesis_plus_gx','repository':'genesis-plus-gx','revision':'393f70cd64c7334564c19a424c383f53986c13f4','directory':'','makefile':'Makefile.libretro','args':['HAVE_CDROM=0','HAVE_CHD=1'],
  'licenses':[['LICENSE.txt','Genesis-Plus-GX-LICENSE.txt'],['libretro/deps/libchdr/LICENSE.txt','libchdr-LICENSE.txt'],
   ['libretro/deps/lzma-19.00/LICENSE','LZMA-SDK-LICENSE.txt'],['libretro/deps/zstd/LICENSE','zstd-LICENSE.txt'],['libretro/deps/zlib-1.2.11/README','zlib-LICENSE.txt']]},
 {'core':'gambatte','repository':'gambatte','revision':'d9d6cd06382d1ced30de34d56d3609452323dab1','directory':'','makefile':'Makefile.libretro',
  'licenses':[['COPYING','Gambatte-LICENSE.txt']]},
 {'core':'mgba','repository':'mgba','revision':'7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6','recipe':'cmake',
  'licenses':[['LICENSE','mGBA-LICENSE.txt']]},
 {'core':'mednafen_pce_fast','repository':'beetle-pce-fast','revision':'3f946f277aef3aa99a95551618bbcd1dd2bda0d9','directory':'','makefile':'Makefile',
  'licenses':[['COPYING','Beetle-PCE-FAST-LICENSE.txt']]},
 {'core':'mednafen_lynx','repository':'beetle-lynx','revision':'fcdefcfb3c11d6d2e71be076a5d3df2e88ab73ed','directory':'','makefile':'Makefile',
  'licenses':[['COPYING','Beetle-LYNX-LICENSE.txt']]},
 {'core':'mednafen_ngp','repository':'beetle-ngp','revision':'a50d5ac288a81f2104ddf43195a4efdd15c72227','directory':'','makefile':'Makefile',
  'licenses':[['COPYING','Beetle-NGP-LICENSE.txt']]},
 {'core':'stella','repository':'stella','revision':'ba52c43b9eda950eb0c0eec69cda9b17dee8c39b','directory':'src/os/libretro','makefile':'Makefile','artifact':'stella2023',
  'licenses':[['License.txt','Stella-LICENSE.txt']]},
 {'core':'vecx','repository':'vecx','revision':'dccff5402a16d1ea7c112095a8e42632bf149506','directory':'','makefile':'Makefile.libretro','args':['HAS_GPU=0'],
  'licenses':[['LICENSE.md','Vecx-LICENSE.md']]},
 # PlayStation. Software GPU (the CRT wants native resolution); Lightrec dynarec on x86-64,
 # built from the bundled GNU Lightning. HAVE_PHYSICAL_CDROM is libretro-common drive access,
 # which a frontend without a cdrom:// browser never uses. CHD comes from the bundled libchdr,
 # with its LZMA, miniz and zstd sources (miniz and zstd carry their licences in their headers,
 # kept in the source archive).
 {'core':'pcsx_rearmed','repository':'pcsx_rearmed','revision':'c8816799b50388e61cfe237fe2cdbb7d8175f20a','directory':'','makefile':'Makefile.libretro',
  'args':['HAVE_PHYSICAL_CDROM=0'],
  'licenses':[['COPYING','PCSX-ReARMed-LICENSE.txt'],['deps/lightrec/COPYING','Lightrec-LICENSE.txt'],
   ['deps/lightning/COPYING.LESSER','GNU-Lightning-LICENSE.txt'],['deps/lightning/COPYING','GNU-Lightning-GPL-3.0-LICENSE.txt'],
   ['deps/libchdr/LICENSE.txt','PCSX-ReARMed-libchdr-LICENSE.txt'],['deps/libchdr/deps/lzma-26.02/LICENSE','PCSX-ReARMed-LZMA-LICENSE.txt'],
   ['deps/mman/README.md','mman-win32-LICENSE.md']]},
 # Nintendo 64. GLideN64 draws through the host's hidden OpenGL 3.3 context; the x86-64 dynarec
 # needs nasm. MSYSTEM selects the 64-bit MinGW branch of the makefile. Windows matches Linux's
 # feature set: no Vulkan renderer (the host offers OpenGL only), no LLE RSP, no threaded Angrylion.
 {'core':'mupen64plus_next','repository':'mupen64plus-next','revision':'6752836de8b224febfd5708444755b77712ac939','directory':'','makefile':'Makefile',
  'args':['MSYSTEM=MINGW64','HAVE_PARALLEL_RSP=0','HAVE_PARALLEL_RDP=0','HAVE_THR_AL=0','LLE=0'],
  'licenses':[['LICENSE','Mupen64Plus-Next-LICENSE.txt'],['mupen64plus-core/LICENSES','Mupen64Plus-core-LICENSE.txt'],
   ['mupen64plus-rsp-hle/LICENSES','Mupen64Plus-RSP-HLE-LICENSE.txt'],['GLideN64/LICENSE','GLideN64-LICENSE.txt'],
   ['GLideN64/licenses/gles2n64/LICENSE','GLideN64-gles2n64-LICENSE.txt'],['GLideN64/licenses/GlideHQ/gpl-2.0.txt','GLideN64-GlideHQ-LICENSE.txt'],
   ['GLideN64/licenses/Glow/LICENSE','GLideN64-Glow-LICENSE.txt'],['GLideN64/licenses/GLSL-FXAA/LICENSE.md','GLideN64-GLSL-FXAA-LICENSE.md'],
   ['GLideN64/licenses/readerwriterqueue/LICENSE.md','GLideN64-readerwriterqueue-LICENSE.md']]},
]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def output(*args):return subprocess.check_output(args,text=True).strip()
def main():
 target=sys.argv[1] if len(sys.argv)>1 else 'all'
 if target not in ['all','linux','windows']:raise SystemExit('Use all, linux or windows')
 platforms=['linux','windows'] if target=='all' else [target]
 chosen=sys.argv[2:] or [spec['core'] for spec in SPECS]
 unknown=set(chosen)-{spec['core'] for spec in SPECS}
 if unknown:raise SystemExit('Unknown cores: '+', '.join(sorted(unknown)))
 cores=ROOT/'cores';sources=cores/'sources';sources.mkdir(parents=True,exist_ok=True)
 logs=ROOT/'build/core-build-logs';logs.mkdir(parents=True,exist_ok=True)
 backup=ROOT/'archive'/('cores-before-source-build-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
 backup.mkdir(parents=True)
 for p in cores.iterdir():
  if p.is_file() and p.suffix in ['.dll','.so','.json']:shutil.copy2(p,backup/p.name)
 records=[]
 for spec in [spec for spec in SPECS if spec['core'] in chosen]:
  core,repository,revision=spec['core'],spec['repository'],spec['revision']
  repo=ROOT/'tools'/repository
  archive=sources/(repository+'-'+revision+'.tar.gz')
  if (repo/'.git').exists():
   assert output('git','-C',str(repo),'rev-parse',revision)==revision,repository+': revision must be a full commit hash present in '+str(repo)
   subprocess.run(['git','-C',str(repo),'archive','--format=tar.gz','--prefix='+repository+'/', '--output='+str(archive),revision],check=True)
   epoch=output('git','-C',str(repo),'show','-s','--format=%ct',revision)
  else:
   # Source releases have no .git directories: validate the bundled archive
   # against the recorded successful release build instead of fetching HEAD.
   known=json.loads((ROOT/'third_party/cores/release-builds.json').read_text(encoding='utf-8'))
   evidence=next(b for b in known['builds'] if b['core']==core and b['source_commit']==revision)
   assert archive.is_file() and digest(archive)==evidence['source_sha256'],'Source archive differs from release evidence'
   epoch=evidence['source_date_epoch']
  for platform in platforms:
   cc='gcc' if platform=='linux' else 'x86_64-w64-mingw32-gcc-posix'
   cxx='g++' if platform=='linux' else 'x86_64-w64-mingw32-g++-posix'
   cxx_args=cxx+spec.get('cxx_extra','')
   version=output(cc,'--version').splitlines()[0]
   with tempfile.TemporaryDirectory(prefix='crt-xr-core-') as work:
    subprocess.run(['tar','-xzf',str(archive),'-C',work],check=True)
    source=Path(work)/repository
    patches=[]
    for name in spec.get('patches',[]):
     patch=ROOT/'scripts/core-patches'/name
     subprocess.run(['git','apply','--check',str(patch)],cwd=source,check=True)
     subprocess.run(['git','apply',str(patch)],cwd=source,check=True)
     stored=sources/name;shutil.copy2(patch,stored)
     patches.append({'path':'sources/'+name,'sha256':digest(stored)})
    artifact=spec.get('artifact',core)
    extension='so' if platform=='linux' else 'dll'
    name=core+'_libretro.'+extension
    env=dict(os.environ,SOURCE_DATE_EPOCH=epoch,LC_ALL='C',TZ='UTC')
    log=logs/(core+'-'+platform+'.log')
    print('Building '+core+' '+platform,flush=True)
    with log.open('w') as stream:
     if spec.get('recipe')=='cmake':
      # Upstream libretro CI recipe; LIBMGBA_ONLY disables optional host libraries
      # (PNG, SQLite, Lua, FFmpeg...) so the core has no extra runtime dependencies.
      configure=['cmake','-S',str(source),'-B',str(Path(work)/'cmake-build'),'-DCMAKE_BUILD_TYPE=Release','-DLIBMGBA_ONLY=ON','-DBUILD_LIBRETRO=ON']
      if platform=='windows':
       configure+=['-DCMAKE_TOOLCHAIN_FILE='+str(ROOT/'native/emulation/mingw.cmake'),'-DCMAKE_SHARED_LINKER_FLAGS=-static -static-libgcc -static-libstdc++']
      subprocess.run(configure,env=env,stdout=stream,stderr=subprocess.STDOUT,check=True)
      build=['cmake','--build',str(Path(work)/'cmake-build'),'--target',artifact+'_libretro','-j'+os.environ.get('BUILD_JOBS','6')]
      subprocess.run(build,env=env,stdout=stream,stderr=subprocess.STDOUT,check=True)
      # Record both steps: the configure line carries the toolchain and link flags.
      args=configure+['&&']+build
      built=Path(work)/'cmake-build'/(artifact+'_libretro.'+extension)
     else:
      make_dir=source/spec['directory'] if spec['directory'] else source
      # Windows cores must not import libwinpthread/libstdc++ DLLs. The flags ride on the
      # compiler drivers so each upstream makefile keeps its own LDFLAGS.
      static=' -static -static-libgcc -static-libstdc++' if platform=='windows' else ''
      args=['make','-C',str(make_dir),'-f',spec['makefile'],'-j'+os.environ.get('BUILD_JOBS','6'),
            'platform='+('unix' if platform=='linux' else 'win'),'CC='+cc+static,'CXX='+cxx_args+static,
            'GIT_VERSION= '+revision[:7]]+spec.get('args',[])
      subprocess.run(args,env=env,stdout=stream,stderr=subprocess.STDOUT,check=True)
      built=make_dir/(artifact+'_libretro.'+extension)
    assert built.is_file(),built
    destination=cores/name;shutil.copy2(built,destination)
    records.append({'core':core,'platform':platform,'source_commit':revision,'origin':'Local source build',
      'binary_sha256':digest(destination),'source_archive':'sources/'+archive.name,'source_sha256':digest(archive),
      'compiler':version,'cxx_compiler':output(cxx,'--version').splitlines()[0],
      'make_version':(output('cmake','--version').splitlines()[0] if spec.get('recipe')=='cmake' else output('make','--version').splitlines()[0]),
      'make_arguments':[str(a).replace(str(source),'<extracted-source>').replace(str(work),'<work>') for a in args[1:]],
      'source_date_epoch':epoch,'build_log_sha256':digest(log), 'patches':patches})
    print('Built '+name+' '+digest(destination),flush=True)
 manifest=cores/'core-builds.json'
 previous=json.loads(manifest.read_text(encoding='utf-8')) if manifest.exists() else {'builds':[]}
 built={(r['core'],r['platform']) for r in records}
 previous['builds']=[b for b in previous.get('builds',[]) if (b['core'],b['platform']) not in built]+records
 previous['origin']='Locally built pinned source; each binary records its exact source archive, compiler, flags and SHA-256.'
 previous['build_environment']=Path('/etc/os-release').read_text()
 previous['built_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
 manifest.write_text(json.dumps(previous,indent=2)+'\n',encoding='utf-8')
 # Source-only releases use this tracked evidence when tools/<core> has no Git metadata.
 evidence=ROOT/'third_party/cores/release-builds.json'
 evidence.parent.mkdir(parents=True,exist_ok=True)
 evidence.write_bytes(manifest.read_bytes())
 for spec in SPECS:
  for relative,stored in spec['licenses']:
   with tarfile.open(sources/(spec['repository']+'-'+spec['revision']+'.tar.gz'),'r:gz') as tar:
    (cores/stored).write_bytes(tar.extractfile(spec['repository']+'/'+relative).read())
 print('Core source builds and provenance complete.',flush=True)
if __name__=='__main__':main()
