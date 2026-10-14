import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("steam_session", ROOT / "scripts/steam-session.py")
session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(session)


class SteamSessionTests(unittest.TestCase):
    def test_gamescope_owns_display(self):
        command = session.launch_command(ROOT, {"XDG_CURRENT_DESKTOP": "gamescope"}, True, [])
        self.assertIn("--full-sbs", command)
        self.assertIn("x11", command)
        self.assertFalse(any("kscreen" in x or "glasses-session" in x for x in command))

    def test_mono_and_rom_arguments(self):
        path = "/home/deck/Games/A game.sfc"
        command = session.launch_command(ROOT, {"GAMESCOPE_WAYLAND_DISPLAY": "gamescope-0"}, False, ["--rom", path])
        self.assertNotIn("--full-sbs", command)
        self.assertEqual(command[-2:], ["--rom", path])

    def test_desktop_keeps_recovery_supervisor(self):
        command = session.launch_command(ROOT, {"XDG_CURRENT_DESKTOP": "KDE"}, True, [])
        self.assertTrue(command[1].endswith("glasses-session.py"))
        self.assertIn("--manual-sbs", command)

    def test_requires_connected_identified_glasses(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            drm = Path(directory)
            connector = drm / "card1-DP-1"
            connector.mkdir()
            (connector / "status").write_text("disconnected")
            (connector / "edid").write_bytes(b"VITURE")
            self.assertFalse(session.glasses_connected(drm))
            (connector / "status").write_text("connected")
            self.assertTrue(session.glasses_connected(drm))
            (connector / "edid").write_bytes(b"Another monitor")
            self.assertFalse(session.glasses_connected(drm))

    def test_switch_waits_for_hardware_and_can_cancel(self):
        process = Mock()
        process.poll.return_value = None
        ready = Mock(side_effect=[False, False, True])
        sleep = Mock()
        self.assertTrue(session.wait_for_sbs(process, ready, clock=lambda: 0, sleep=sleep))
        self.assertEqual(sleep.call_count, 2)
        process.poll.return_value = 0
        self.assertFalse(session.wait_for_sbs(process, lambda: True, clock=lambda: 0, sleep=sleep))

    def test_switch_timeout_does_not_launch(self):
        process = Mock()
        process.poll.return_value = None
        ticks = iter([0, 0, 91])
        self.assertFalse(session.wait_for_sbs(process, lambda: False, clock=lambda: next(ticks), sleep=lambda _: None))


if __name__ == "__main__":
    unittest.main()
