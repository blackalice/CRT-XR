#!/usr/bin/env python3
"""Request SBS through the installed XR driver's existing control protocol."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import time

DRIVER_SHA256 = "bb14df734f6fb81fb22d584e9954a843acb4dda68c841bab176053e0371479ed"
API_SHA256 = "9e0bfcf85b7dc6f1a784fa0adfa1821d11351000883784df1668a173b36c0394"


class DriverSBS:
    control_path = Path("/dev/shm/xr_driver_control")
    def __init__(self):
        driver = Path.home() / ".local/bin/xrDriver"
        if hashlib.sha256(driver.read_bytes()).hexdigest() != DRIVER_SHA256:
            raise RuntimeError("Unverified XR driver build; use the physical SBS switch.")
        # Reuse the installed API's state parsing and feature-availability rules.
        api = Path.home() / "homebrew/plugins/decky-XRGaming/PyXRLinuxDriverIPC/xrdriveripc.py"
        if hashlib.sha256(api.read_bytes()).hexdigest() != API_SHA256:
            raise RuntimeError("Unverified XR Gaming control API; use the physical SBS switch.")
        spec = importlib.util.spec_from_file_location("retrocrt_installed_xr_api", api)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.ipc = module.XRDriverIPC()

    def state(self):
        state = self.ipc.retrieve_driver_state()
        if not state.get("ui_view", {}).get("driver_running"):
            raise RuntimeError("XR driver is not reporting a fresh heartbeat.")
        if state.get("connected_device_brand") != "VITURE" or state.get("connected_device_model") != "Pro 2":
            raise RuntimeError("The verified VITURE Pro 2 is not connected.")
        if state.get("sbs_mode_supported") is not True:
            raise RuntimeError("The driver is not reporting SBS support.")
        return state

    def enabled(self):
        return bool(self.state().get("sbs_mode_enabled"))

    def set_enabled(self, enabled):
        state = self.state()
        if bool(state.get("sbs_mode_enabled")) == enabled:
            return
        if enabled and "sbs" not in state.get("ui_view", {}).get("license", {}).get("enabled_features", []):
            raise RuntimeError("SBS is not currently available through XR Gaming. Use the physical switch.")
        path = self.control_path
        # Do not overwrite another client's pending request or change its permissions.
        for _ in range(20):
            try:
                fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
                break
            except FileExistsError:
                time.sleep(0.1)
        else:
            raise RuntimeError("An existing XR control request is blocking SBS. Use the physical switch.")
        # Closing this documented request triggers the driver's existing inotify handler.
        with os.fdopen(fd, "w") as request:
            request.write("sbs_mode=" + ("enable" if enabled else "disable") + "\n")
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            try:
                if self.enabled() == enabled:
                    return
            except RuntimeError:
                pass  # A display-mode transition may briefly reconnect the glasses.
            time.sleep(0.25)
        raise RuntimeError("The driver did not acknowledge the SBS switch.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["status", "on", "off"])
    args = parser.parse_args()
    control = DriverSBS()
    if args.mode != "status": control.set_enabled(args.mode == "on")
    print(json.dumps({"sbs": control.enabled()}))
