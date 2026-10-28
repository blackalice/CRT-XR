import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/installer'))
import install as setup
import runtime_check

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

launcher = load('linux_session_tested', ROOT / 'scripts/linux-session.py')
tracking = load('desktop_tracking_tested', ROOT / 'scripts/tracking-session.py')


@unittest.skipIf(os.name == 'nt', 'Installer transactions use Linux symlinks')
class DesktopInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / 'build')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home with spaces % $'
        self.package = self.root / 'package'
        self.data = self.home / 'custom-data'
        for name in ['crt-xr.x86_64', 'crt-xr-engine.x86_64', 'crt-xr.pck', 'launch-steam.sh',
                     'steam-session.py', 'display-probe.py', 'launch-linux.sh', 'linux-session.py',
                     'tracking-session.py', 'installer/runtime_check.py', 'artwork/Icon.png']:
            path = self.package / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('payload ' + name)
        self.manifest()
        self.runtime = patch.object(runtime_check, 'check_runtime', return_value={'architecture': 'x86_64', 'glibc': '2.39'})
        self.runtime.start(); self.addCleanup(self.runtime.stop)
        self.running = patch.object(setup, 'application_running', return_value=False)
        self.running.start(); self.addCleanup(self.running.stop)

    def manifest(self):
        import hashlib
        (self.package / 'package-manifest.json').write_text(json.dumps({p.relative_to(self.package).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in self.package.rglob('*') if p.is_file() and p.name != 'package-manifest.json'}))

    def install(self, dry=False):
        return setup.install_desktop(self.package, self.home, dry_run=dry, data_home=self.data)

    def test_installs_without_steam_and_while_steam_is_running(self):
        with patch.object(setup, 'steam_running', return_value=True): result = self.install()
        current = self.home / 'Applications/CRT-XR/current'
        self.assertEqual(current.resolve(), Path(result['release']))
        self.assertTrue((current / 'launch-linux.sh').stat().st_mode & 0o111)
        entry = Path(result['shortcut']).read_text()
        self.assertIn('launch-linux.sh', entry)
        self.assertIn('%%', entry)
        self.assertIn('Actions=Glasses;', entry)
        self.assertFalse((self.home / '.local/share/Steam').exists())

    def test_updates_preserve_user_files_steam_and_previous_release(self):
        steam = self.home / '.local/share/Steam/userdata/123/config/shortcuts.vdf'
        steam.parent.mkdir(parents=True); steam.write_bytes(b'existing Steam shortcut')
        save = self.data / 'godot/app_userdata/CRT XR/saves/game.srm'
        save.parent.mkdir(parents=True); save.write_bytes(b'progress')
        base = self.home / 'Applications/CRT-XR'
        base.mkdir(parents=True)
        (base / 'install-receipt.json').write_text('{"account":"123","appid":42}')
        first = self.install()
        (self.package / 'crt-xr.pck').write_text('new package'); self.manifest()
        second = self.install()
        self.assertNotEqual(first['release'], second['release'])
        self.assertTrue(Path(first['release']).is_dir())
        self.assertEqual(save.read_bytes(), b'progress')
        self.assertEqual(steam.read_bytes(), b'existing Steam shortcut')
        self.assertEqual(json.loads((base / 'install-receipt.json').read_text())['appid'], 42)

    def test_menu_launch_with_special_characters_uses_real_glib_parser(self):
        try:
            from gi.repository import Gio
        except ImportError:
            self.skipTest('System GLib Python bindings unavailable')
        script = self.package / 'launch-linux.sh'
        script.write_text('#!/bin/sh\nprintf menu-ok > "$HOME/menu-result"\n')
        self.manifest()
        result = self.install()
        app = Gio.DesktopAppInfo.new_from_filename(result['shortcut'])
        context = Gio.AppLaunchContext()
        context.setenv('HOME', str(self.home))
        self.assertTrue(app.launch([], context))
        import time
        for _ in range(50):
            if (self.home / 'menu-result').exists(): break
            time.sleep(0.1)
        self.assertEqual((self.home / 'menu-result').read_text(), 'menu-ok')

    def test_failed_update_rolls_back_shortcut_receipt_and_active_link(self):
        first = self.install()
        shortcut = Path(first['shortcut'])
        receipt = self.home / 'Applications/CRT-XR/desktop-install-receipt.json'
        before = (shortcut.read_bytes(), receipt.read_bytes())
        (self.package / 'crt-xr.pck').write_text('new package'); self.manifest()
        real_atomic = setup.atomic
        failed = False
        def failing(path, data):
            nonlocal failed
            if path == receipt and not failed:
                failed = True
                raise OSError('simulated write failure')
            real_atomic(path, data)
        with patch.object(setup, 'atomic', side_effect=failing):
            with self.assertRaises(OSError): self.install()
        self.assertEqual(before, (shortcut.read_bytes(), receipt.read_bytes()))
        self.assertEqual((self.home / 'Applications/CRT-XR/current').resolve(), Path(first['release']))
        self.assertFalse((self.home / 'Applications/CRT-XR/.current-install').is_symlink())

    def test_dry_run_and_runtime_failure_leave_no_install(self):
        self.install(dry=True)
        self.assertFalse((self.home / 'Applications').exists())
        with patch.object(runtime_check, 'check_runtime', side_effect=RuntimeError('old runtime')):
            with self.assertRaisesRegex(RuntimeError, 'old runtime'): self.install()
        self.assertFalse((self.home / 'Applications').exists())

    def test_running_app_and_unsafe_manifest_are_rejected(self):
        with patch.object(setup, 'application_running', return_value=True):
            with self.assertRaisesRegex(RuntimeError, 'Close CRT XR'): self.install()
        (self.package / 'package-manifest.json').write_text(json.dumps({str((self.package / 'crt-xr.pck').resolve()): 'unused'}))
        with self.assertRaisesRegex(ValueError, 'Unsafe package path'): self.install()


