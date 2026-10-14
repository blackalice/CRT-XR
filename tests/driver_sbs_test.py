import importlib.util
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("driver_sbs", Path(__file__).resolve().parents[1] / "scripts/driver-sbs.py")
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


class DriverTests(unittest.TestCase):
    def setUp(self):
        nofollow = patch.object(driver.os, "O_NOFOLLOW", getattr(driver.os, "O_NOFOLLOW", 0), create=True)
        nofollow.start()
        self.addCleanup(nofollow.stop)
        self.folder = tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1] / "build")
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name) / "control"
        self.state = {"sbs_mode_supported": True, "sbs_mode_enabled": False,
                      "connected_device_brand": "VITURE", "connected_device_model": "Pro 2",
                      "ui_view": {"driver_running": True, "license": {"enabled_features": ["sbs"]}}}
        self.control = driver.DriverSBS.__new__(driver.DriverSBS)
        self.control.control_path = self.path
        self.control.ipc = types.SimpleNamespace(retrieve_driver_state=lambda: self.state)

    def test_unavailable_feature_never_writes(self):
        self.state["ui_view"]["license"]["enabled_features"] = []
        with self.assertRaises(RuntimeError): self.control.set_enabled(True)
        self.assertFalse(self.path.exists())

    def test_stale_or_wrong_device_never_writes(self):
        self.state["ui_view"]["driver_running"] = False
        with self.assertRaises(RuntimeError): self.control.set_enabled(True)
        self.state["ui_view"]["driver_running"] = True
        self.state["connected_device_model"] = "Other"
        with self.assertRaises(RuntimeError): self.control.set_enabled(True)
        self.assertFalse(self.path.exists())

    def test_pending_request_preserved(self):
        self.path.write_text("another_client=true\n")
        with patch.object(driver.time, "sleep"), self.assertRaises(RuntimeError): self.control.set_enabled(True)
        self.assertEqual(self.path.read_text(), "another_client=true\n")

    def test_only_sbs_sent_and_acknowledged(self):
        def consume():
            if self.path.exists():
                self.assertEqual(self.path.read_text(), "sbs_mode=enable\n")
                self.state["sbs_mode_enabled"] = True
                self.path.unlink()
            return self.state
        self.control.ipc.retrieve_driver_state = consume
        self.control.set_enabled(True)
        self.assertTrue(self.control.enabled())
        self.assertFalse(self.path.exists())

    def test_already_in_requested_mode_does_not_send(self):
        self.control.set_enabled(False)
        self.assertFalse(self.path.exists())


if __name__ == "__main__": unittest.main()
