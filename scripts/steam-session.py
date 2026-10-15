#!/usr/bin/env python3
"""Steam entry point: normal gamepad input, with separate KDE/Gamescope paths."""
import argparse
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import time


def gaming_mode(env):
    return any("gamescope" in env.get(key, "").lower() for key in
               ("XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "DESKTOP_SESSION")) or bool(
                   env.get("GAMESCOPE_WAYLAND_DISPLAY"))


def glasses_connected(drm=Path("/sys/class/drm")):
    for edid in drm.glob("card*-*/edid"):
        try:
            if edid.with_name("status").read_text().strip() == "connected" and b"viture" in edid.read_bytes().lower():
                return True
        except OSError:
            pass
    return False


def launch_command(here, env, glasses, app_args):
    if glasses and not gaming_mode(env):
        # Steam still owns the controller layout; KDE owns the desktop monitors.
        return [sys.executable, str(here / "glasses-session.py"), "--manual-sbs", *app_args]
    state = Path(env.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "retrocrt"
    # Gaming Mode owns output selection. Never invoke KScreen or nest Gamescope.
    display = ["--display-driver", "x11"]
    return [str(here / "retrocrt.x86_64"), *display,
            "--rendering-method", "gl_compatibility", "--fullscreen",
            "--resolution", "3840x1080" if glasses else "1280x800",
            "--log-file", str(state / "godot-steam.log"), "--",
            *(["--full-sbs"] if glasses else []), *app_args]


def wait_for_sbs(process, ready, timeout=90, clock=time.monotonic, sleep=time.sleep):
    deadline = clock() + timeout
    while process.poll() is None and clock() < deadline:
        if ready():
            return True
        sleep(0.4)
    return False


def show_sbs_prompt(here, env):
    gaming = gaming_mode(env)
    log = Path(env.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "retrocrt/sbs-prompt.log"
    command = [str(here / "retrocrt.x86_64"), "--display-driver", "x11",
               "--rendering-method", "gl_compatibility", "--fullscreen",
               "--resolution", "1280x720", "--log-file", str(log), "--", "--sbs-prompt"]
    if gaming:
        command.append("--sbs-prompt-manual")
    process = subprocess.Popen(command, cwd=here, env=dict(env))
    try:
        if gaming:
            return process.wait() == 10
        spec = importlib.util.spec_from_file_location("retrocrt_displays", here / "glasses-session.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        screens = module.Screens()

        def ready():
            try:
                target = module.select_output(screens.read())
                return module.sbs_mode(target) is not None
            except (RuntimeError, OSError, ValueError, subprocess.SubprocessError):
                return False

        # Keep the recovery instructions visible until SBS appears or the user
        # cancels. A slow reconnect must not silently dismiss the prompt.
        while process.poll() is None:
            if wait_for_sbs(process, ready):
                return True
        return False
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--mono", action="store_true", help="Use the Deck display without SBS")
    modes.add_argument("--glasses", action="store_true", help="Use glasses already switched to Full SBS")
    args, app_args = parser.parse_known_args()
    here = Path(__file__).resolve().parent
    state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "retrocrt"
    state.mkdir(parents=True, exist_ok=True)
    glasses = args.glasses or (not args.mono and glasses_connected())
    if glasses:
        if not show_sbs_prompt(here, os.environ):
            print("RetroCRT: glasses setup cancelled or timed out; game not started.", flush=True)
            return
    if "--rom" not in app_args:
        app_args.append("--last-game")
    command = launch_command(here, os.environ, glasses, app_args)
    print("RetroCRT: Steam launch / " + ("Gaming Mode" if gaming_mode(os.environ) else "Desktop Mode")
          + " / " + ("Full SBS" if glasses else "mono"), flush=True)
    os.chdir(here)
    os.execvpe(command[0], command, dict(os.environ))


if __name__ == "__main__":
    main()
