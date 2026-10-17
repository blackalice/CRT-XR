"""Offline per-user CRT XR installer. Steam must be closed before configuration writes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import zlib
from steam_config import load_binary,dump_binary,integer,load_text,dump_text,branch

DRIVER_HASH='bb14df734f6fb81fb22d584e9954a843acb4dda68c841bab176053e0371479ed'


def steam_running():
    for path in Path('/proc').glob('[0-9]*/comm'):
        try:
            if path.read_text().strip()=='steam': return True
        except OSError: pass
    return False


def verified_payload(package):
    manifest=json.loads((package/'package-manifest.json').read_text(encoding='utf-8'))
    for name,digest in manifest.items():
        path=package/name
        if path.is_symlink() or not path.resolve().is_relative_to(package.resolve()): raise ValueError('Unsafe package path')
        if hashlib.sha256(path.read_bytes()).hexdigest()!=digest: raise ValueError('Package integrity check failed: '+name)
    required=['crt-xr.x86_64','crt-xr-engine.x86_64','crt-xr.pck','launch-steam.sh','steam-session.py','display-probe.py']
    for name in required:
        if name not in manifest: raise ValueError('Incomplete package: '+name)
    # Only manifest-listed files are installed; unrelated files are never copied.
    return manifest


def configure(shortcuts,localconfig,executable,startdir,resolution):
    binary=load_binary(shortcuts) if shortcuts else {'shortcuts':(0,{})}
    if set(binary)!={'shortcuts'} or binary['shortcuts'][0]!=0: raise ValueError('Unexpected Steam shortcuts root')
    entries=binary['shortcuts'][1]
    matches=[v[1] for v in entries.values() if v[0]==0 and v[1].get('appname',(1,''))[1] in ['CRT XR','RetroCRT XR']]
    if len(matches)>1: raise ValueError('Multiple CRT XR shortcuts; remove duplicate entries before installing')
    if matches:
        entry=matches[0]
        if entry.get('appid',(None,None))[0]!=2: raise ValueError('Invalid existing CRT XR app ID')
        appid=int.from_bytes(entry['appid'][1],'little')
    else:
        appid=zlib.crc32((executable+'CRT XR').encode())|0x80000000
        entry={'appid':integer(appid)}
        index=str(max([int(k) for k in entries if k.isdigit()],default=-1)+1)
        entries[index]=(0,entry)
    entry.update({'appname':(1,'CRT XR'),'exe':(1,executable),'StartDir':(1,startdir),
                  'IsHidden':integer(0),'AllowDesktopConfig':integer(0),
                  'AllowOverlay':integer(1),'OpenVR':integer(0)})
    entry.setdefault('tags',(0,{}))
    entry.setdefault('LaunchOptions',(1,''))
    config=load_text(localconfig)
    if not any(k.lower()=='userlocalconfigstore' for k in config): raise ValueError('Unexpected Steam localconfig root')
    app=branch(config,['UserLocalConfigStore','Software','Valve','Steam','apps',str(appid)])
    app['ResolutionOverride2']=resolution
    # Preserve existing controller configuration/app ID and other apps verbatim in value.
    return dump_binary(binary),dump_text(config),appid


def atomic(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    fd,name=tempfile.mkstemp(prefix='.crt-xr-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as file: file.write(data);file.flush();os.fsync(file.fileno())
        if path.exists(): os.chmod(name,path.stat().st_mode & 0o777)
        os.replace(name,path)
    finally:
        if os.path.exists(name): os.unlink(name)


def artwork_plan(package,config,appid,previous,allowed=None):
    """Only replace artwork that still matches our last installed bytes."""
    names={'Portrait.png':f'{appid}p','Landscape.png':str(appid),
           'Hero.png':f'{appid}_hero','Logo.png':f'{appid}_logo'}
    changes={};owned={}
    for source,stem in names.items():
        image=package/'artwork'/source
        if allowed is not None and 'artwork/'+source not in allowed:continue
        if not image.is_file(): continue
        target=config/'grid'/(stem+'.png')
        existing=[config/'grid'/(stem+ext) for ext in ['.png','.jpg','.jpeg','.webp']]
        existing=[p for p in existing if p.exists() or p.is_symlink()]
        if existing:
            if existing!=[target] or target.is_symlink():continue
            digest=hashlib.sha256(target.read_bytes()).hexdigest()
            if previous.get(target.name)!=digest:continue
        data=image.read_bytes();changes[target]=data
        owned[target.name]=hashlib.sha256(data).hexdigest()
    return changes,owned


def install(package,home,account,resolution,dry_run=False):
    if steam_running(): raise RuntimeError('Close Steam fully, then run setup again. No Steam files were changed.')
    manifest=verified_payload(package)
    steam=next((p for p in [home/'.local/share/Steam',home/'.steam/steam'] if (p/'userdata').is_dir()),None)
    if steam is None: raise ValueError('Steam installation not found. Sign in to Steam once before setup.')
    profiles=[p for p in (steam/'userdata').iterdir() if p.name.isdigit() and p.name!='0' and (p/'config/localconfig.vdf').is_file()]
    profile=next((p for p in profiles if p.name==account),None) if account else (profiles[0] if len(profiles)==1 else None)
    if profile is None: raise ValueError('Select a Steam account with --account; found: '+', '.join(p.name for p in profiles))
    config=profile/'config'; short=config/'shortcuts.vdf'; local=config/'localconfig.vdf'
    old_short=short.read_bytes() if short.exists() else b'';old_local=local.read_bytes()
    base=home/'Applications/CRT-XR'; current=base/'current'
    if current.exists() and not current.is_symlink(): raise ValueError('The install/current path is not a managed link; nothing changed')
    exe='"'+str(current/'launch-steam.sh')+'"';start='"'+str(current)+'"'
    new_short,new_local,appid=configure(old_short,old_local.decode('utf-8'),exe,start,resolution)
    previous_art={}
    receipt_path=base/'install-receipt.json'
    if receipt_path.is_file():
        receipt=json.loads(receipt_path.read_text())
        if receipt.get('appid')==appid and receipt.get('account')==profile.name:previous_art=receipt.get('artwork',{})
    art_changes,art_owned=artwork_plan(package,config,appid,previous_art,manifest)
    if 'artwork/Icon.png' in manifest:
        tree=load_binary(new_short)
        for kind,entry in tree['shortcuts'][1].values():
            if kind!=0:continue
            if entry.get('appid')==integer(appid):
                managed_icon=str(current/'artwork/Icon.png')
                if entry.get('icon',(1,''))[1] in ['',managed_icon]:entry['icon']=(1,managed_icon)
        new_short=dump_binary(tree)
    result={'appid':appid,'account':profile.name,'resolution':resolution,'tracking':'Supported driver binary detected; tracking still needs its enabled service and connected glasses.' if (home/'.local/bin/xrDriver').is_file() and hashlib.sha256((home/'.local/bin/xrDriver').read_bytes()).hexdigest()==DRIVER_HASH else 'XR Gaming (Decky Loader) must be installed and enabled. Pro 2 needs its testing version and a supported driver. Fixed view remains available.'}
    if dry_run: return dict(result,dry_run=True)
    fingerprint=hashlib.sha256((package/'package-manifest.json').read_bytes()).hexdigest()[:12]
    release=base/'releases'/fingerprint;release.parent.mkdir(parents=True,exist_ok=True)
    if not release.exists():
        stage=Path(tempfile.mkdtemp(prefix='.staging-',dir=release.parent))
        try:
            for name in manifest:
                destination=stage/name;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(package/name,destination)
                if name.endswith('.sh') or name.endswith('.x86_64') or name in ['crt-xr-tracking-bridge','crt-xr-ipc-inventory']:destination.chmod(0o755)
            shutil.copy2(package/'package-manifest.json',stage/'package-manifest.json')
            verified_payload(stage)
            stage.rename(release)
        finally:
            if stage.exists(): shutil.rmtree(stage)
    else: verified_payload(release)
    backup_root=base/'install-backups';backup_root.mkdir(parents=True,exist_ok=True)
    backup=Path(tempfile.mkdtemp(prefix=time.strftime('%Y%m%d-%H%M%S')+'-',dir=backup_root))
    if old_short: (backup/'shortcuts.vdf').write_bytes(old_short)
    (backup/'localconfig.vdf').write_bytes(old_local)
    previous=os.readlink(current) if current.is_symlink() else None
    (backup/'receipt.json').write_text(json.dumps(dict(result,previous_release=previous,new_release=str(release)),indent=2))
    old_art={path:path.read_bytes() if path.exists() else None for path in art_changes}
    for path,data in old_art.items():
        if data is not None:
            (backup/'artwork').mkdir(exist_ok=True)
            (backup/'artwork'/path.name).write_bytes(data)
    # Recheck after copying; do not overwrite a client restarted during installation.
    if steam_running() or local.read_bytes()!=old_local or (short.read_bytes() if short.exists() else b'')!=old_short:
        raise RuntimeError('Steam configuration changed during setup. Close Steam and retry; configuration was not overwritten.')
    pending=base/'.current-install'
    if pending.exists() or pending.is_symlink(): raise ValueError('Incomplete install link exists; inspect .current-install before retrying')
    try:
        for path,data in art_changes.items():atomic(path,data)
        atomic(short,new_short);atomic(local,new_local.encode('utf-8'))
        pending.symlink_to(release,target_is_directory=True);os.replace(pending,current)
    except BaseException:
        if old_short: atomic(short,old_short)
        elif short.exists(): short.unlink()
        atomic(local,old_local)
        for path,data in old_art.items():
            if data is None:
                if path.exists():path.unlink()
            else:atomic(path,data)
        if pending.is_symlink(): pending.unlink()
        raise
    result.update(release=str(release),backup=str(backup),artwork=art_owned)
    atomic(base/'install-receipt.json',(json.dumps(result,indent=2)+'\n').encode())
    return result


def dialog(*args):
    return subprocess.run(['kdialog','--title','CRT XR setup',*args],text=True,capture_output=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package',type=Path,required=True)
    parser.add_argument('--home',type=Path,default=Path.home())
    parser.add_argument('--account',default='')
    parser.add_argument('--resolution',default='3840x1080',choices=['3840x1080','Native'])
    parser.add_argument('--dry-run',action='store_true')
    parser.add_argument('--gui',action='store_true')
    args=parser.parse_args()
    try:
        verified_payload(args.package.resolve())
        if args.gui:
            if not shutil.which('kdialog'): raise RuntimeError('Desktop setup needs kdialog. Run this from Steam Deck Desktop Mode.')
            selection=dialog('--radiolist','XR setup requires Decky Loader + XR Gaming already installed.\nPro 2 glasses currently need the testing version of XR Gaming.\n\nChoose your display setup.\nVITURE Full SBS uses the tested 3840 × 1080 game resolution.\nOther glasses need manual display setup in this beta.',
                             '3840x1080','VITURE Full SBS (Deck mono also supported)','on','Native','Deck / monitor only','off')
            if selection.returncode:return 0
            args.resolution=selection.stdout.strip()
            if args.resolution not in ['3840x1080','Native']:raise ValueError('No display profile selected')
            steam=next((p for p in [args.home/'.local/share/Steam',args.home/'.steam/steam'] if (p/'userdata').is_dir()),None)
            profiles=[] if steam is None else [p for p in (steam/'userdata').iterdir() if p.name.isdigit() and p.name!='0' and (p/'config/localconfig.vdf').is_file()]
            if len(profiles)>1 and not args.account:
                selected=dialog('--menu','Choose the Steam account to install for:',*[value for p in profiles for value in [p.name,'Steam account '+p.name]])
                if selected.returncode:return 0
                args.account=selected.stdout.strip()
            if steam_running() and not args.dry_run:
                if dialog('--yesno','Steam must close to safely add CRT XR.\nFinish any running game first. Close Steam and continue?').returncode:return 0
                subprocess.run(['steam','-shutdown'],timeout=15,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                deadline=time.monotonic()+45
                while steam_running() and time.monotonic()<deadline:time.sleep(.5)
        result=install(args.package.resolve(),args.home.resolve(),args.account,args.resolution,args.dry_run)
        print(json.dumps(result,indent=2))
        if args.gui and not args.dry_run:
            dialog('--msgbox','CRT XR is installed.\n\n'+result['tracking']+'\n\nRestart Steam, then Return to Gaming Mode. Find CRT XR under Non-Steam.\nWith glasses: start in mono, press A at the prompt, then switch SBS.\nWithout glasses: launch normally.\n\nYour ROMs, settings and saves were not moved.')
            subprocess.Popen(['steam'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
        return 0
    except Exception as error:
        message='Setup could not finish: '+str(error)
        if args.gui and shutil.which('kdialog'):dialog('--error',message)
        print(message,file=sys.stderr)
        return 1


if __name__=='__main__':sys.exit(main())
