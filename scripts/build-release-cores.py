"""Build release cores from exact git objects, with per-binary source/toolchain evidence.
Run with Linux Python 3.9+: python3 scripts/build-release-cores.py [all|linux|windows].
Requires make, GCC/G++, and MinGW-w64 POSIX cross-compilers for Windows.
"""
from pathlib import Path
import datetime, hashlib, json, os, shutil, subprocess, sys, tempfile, tarfile

ROOT=Path(__file__).resolve().parents[1]
SPECS=[('snes9x','snes9x','1bcc369e89f08243e0a462882fb1f3e42e51de3a','libretro/Makefile'),
       ('nestopia','nestopia','06a8949e0b3cf60e3a38a374b1426bf40fccb9a0','libretro/Makefile'),
       ('genesis_plus_gx','genesis-plus-gx','393f70cd64c7334564c19a424c383f53986c13f4','Makefile.libretro')]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def output(*args):return subprocess.check_output(args,text=True).strip()
def main():
 target=sys.argv[1] if len(sys.argv)>1 else 'all'
 if target not in ['all','linux','windows']:raise SystemExit('Use all, linux or windows')
 platforms=['linux','windows'] if target=='all' else [target]
 cores=ROOT/'cores';sources=cores/'sources';sources.mkdir(parents=True,exist_ok=True)
 logs=ROOT/'build/core-build-logs';logs.mkdir(parents=True,exist_ok=True)
 backup=ROOT/'archive'/('cores-before-source-build-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
 backup.mkdir(parents=True)
 for p in cores.iterdir():
  if p.is_file() and p.suffix in ['.dll','.so','.json']:shutil.copy2(p,backup/p.name)
 records=[]
 for core,repository,revision,makefile in SPECS:
  repo=ROOT/'tools'/repository
  archive=sources/(repository+'-'+revision+'.tar.gz')
  if (repo/'.git').exists():
   assert output('git','-C',str(repo),'rev-parse',revision)==revision
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
   version=output(cc,'--version').splitlines()[0]
   with tempfile.TemporaryDirectory(prefix='crt-xr-core-') as work:
    subprocess.run(['tar','-xzf',str(archive),'-C',work],check=True)
    source=Path(work)/repository
    make_dir=source/'libretro' if core in ['snes9x','nestopia'] else source
    build_makefile='Makefile' if core in ['snes9x','nestopia'] else makefile
    args=['make','-C',str(make_dir),'-f',build_makefile,'-j'+os.environ.get('BUILD_JOBS','6'),
          'platform='+('unix' if platform=='linux' else 'win'),'CC='+cc,
          'CXX='+cxx+(' -std=c++17' if core=='snes9x' else ''),'GIT_VERSION= '+revision[:7]]
    if core=='snes9x':args+=['LTO=']
    if core=='genesis_plus_gx':args+=['HAVE_CDROM=0','HAVE_CHD=0']
    if platform=='windows':args+=['LDFLAGS=-static -static-libgcc -static-libstdc++']
    env=dict(os.environ,SOURCE_DATE_EPOCH=epoch,LC_ALL='C',TZ='UTC')
    log=logs/(core+'-'+platform+'.log')
    print('Building '+core+' '+platform,flush=True)
    with log.open('w') as stream:
     subprocess.run(args,env=env,stdout=stream,stderr=subprocess.STDOUT,check=True)
    name=core+'_libretro.'+('so' if platform=='linux' else 'dll')
    built=make_dir/name
    assert built.is_file(),built
    destination=cores/name;shutil.copy2(built,destination)
    records.append({'core':core,'platform':platform,'source_commit':revision,'origin':'Local source build',
      'binary_sha256':digest(destination),'source_archive':'sources/'+archive.name,'source_sha256':digest(archive),
      'compiler':version,'cxx_compiler':output(cxx,'--version').splitlines()[0],
      'make_version':output('make','--version').splitlines()[0],
      'make_arguments':[str(a).replace(str(source),'<extracted-source>') for a in args[1:]],
      'source_date_epoch':epoch,'build_log_sha256':digest(log)})
    print('Built '+name+' '+digest(destination),flush=True)
 manifest=cores/'core-builds.json'
 previous=json.loads(manifest.read_text(encoding='utf-8')) if manifest.exists() else {'builds':[]}
 previous['builds']=[b for b in previous.get('builds',[]) if b['platform'] not in platforms]+records
 previous['origin']='Locally built pinned source; each binary records its exact source archive, compiler, flags and SHA-256.'
 previous['build_environment']=Path('/etc/os-release').read_text()
 previous['built_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
 manifest.write_text(json.dumps(previous,indent=2)+'\n',encoding='utf-8')
 for source,name in [('snes9x/LICENSE','Snes9x-LICENSE.txt'),('snes9x/filter/snes_ntsc-license.txt','snes_ntsc-LICENSE.txt'),('snes9x/jma/license.txt','JMA-LICENSE.txt'),('snes9x/filter/xbrz-license.txt','xbrz-LICENSE.txt'),('nestopia/COPYING','Nestopia-LICENSE.txt'),('genesis-plus-gx/LICENSE.txt','Genesis-Plus-GX-LICENSE.txt')]:
  repository,relative=source.split('/',1)
  revision=next(s[2] for s in SPECS if s[1]==repository)
  with tarfile.open(sources/(repository+'-'+revision+'.tar.gz'),'r:gz') as archive:
   (cores/name).write_bytes(archive.extractfile(repository+'/'+relative).read())
 print('Core source builds and provenance complete.',flush=True)
if __name__=='__main__':main()
