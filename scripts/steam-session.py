#!/usr/bin/env python3
"""Steam entry point: normal gamepad input, with separate KDE/Gamescope paths."""
import argparse
import os
from pathlib import Path
import sys
import subprocess
import signal
import tempfile
import threading
import json


def gaming_mode(env):
    return any("gamescope" in env.get(key, "").lower() for key in
               ("XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "DESKTOP_SESSION")) or bool(
                   env.get("GAMESCOPE_WAYLAND_DISPLAY"))


def glasses_connected(drm=Path("/sys/class/drm")):
    import importlib.util
    # The glasses names live in display-probe.py, shipped beside this script.
    spec = importlib.util.spec_from_file_location("display_probe", Path(__file__).with_name("display-probe.py"))
    probe = importlib.util.module_from_spec(spec); spec.loader.exec_module(probe)
    for edid in drm.glob("card*-*/edid"):
        try:
            if edid.with_name("status").read_text().strip() == "connected" and probe.is_glasses_edid(edid.read_bytes()):
                return True
        except OSError:
            pass
    return False


def sbs_driver(here):
    """The XR driver adapter when the driver can switch these glasses itself, else None."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("crt_xr_driver_sbs", here / "driver-sbs.py")
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    driver = module.load()
    return driver if driver is not None and driver.supported() else None


class AutoSBS:
    """Switches the glasses to SBS for this session and back to 2D afterwards,
    through the XR driver, as its own SBS toggle does. Only for glasses the
    driver says it can switch; others use their button. The app reads `status`
    ({"state": "switching" | "on" | "failed"}) to choose its instructions."""
    def __init__(self, driver, status):
        self.driver = driver
        self.status = Path(status)
        self.before = None  # SBS state before this session, once read
        self.thread = threading.Thread(target=self._switch, daemon=True)

    def _write(self, state, detail=""):
        pending = self.status.with_suffix(".tmp")
        pending.write_text(json.dumps({"state": state, "detail": detail}), encoding="utf-8")
        os.replace(pending, self.status)

    def start(self):
        self._write("switching")
        self.thread.start()

    def _switch(self):
        try:
            self.before = self.driver.enabled()
            if not self.before:
                self.driver.set_enabled(True)  # waits for the driver to confirm
            self._write("on")
        except (RuntimeError, OSError, ValueError) as error:
            self._write("failed", str(error))
            print("CRT XR: automatic SBS unavailable: " + str(error), flush=True)

    def restore(self):
        """Back to 2D after the session, only if the glasses were in 2D before it."""
        self.thread.join(timeout=15)
        if self.before is not False:
            return
        try:
            self.driver.set_enabled(False)
        except (RuntimeError, OSError, ValueError) as error:
            print("CRT XR: could not return the glasses to 2D: " + str(error), flush=True)


def launch_command(here, env, glasses, app_args, auto_sbs=False):
    if glasses and not gaming_mode(env):
        # Steam still owns the controller layout; KDE owns the desktop monitors.
        return [sys.executable, str(here / "glasses-session.py"), "--auto-sbs" if auto_sbs else "--manual-sbs", *app_args]
    state = Path(env.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "crt_xr"
    # Gaming Mode owns output selection. Never invoke KScreen or nest Gamescope.
    display = ["--display-driver", "x11"]
    return [str(here / "crt-xr.x86_64"), *display,
            "--rendering-method", "gl_compatibility",
            *( ["--windowed"] if gaming_mode(env) and not glasses else ["--fullscreen"] ),
            "--resolution", "1280x720" if glasses else "1280x800",
            "--log-file", str(state / "godot-steam.log"), "--",
            *(["--sbs-session-manual"] if glasses else (["--deck-mono"] if gaming_mode(env) else [])), *app_args]


def tracking_session(state):
    import importlib.util
    spec = importlib.util.spec_from_file_location("tracking_session", Path(__file__).with_name("tracking-session.py"))
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home()/".config"))) / "xr_driver/config.ini"
    return module.TrackingSession(config, state)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--mono", action="store_true", help="Use the Deck display without SBS")
    modes.add_argument("--glasses", action="store_true", help="Use glasses already switched to Full SBS")
    parser.add_argument("--sbs-probe", action="store_true", help="Experimental read-only SBS handoff diagnostics")
    parser.add_argument("--sbs-resolution", default="3840x1080", help="Expected full SBS size for this display profile")
    parser.add_argument("--xr-connector", default="", help="Explicit DRM connector for an unidentified XR display")
    args, app_args = parser.parse_known_args()
    if args.sbs_probe or gaming_mode(os.environ):
        import importlib.util
        spec = importlib.util.spec_from_file_location("display_probe", Path(__file__).with_name("display-probe.py"))
        probe = importlib.util.module_from_spec(spec); spec.loader.exec_module(probe)
        try: probe.dimensions(args.sbs_resolution)
        except ValueError as error: parser.error(str(error))
        if args.sbs_probe and not gaming_mode(os.environ): parser.error("--sbs-probe is for Gaming Mode; use the existing Desktop launcher there")
    here = Path(__file__).resolve().parent
    state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "crt_xr"
    state.mkdir(parents=True, exist_ok=True)
    glasses = args.glasses or (not args.mono and glasses_connected())
    # The prompt now lives inside the game window. Do not launch/close a
    # separate Godot process between the physical switch and the first frame.
    if "--rom" not in app_args:
        app_args.append("--last-game")
    driver = sbs_driver(here) if glasses and not args.glasses else None
    command = launch_command(here, os.environ, glasses, app_args, auto_sbs=driver is not None)
    print("CRT XR: Steam launch / " + ("Gaming Mode" if gaming_mode(os.environ) else "Desktop Mode")
          + " / " + ("Full SBS" if glasses else "mono")
          + (" / automatic SBS" if driver is not None else ""), flush=True)
    os.chdir(here)
    if not (gaming_mode(os.environ) and glasses):
        os.execvpe(command[0], command, dict(os.environ))
        return
    # Unique files prevent a previous launch from authorising this handoff.
    run = Path(tempfile.mkdtemp(prefix="display-probe-", dir=state))
    env = dict(os.environ, CRT_XR_DISPLAY_PROBE=str(run / "display.json"), CRT_XR_SBS_SIZE=args.sbs_resolution)
    auto = AutoSBS(driver, run / "auto-sbs.json") if driver is not None else None
    if auto is not None: env["CRT_XR_AUTO_SBS"] = str(auto.status)
    with tracking_session(state):
        watcher = subprocess.Popen([sys.executable, str(here / "display-probe.py"), "--output", env["CRT_XR_DISPLAY_PROBE"],
                                    "--size", args.sbs_resolution, "--connector", args.xr_connector])
        child = None
        old_handler = signal.signal(signal.SIGTERM, lambda number, frame: sys.exit(128+number))
        try:
            if auto is not None: auto.start()  # while the setup screen shows
            child = subprocess.Popen(command, env=env)
            return child.wait()
        finally:
            signal.signal(signal.SIGTERM, old_handler)
            if child is not None and child.poll() is None:
                child.terminate()
                try: child.wait(timeout=3)
                except subprocess.TimeoutExpired: child.kill(); child.wait()
            if auto is not None: auto.restore()
            watcher.terminate()
            try: watcher.wait(timeout=3)
            except subprocess.TimeoutExpired: watcher.kill(); watcher.wait()



if __name__ == "__main__":
    sys.exit(main())
