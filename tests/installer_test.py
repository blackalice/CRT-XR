import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/installer'))
import steam_config as kv
import install as setup


class SteamConfigTests(unittest.TestCase):
    def test_binary_roundtrip_and_preserve_other_game(self):
        original={'shortcuts':(0,{'0':(0,{'appname':(1,'Other game'),'appid':kv.integer(17),'tags':(0,{'0':(1,'Favourite')})})})}
        data=kv.dump_binary(original)
        self.assertEqual(kv.dump_binary(kv.load_binary(data)),data)
        short,local,appid=setup.configure(data,'"UserLocalConfigStore" { "keep" "yes" }','"/home/deck/CRT XR/launch-steam.sh"','"/home/deck/CRT XR"','3840x1080')
        parsed=kv.load_binary(short)['shortcuts'][1]
        self.assertEqual(parsed['0'],original['shortcuts'][1]['0'])
        self.assertEqual(kv.load_text(local)['UserLocalConfigStore']['keep'],'yes')
        self.assertEqual(kv.branch(kv.load_text(local),['UserLocalConfigStore','Software','Valve','Steam','apps',str(appid)])['ResolutionOverride2'],'3840x1080')

    def test_update_retains_appid_tags_and_launch_options(self):
        original={'shortcuts':(0,{'0':(0,{'appname':(1,'CRT XR'),'appid':kv.integer(123),'LaunchOptions':(1,'--mono'),'tags':(0,{'0':(1,'Custom')})})})}
        short,_,appid=setup.configure(kv.dump_binary(original),'"UserLocalConfigStore" {}','"/new"','"/newdir"','Native')
        self.assertEqual(appid,123)
        entry=kv.load_binary(short)['shortcuts'][1]['0'][1]
        self.assertEqual(entry['LaunchOptions'][1],'--mono')
        self.assertEqual(entry['tags'][1]['0'][1],'Custom')
        self.assertEqual(entry['exe'][1],'"/new"')

    def test_text_roundtrip_preserves_escaped_and_unrelated_values(self):
        tree={'UserLocalConfigStore':{'path':'C:\\Games\\A "quoted" game','nested':{'setting':'a\nb'}}}
        self.assertEqual(kv.load_text(kv.dump_text(tree)),tree)

    def test_unknown_or_malformed_formats_fail(self):
        for raw in [b'\x00shortcuts\0',b'\x09x\0\x08',b'\x08junk']:
            with self.assertRaises(ValueError):kv.load_binary(raw)
        for raw in ['"root" {','"root" "a" "root" "b"','"root" { unquoted "value" }']:
            with self.assertRaises(ValueError):kv.load_text(raw)


