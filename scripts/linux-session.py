#!/usr/bin/env python3
"""Standalone Linux launcher; Steam and desktop display changes are optional."""
import argparse
import importlib.util
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def managed_desktop(env):
    desktop = env.get('XDG_CURRENT_DESKTOP', '').lower().split(':')
    return 'kde' in desktop and bool(shutil.which('kscreen-doctor'))


def launch_command(here, env, glasses=False, manual=False, screen=None, app_args=()):
    state = Path(env.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'crt_xr'
    if glasses and not manual and screen is None and managed_desktop(env):
        # KScreen changes/restores only this session's display layout.
        return [sys.executable, str(here / 'glasses-session.py'), '--auto-sbs', *app_args]
    command = [str(here / 'crt-xr.x86_64'), '--rendering-method', 'gl_compatibility', '--fullscreen',
               '--log-file', str(state / 'godot-linux.log')]
    if screen is not None:
        command += ['--screen', str(screen)]
    # Let Godot choose its display backend and the display's native dimensions.
    # Manual SBS deliberately does not invoke KScreen, xrandr or Gamescope.
    return command + ['--', *(['--sbs'] if glasses else ['--simulate']), *app_args]


def run_child(command, here, env):
    child = None
    previous = {}
    def interrupted(number, _frame):
        raise SystemExit(128 + number)
    try:
        for number in (signal.SIGTERM, signal.SIGINT):
            previous[number] = signal.signal(number, interrupted)
        child = subprocess.Popen(command, cwd=here, env=env)
        return child.wait()
    finally:
        for number, handler in previous.items():
            signal.signal(number, handler)
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--glasses', action='store_true', help='Use KDE display setup when available; otherwise use manually configured SBS')
    modes.add_argument('--manual-sbs', action='store_true', help='Glasses already in SBS with the target display configured')
    modes.add_argument('--mono', action='store_true', help='Ordinary desktop play (the default)')
    parser.add_argument('--screen', type=int, help='Godot display index for manually configured output (starting at 0)')
    args, app_args = parser.parse_known_args(argv)
    if args.screen is not None and args.screen < 0:
        parser.error('--screen must be zero or greater')
    if app_args[:1] == ['--']:
        app_args = app_args[1:]
    here = Path(__file__).resolve().parent
    env = dict(os.environ)
    state = Path(env.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'crt_xr'
    state.mkdir(parents=True, exist_ok=True)
    module(here / 'installer/runtime_check.py', 'crt_xr_runtime_check').check_runtime(here)
    glasses = args.glasses or args.manual_sbs
    command = launch_command(here, env, glasses, args.manual_sbs, args.screen, app_args)
    if not glasses:
        return run_child(command, here, env)
    if args.manual_sbs or args.screen is not None or not managed_desktop(env):
        print('CRT XR: manual SBS — switch the glasses to SBS and select their display in your desktop settings. No display layout will be changed.', flush=True)
    config = Path(env.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'xr_driver/config.ini'
    tracking = module(here / 'tracking-session.py', 'crt_xr_tracking_session')
    # Includes both desktop paths; the lease restores driver settings even if
    # the game crashes or the launcher receives SIGINT/SIGTERM.
    with tracking.TrackingSession(config, state):
        return run_child(command, here, env)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        message = 'CRT XR could not start: ' + str(error)
        print(message, file=sys.stderr)
        try:
            state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'crt_xr'
            state.mkdir(parents=True, exist_ok=True)
            (state / 'launcher-error.log').write_text(message + '\n', encoding='utf-8')
        except OSError:
            pass  # Keep the original startup failure visible even if logging fails.
        if shutil.which('kdialog'):
            subprocess.run(['kdialog', '--error', message], check=False)
        elif shutil.which('zenity'):
            subprocess.run(['zenity', '--error', '--text', message], check=False)
        sys.exit(1)
