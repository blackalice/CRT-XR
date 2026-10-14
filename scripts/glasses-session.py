#!/usr/bin/env python3
"""Temporary KDE display layout for RetroCRT; Python standard library only."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time


def internal(output):
    return output["name"].startswith(("eDP", "LVDS", "DSI"))


def mode_size(mode):
    size = mode.get("size", {})
    return size.get("width"), size.get("height")


def sbs_mode(output):
    modes = [m for m in output.get("modes", []) if mode_size(m) == (3840, 1080)
             and 59 <= float(m.get("refreshRate", 0)) <= 121]
    # Prefer 60 Hz for the initial hardware validation, then the nearest supported rate.
    return min(modes, key=lambda m: abs(float(m["refreshRate"]) - 60)) if modes else None


def is_viture(name):
    # KScreen JSON omits EDID. Read only the kernel's existing EDID descriptors.
    for path in Path("/sys/class/drm").glob("card*-*/edid"):
        if path.parent.name.endswith("-" + name):
            try:
                if b"viture" in path.read_bytes().lower():
                    return True
            except OSError:
                pass
    return False


def select_output(config, explicit=None, identify=is_viture):
    candidates = [o for o in config["outputs"] if o.get("connected") and not internal(o)
                  and (o["name"] == explicit if explicit else identify(o["name"]))]
    if len(candidates) != 1:
        raise RuntimeError("Could not identify one glasses display. Use --output with its connector name.")
    others = [o for o in config["outputs"] if o.get("connected") and o.get("enabled")
              and not internal(o) and o["name"] != candidates[0]["name"]]
    if others:
        raise RuntimeError("Disconnect other active external monitors before using the glasses launcher.")
    return candidates[0]


class Screens:
    def read(self):
        result = subprocess.run(["kscreen-doctor", "--json"], check=True,
                                capture_output=True, text=True, timeout=8)
        config = json.loads(result.stdout)
        if not isinstance(config.get("outputs"), list):
            raise RuntimeError("KScreen did not return a usable display inventory.")
        return config

    def apply(self, commands):
        if commands:
            subprocess.run(["kscreen-doctor", *commands], check=True, timeout=10)


def command(output, setting):
    # Connector names are arguments, never shell text; periods are KScreen syntax.
    if not re.fullmatch(r"[A-Za-z0-9_-]+", output["name"]):
        raise RuntimeError("Unsupported display connector name")
    return "output." + output["name"] + "." + setting


def matches_mode(output, expected):
    current = next((m for m in output.get("modes", []) if m["id"] == output.get("currentModeId")), {})
    return output.get("enabled") and mode_size(current) == mode_size(expected) and abs(
        float(current.get("refreshRate", 0)) - float(expected.get("refreshRate", 0))) < 1


def restore_commands(saved, current):
    commands = []
    live = {o["name"]: o for o in current["outputs"] if o.get("connected")}
    for old in saved["outputs"]:
        output = live.get(old["name"])
        if output is None:
            continue
        # On disconnect, always recover a visible internal screen even if it was disabled before launch.
        recovery = internal(output) and (saved.get("wake_internal_on_exit", False)
                                        or not any(not internal(o) for o in live.values()))
        if not old.get("enabled") and not recovery:
            commands.append(command(output, "disable"))
            continue
        commands.append(command(output, "enable"))
        old_mode = next((m for m in old.get("modes", []) if m["id"] == old.get("currentModeId")), None)
        if old_mode:
            modes = [m for m in output.get("modes", []) if mode_size(m) == mode_size(old_mode)]
            if modes:
                mode = min(modes, key=lambda m: abs(float(m["refreshRate"]) - float(old_mode["refreshRate"])))
                commands.append(command(output, "mode." + str(mode["id"])))
        pos = old.get("pos", {"x": 0, "y": 0})
        commands += [command(output, "scale." + str(old.get("scale", 1))),
                     command(output, "position.%s,%s" % (pos["x"], pos["y"]))]
        rotation = {1: "none", 2: "left", 4: "inverted", 8: "right", 16: "flipped",
                    32: "flipped90", 64: "flipped180", 128: "flipped270"}.get(old.get("rotation", 1))
        if rotation:
            commands.append(command(output, "rotation." + rotation))
        if "priority" in old:
            commands.append(command(output, "priority." + str(max(1, old["priority"]) if recovery else old["priority"])))
        elif old.get("primary"):
            commands.append(command(output, "primary"))
    return commands


def restore(screens, saved):
    # First recover the built-in screen separately, so a rejected old external mode cannot strand us.
    live = screens.read()
    screens.apply([command(o, "enable") for o in live["outputs"] if o.get("connected") and internal(o)])
    if "hardware_sbs_before" in saved:
        # Recover the Deck panel before a hardware switch can disconnect the external output.
        target_name = saved.get("glasses_output")
        connected = any(o.get("connected") and o["name"] == target_name for o in live["outputs"])
        if connected:
            load_driver().set_enabled(saved["hardware_sbs_before"])
            for _ in range(10):
                if any(o.get("connected") and o["name"] == target_name for o in screens.read()["outputs"]):
                    break
                time.sleep(0.5)
    screens.apply(restore_commands(saved, screens.read()))


def load_driver():
    path = Path(__file__).resolve().with_name("driver-sbs.py")
    spec = importlib.util.spec_from_file_location("retrocrt_driver_sbs", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.DriverSBS()


def activate(screens, target, mode):
    screens.apply([command(target, "enable"), command(target, "mode." + str(mode["id"])),
                   command(target, "scale.1"), command(target, "rotation.none"),
                   command(target, "position.0,0")])
    verified = None
    for _ in range(8):
        config = screens.read()
        verified = next((o for o in config["outputs"] if o["name"] == target["name"]), None)
        if verified and verified.get("connected") and matches_mode(verified, mode) and abs(float(verified.get("scale", 1)) - 1) < 0.01:
            break
        time.sleep(0.25)
    else:
        raise RuntimeError("The glasses did not accept Full-SBS. The internal screen remains on.")
    screens.apply([command(o, "disable") for o in config["outputs"] if internal(o) and o.get("enabled")])


def healthy_status(path):
    try:
        report = json.loads(path.read_text())
        return (time.time() - path.stat().st_mtime < 6 and report.get("stereo") is True
                and report.get("width") == 3840 and report.get("height") == 1080 and report.get("frames", 0) > 10)
    except (OSError, ValueError):
        return False


def notice(message):
    print(message, flush=True)
    try:
        subprocess.Popen(["notify-send", "RetroCRT XR", message], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", help="Explicit glasses connector, for example DP-1")
    parser.add_argument("--restore", action="store_true", help="Recover the previous layout without launching")
    parser.add_argument("--manual-sbs", action="store_true", help="Use the glasses button instead of requesting hardware SBS")
    parser.add_argument("--auto-sbs", action="store_true", help="Experimental: request hardware SBS; the inspected SDK currently rejects this")
    parser.add_argument("--wait", type=float, default=90, help="Seconds to wait for the physical SBS switch")
    args, app_args = parser.parse_known_args()
    args.manual_sbs = args.manual_sbs or not args.auto_sbs
    if "gamescope" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower():
        raise RuntimeError("Use this launcher in KDE Desktop Mode. Gaming Mode has a different display manager.")
    import fcntl  # Linux only; keep the pure planning functions testable on Windows.
    state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "retrocrt"
    state.mkdir(parents=True, exist_ok=True)
    with (state / "display-session.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("A glasses session is already running. Exit it before restoring or relaunching.")
        return run_session(args, app_args, state)


def run_session(args, app_args, state):
    screens = Screens()
    backup = state / "display-before.json"
    if backup.exists():
        restore(screens, json.loads(backup.read_text()))
        backup.unlink()
    if args.restore:
        screens.apply([command(o, "enable") for o in screens.read()["outputs"] if o.get("connected") and internal(o)])
        return 0
    notice("Switch the glasses to SBS; display setup will follow automatically." if args.manual_sbs else
           "Connect the glasses. RetroCRT will request SBS through the existing XR driver.")
    target = None
    deadline = time.monotonic() + args.wait
    while time.monotonic() < deadline:
        config = screens.read()
        try:
            target = select_output(config, args.output)
        except RuntimeError:
            target = None
        if target:
            break
        time.sleep(1)
    else:
        raise RuntimeError("No identified glasses display found. No layout changes made. Use --output if EDID identification is unavailable.")
    # Snapshot only displays this session may change, before the first mutation.
    saved = {"wake_internal_on_exit": True,
             "outputs": [o for o in config["outputs"] if internal(o) or o["name"] == target["name"]]}
    def save_backup():
        temporary = backup.with_suffix(".tmp")
        temporary.write_text(json.dumps(saved, indent=2))
        os.replace(temporary, backup)
    save_backup()
    child = None
    def interrupted(_signum, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        manual = args.manual_sbs
        if not args.manual_sbs:
            try:
                driver = load_driver()
                saved["hardware_sbs_before"] = driver.enabled()
                saved["glasses_output"] = target["name"]
                save_backup()  # Persist the previous mode before sending any request.
                driver.set_enabled(True)
            except (RuntimeError, OSError, ImportError) as error:
                manual = True
                saved.pop("hardware_sbs_before", None)
                saved.pop("glasses_output", None)
                save_backup()
                notice("Automatic SBS unavailable: " + str(error) + " Switch the glasses to SBS manually.")
        deadline = time.monotonic() + args.wait
        while time.monotonic() < deadline:
            config = screens.read()
            target = next((o for o in config["outputs"] if o["name"] == target["name"] and o.get("connected")), target)
            if target.get("connected") and sbs_mode(target):
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("Full-SBS did not appear; restoring the display layout.")
        if manual:
            # The user owns the physical mode in fallback mode. Preserve their
            # working SBS desktop layout instead of restoring a pre-switch 2D mode.
            saved = {"wake_internal_on_exit": True,
                     "outputs": [o for o in config["outputs"] if internal(o) or o["name"] == target["name"]]}
            save_backup()
        activate(screens, target, sbs_mode(target))
        here = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory(prefix="retrocrt-display-", dir=state) as session_dir:
            status = Path(session_dir) / "status.json"
            env = dict(os.environ, RETROCRT_DISPLAY_STATUS=str(status))
            display_args = ["--display-driver", "wayland"] if os.environ.get("WAYLAND_DISPLAY") else []
            child = subprocess.Popen([str(here / "retrocrt.x86_64"), *display_args, "--rendering-method", "gl_compatibility",
                                      "--log-file", str(state / "godot.log"), "--", "--full-sbs", *app_args], env=env, cwd=here)
            deadline = time.monotonic() + 20
            acknowledged = False
            last_healthy = time.monotonic()
            while child.poll() is None:
                config = screens.read()
                live = next((o for o in config["outputs"] if o["name"] == target["name"]), {})
                if not live.get("connected") or not matches_mode(live, sbs_mode(target)):
                    raise RuntimeError("Glasses disconnected or left SBS mode; restoring the Deck screen.")
                healthy = healthy_status(status)
                acknowledged = acknowledged or healthy
                if healthy:
                    last_healthy = time.monotonic()
                if (acknowledged and time.monotonic() - last_healthy > 6) or (not acknowledged and time.monotonic() > deadline):
                    raise RuntimeError("The app did not maintain a Full-SBS window; restoring the Deck screen.")
                time.sleep(1)
            return child.returncode
    finally:
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        restore(screens, saved)
        backup.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as error:
        notice(str(error))
        sys.exit(1)