@unittest.skipIf(os.name=='nt','Install transaction uses Linux symlinks; run in WSL too')
class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(dir=ROOT/'build');self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.home=self.root/'home';self.package=self.root/'package';self.package.mkdir()
        for name in ['crt-xr.x86_64','crt-xr-engine.x86_64','crt-xr.pck','launch-steam.sh','steam-session.py','display-probe.py']:
            (self.package/name).write_text('payload '+name)
        self.write_manifest()
        self.config=self.home/'.local/share/Steam/userdata/123/config';self.config.mkdir(parents=True)
        (self.config/'localconfig.vdf').write_text('"UserLocalConfigStore" { "Existing" "kept" }')
        self.running=patch.object(setup,'steam_running',return_value=False);self.running.start();self.addCleanup(self.running.stop)

    def write_manifest(self):
        (self.package/'package-manifest.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in self.package.iterdir() if p.name!='package-manifest.json'}))

    def test_install_update_keeps_saves_and_previous_release(self):
        saves=self.home/'.local/share/godot/app_userdata/CRT XR/saves';saves.mkdir(parents=True);(saves/'game.srm').write_bytes(b'save')
        first=setup.install(self.package,self.home,'','3840x1080')
        self.assertTrue((self.home/'Applications/CRT-XR/current').is_symlink())
        self.assertEqual((saves/'game.srm').read_bytes(),b'save')
        self.assertTrue(Path(first['backup'],'localconfig.vdf').is_file())
        (self.package/'crt-xr.pck').write_text('new version');self.write_manifest()
        # Ensure unique backup timestamp in this synthetic fast update.
        with patch.object(setup.time,'strftime',return_value='update'):
            second=setup.install(self.package,self.home,'','3840x1080')
        self.assertEqual(first['appid'],second['appid']);self.assertNotEqual(first['release'],second['release'])
        self.assertTrue(Path(first['release']).is_dir())

    def test_dry_run_and_running_steam_do_not_mutate(self):
        before=(self.config/'localconfig.vdf').read_bytes()
        setup.install(self.package,self.home,'','Native',True)
        self.assertFalse((self.home/'Applications').exists())
        with patch.object(setup,'steam_running',return_value=True):
            with self.assertRaises(RuntimeError):setup.install(self.package,self.home,'','Native')
        self.assertEqual((self.config/'localconfig.vdf').read_bytes(),before)

    def test_corrupt_and_traversal_payloads_rejected_before_install(self):
        (self.package/'crt-xr.pck').write_text('corrupt')
        with self.assertRaises(ValueError):setup.install(self.package,self.home,'','Native')
        (self.package/'package-manifest.json').write_text(json.dumps({'../secret':'abc'}))
        with self.assertRaises(ValueError):setup.install(self.package,self.home,'','Native')
        self.assertFalse((self.home/'Applications').exists())

    def test_config_commit_failure_restores_original_bytes(self):
        before=(self.config/'localconfig.vdf').read_bytes();real_atomic=setup.atomic;failed=False
        def fail_once(path,data):
            nonlocal failed
            if path.name=='localconfig.vdf' and not failed:failed=True;raise OSError('Simulated disk failure')
            real_atomic(path,data)
        with patch.object(setup,'atomic',side_effect=fail_once):
            with self.assertRaises(OSError):setup.install(self.package,self.home,'','Native')
        self.assertEqual((self.config/'localconfig.vdf').read_bytes(),before)
        self.assertFalse((self.config/'shortcuts.vdf').exists())
        self.assertFalse((self.home/'Applications/CRT-XR/current').exists())

    def add_artwork(self):
        folder=self.package/'artwork';folder.mkdir()
        for name in ['Portrait','Landscape','Hero','Logo','Icon']:(folder/(name+'.png')).write_bytes(('image '+name).encode())
        manifest={p.relative_to(self.package).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in self.package.rglob('*') if p.is_file() and p.name!='package-manifest.json'}
        (self.package/'package-manifest.json').write_text(json.dumps(manifest))

    def test_artwork_install_and_customisation_preservation(self):
        self.add_artwork()
        first=setup.install(self.package,self.home,'','3840x1080');appid=first['appid'];grid=self.config/'grid'
        self.assertEqual((grid/(str(appid)+'p.png')).read_bytes(),b'image Portrait')
        self.assertTrue((grid/(str(appid)+'_hero.png')).is_file())
        tree=kv.load_binary((self.config/'shortcuts.vdf').read_bytes())
        self.assertTrue(tree['shortcuts'][1]['0'][1]['icon'][1].endswith('/current/artwork/Icon.png'))
        (grid/(str(appid)+'p.png')).write_bytes(b'my custom cover')
        (self.package/'artwork/Hero.png').write_bytes(b'updated Hero')
        manifest=json.loads((self.package/'package-manifest.json').read_text());manifest['artwork/Hero.png']=hashlib.sha256(b'updated Hero').hexdigest()
        (self.package/'package-manifest.json').write_text(json.dumps(manifest))
        setup.install(self.package,self.home,'','3840x1080')
        self.assertEqual((grid/(str(appid)+'p.png')).read_bytes(),b'my custom cover')
        self.assertEqual((grid/(str(appid)+'_hero.png')).read_bytes(),b'updated Hero')

    def test_existing_jpeg_artwork_is_preserved(self):
        self.add_artwork()
        # Use a dry-run to discover the generated shortcut ID without mutation.
        appid=setup.install(self.package,self.home,'','Native',True)['appid']
        grid=self.config/'grid';grid.mkdir();(grid/(str(appid)+'p.jpg')).write_bytes(b'custom jpeg')
        setup.install(self.package,self.home,'','Native')
        self.assertFalse((grid/(str(appid)+'p.png')).exists())
        self.assertEqual((grid/(str(appid)+'p.jpg')).read_bytes(),b'custom jpeg')

    def test_artwork_is_rolled_back_with_failed_configuration(self):
        self.add_artwork();real_atomic=setup.atomic;failed=False
        def fail_once(path,data):
            nonlocal failed
            if path.name=='localconfig.vdf' and not failed:failed=True;raise OSError('Simulated failure after artwork writes')
            real_atomic(path,data)
        with patch.object(setup,'atomic',side_effect=fail_once):
            with self.assertRaises(OSError):setup.install(self.package,self.home,'','Native')
        self.assertEqual(list((self.config/'grid').glob('*.png')),[])

    def test_multiple_accounts_require_choice(self):
        other=self.config.parents[1]/'456/config';other.mkdir(parents=True);(other/'localconfig.vdf').write_text('"UserLocalConfigStore" {}')
        with self.assertRaises(ValueError):setup.install(self.package,self.home,'','Native')


if __name__=='__main__':unittest.main()