class LinuxRuntimeTests(unittest.TestCase):
    def test_arm_and_old_glibc_fail_before_loading_libraries(self):
        with patch.object(runtime_check.platform, 'system', return_value='Linux'), patch.object(runtime_check.platform, 'machine', return_value='aarch64'):
            with self.assertRaisesRegex(RuntimeError, 'x86-64'): runtime_check.check_runtime(ROOT)
        with patch.object(runtime_check.platform, 'system', return_value='Linux'), patch.object(runtime_check.platform, 'machine', return_value='x86_64'), patch.object(runtime_check.platform, 'libc_ver', return_value=('glibc', '2.35')):
            with self.assertRaisesRegex(RuntimeError, 'glibc 2.38'): runtime_check.check_runtime(ROOT)

    def test_missing_cpp_runtime_is_actionable(self):
        with patch.object(runtime_check.platform, 'system', return_value='Linux'), patch.object(runtime_check.platform, 'machine', return_value='x86_64'), patch.object(runtime_check.platform, 'libc_ver', return_value=('glibc', '2.39')), patch.object(runtime_check.shutil, 'which', return_value='/usr/bin/ldd'), patch.object(runtime_check.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', "version `GLIBCXX_3.4.32' not found")):
            with self.assertRaisesRegex(RuntimeError, 'GLIBCXX_3.4.32'): runtime_check.check_runtime(ROOT)


class DesktopLauncherTests(unittest.TestCase):
    def test_monitor_and_manual_sbs_do_not_change_display_layout(self):
        here = Path('/installed CRT XR')
        with patch.object(launcher, 'managed_desktop', return_value=False):
            mono = launcher.launch_command(here, {}, app_args=['--last-game'])
            sbs = launcher.launch_command(here, {}, glasses=True, screen=1)
        self.assertIn('--simulate', mono)
        self.assertNotIn('--sbs', mono)
        self.assertIn('--sbs', sbs)
        self.assertIn('--screen', sbs)
        self.assertNotIn('--display-driver', mono)
        self.assertFalse(any('glasses-session' in value for value in sbs))

    def test_kde_uses_managed_display_unless_manual_or_explicit_screen(self):
        with patch.object(launcher, 'managed_desktop', return_value=True):
            command = launcher.launch_command(Path('/app'), {}, glasses=True)
            manual = launcher.launch_command(Path('/app'), {}, glasses=True, manual=True)
        self.assertIn(str(Path('/app') / 'glasses-session.py'), command)
        self.assertIn('--auto-sbs', command)
        self.assertIn('--sbs', manual)

    def test_driver_restored_after_manual_glasses_child_crashes(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'build') as temp:
            root = Path(temp)
            config = root / 'config/xr_driver/config.ini'
            config.parent.mkdir(parents=True)
            original = 'disabled=true\noutput_mode=mouse\nexternal_mode=breezy_desktop\n'
            config.write_text(original)
            def modules(path, name):
                if 'runtime_check' in name:
                    from types import SimpleNamespace
                    return SimpleNamespace(check_runtime=lambda _: None)
                return tracking
            def crash(*_):
                text = config.read_text()
                self.assertIn('external_mode=none', text)
                self.assertIn('output_mode=external_only', text)
                raise RuntimeError('simulated core crash')
            with patch.dict(os.environ, {'XDG_STATE_HOME':str(root/'state'), 'XDG_CONFIG_HOME':str(root/'config')}), patch.object(launcher, 'module', side_effect=modules), patch.object(launcher, 'run_child', side_effect=crash):
                with self.assertRaisesRegex(RuntimeError, 'simulated core crash'): launcher.main(['--manual-sbs'])
            self.assertEqual(config.read_text(), original)
            self.assertFalse((root/'state/crt_xr/tracking-only.json').exists())

    def test_signal_stops_child_before_restoring_session(self):
        from unittest.mock import Mock
        child = Mock()
        child.wait.side_effect = [SystemExit(143), 0]
        child.poll.return_value = None
        with patch.object(launcher.subprocess, 'Popen', return_value=child):
            with self.assertRaises(SystemExit): launcher.run_child(['/app'], Path('/'), {})
        child.terminate.assert_called_once()


class InstallerDialogTests(unittest.TestCase):
    def test_zenity_can_select_the_existing_steam_display_profile(self):
        with patch.object(setup.shutil, 'which', side_effect=lambda value: '/usr/bin/zenity' if value == 'zenity' else None), patch.object(setup.subprocess, 'run') as run:
            setup.dialog('--radiolist', 'Choose', '3840x1080', 'Glasses', 'on', 'Native', 'Monitor', 'off')
        command = run.call_args.args[0]
        self.assertEqual(command[0], 'zenity')
        self.assertEqual(command[-6:], ['TRUE','3840x1080','Glasses','FALSE','Native','Monitor'])


if __name__ == '__main__': unittest.main()
