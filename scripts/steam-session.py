#!/usr/bin/env python3
"""Steam entry point: normal gamepad input, with separate KDE/Gamescope paths."""
import argparse
import os
from pathlib import Path
import sys


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
            "--resolution", "1280x720" if glasses else "1280x800",
            "--log-file", str(state / "godot-steam.log"), "--",
            *(["--sbs-session-manual"] if glasses else []), *app_args]


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
    # The prompt now lives inside the game window. Do not launch/close a
    # separate Godot process between the physical switch and the first frame.
    if "--rom" not in app_args:
        app_args.append("--last-game")
    command = launch_command(here, os.environ, glasses, app_args)
    print("RetroCRT: Steam launch / " + ("Gaming Mode" if gaming_mode(os.environ) else "Desktop Mode")
          + " / " + ("Full SBS" if glasses else "mono"), flush=True)
    os.chdir(here)
    os.execvpe(command[0], command, dict(os.environ))


if __name__ == "__main__":
    main()
