#!/usr/bin/env python3
"""Request SBS through the installed XR driver's existing control protocol.

Only where the driver itself reports it can switch the connected glasses: it
reports sbs_mode_supported per device. (Checked on 24 October 2026 with driver
2.11.9: a VITURE Pro 2 reports false, and switches with its own button.)"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import time



class DriverSBS:
    control_path = Path("/dev/shm/xr_driver_control")
    def __init__(self):
        driver = Path.home() / ".local/bin/xrDriver"
        if not driver.is_file():
            raise RuntimeError("XR driver missing; use the physical SBS switch.")
        # Reuse the installed API's state parsing and feature-availability rules.
        api = Path.home() / "homebrew/plugins/decky-XRGaming/PyXRLinuxDriverIPC/xrdriveripc.py"
        if not api.is_file():
            raise RuntimeError("XR Gaming control API missing; use the physical SBS switch.")
        spec = importlib.util.spec_from_file_location("crt_xr_installed_xr_api", api)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.ipc = module.XRDriverIPC()
        if not callable(getattr(self.ipc, "retrieve_driver_state", None)):
            raise RuntimeError("XR Gaming control API lacks state access; use the physical SBS switch.")

    def state(self):
        state = self.ipc.retrieve_driver_state()
        if not state.get("ui_view", {}).get("driver_running"):
            raise RuntimeError("XR driver is not reporting a fresh heartbeat.")
        if not state.get("connected_device_brand"):
            raise RuntimeError("The XR driver has no glasses connected.")
        if state.get("sbs_mode_supported") is not True:
            raise RuntimeError("The driver is not reporting SBS support.")
        return state

    def supported(self):
        """True when the driver says it can switch these glasses; never raises."""
        try:
            state = self.state()
        except (RuntimeError, OSError, ValueError):
            return False
        return "sbs" in state.get("ui_view", {}).get("license", {}).get("enabled_features", [])

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


def load():
    """The driver adapter, or None when the XR driver or its API is missing."""
    try:
        return DriverSBS()
    except (RuntimeError, OSError, ImportError):
        return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["status", "supported", "on", "off"])
    args = parser.parse_args()
    control = DriverSBS()
    if args.mode == "supported":
        print(json.dumps({"supported": control.supported()}))
    else:
        if args.mode != "status": control.set_enabled(args.mode == "on")
        print(json.dumps({"sbs": control.enabled()}))
