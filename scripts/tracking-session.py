"""Lease the XR driver for raw tracking without a compositor display effect."""
import json
import os
from pathlib import Path
import re

TRACKING_ONLY = {
    "disabled": "false",
    "output_mode": "external_only",
    "external_mode": "none",
    "gamescope_reshade_wayland_disabled": "true",
}

def line_for(text, key):
    return re.search(r"(?m)^[ \t]*" + re.escape(key) + r"[ \t]*=.*$", text)

def replace_line(text, key, value):
    match = line_for(text, key)
    if match:
        return text[:match.start()] + (value or "") + text[match.end():]
    return text + ("" if text.endswith("\n") else "\n") + value + "\n" if value is not None else text

class TrackingSession:
    def __init__(self, config, state):
        self.config = Path(config)
        self.state = Path(state)
        self.journal = self.state / "tracking-only.json"
        self.lock = None
        self.active = False

    def restore(self, record):
        if record.get("version") != 1 or record.get("path") != str(self.config):
            raise RuntimeError("Tracking recovery record does not match this driver configuration")
        text = self.config.read_text(encoding="utf-8")
        original = record.get("original_text")
        if original is not None:
            expected = original
            for key, value in record["applied"].items(): expected = replace_line(expected, key, key+"="+value)
            if text == expected:
                if text != original: self.config.write_text(original, encoding="utf-8")
                self.journal.unlink()
                return
        restored = text
        for key, value in record["applied"].items():
            if key not in TRACKING_ONLY: raise RuntimeError("Unknown tracking recovery field")
            match = line_for(restored, key)
            # Preserve changes made through the driver's UI while the app was open.
            if match and match.group().split("=", 1)[1].strip() == value:
                restored = replace_line(restored, key, record["before"].get(key))
        if restored != text: self.config.write_text(restored, encoding="utf-8")
        self.journal.unlink()

    def __enter__(self):
        if not self.config.is_file():
            print("CRT XR: driver config missing; tracking-only setup unavailable", flush=True)
            return self
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.lock = (self.state / "tracking-only.lock").open("a")
        try:
            if os.name == "posix":
                import fcntl
                fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if self.journal.exists(): self.restore(json.loads(self.journal.read_text(encoding="utf-8")))
            original = self.config.read_text(encoding="utf-8")
            backup = self.state / "tracking-config-before.ini"
            backup.write_text(original, encoding="utf-8"); backup.chmod(0o600)
            before = {key: (line_for(original, key).group() if line_for(original, key) else None) for key in TRACKING_ONLY}
            record = {"version":1, "path":str(self.config), "before":before, "applied":TRACKING_ONLY, "original_text":original}
            self.journal.write_text(json.dumps(record), encoding="utf-8"); self.journal.chmod(0o600)
            self.active = True
            modified = original
            for key, value in TRACKING_ONLY.items(): modified = replace_line(modified, key, key + "=" + value)
            # The driver watches this file's writes; retain its inode and permissions.
            if modified != original: self.config.write_text(modified, encoding="utf-8")
            print("CRT XR: tracking enabled; XR driver display effects disabled for this session", flush=True)
            return self
        except BaseException:
            try:
                if self.active:
                    self.restore(record)
                    self.active = False
            finally:
                self.lock.close(); self.lock = None
            raise

    def __exit__(self, kind, value, traceback):
        try:
            if self.active:
                self.restore(json.loads(self.journal.read_text(encoding="utf-8")))
                self.active = False
                print("CRT XR: previous driver settings restored", flush=True)
        finally:
            if self.lock: self.lock.close(); self.lock = None
