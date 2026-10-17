import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("steam_session", ROOT / "scripts/steam-session.py")
session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(session)


class SteamSessionTests(unittest.TestCase):
    def test_gamescope_owns_display(self):
        command = session.launch_command(ROOT, {"XDG_CURRENT_DESKTOP": "gamescope"}, True, [])
        self.assertIn("--sbs-session-manual", command)
        self.assertIn("--fullscreen", command)
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

    def test_probe_supervises_both_processes_and_uses_unique_reports(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            from unittest.mock import MagicMock
            watcher=MagicMock(); child=MagicMock(); child.wait.return_value=0; child.poll.return_value=0
            with patch.dict(session.os.environ, {"XDG_STATE_HOME":directory,"XDG_CURRENT_DESKTOP":"gamescope"}), patch.object(session.sys,"argv",["steam-session.py","--glasses","--sbs-probe","--sbs-resolution","5120x1440","--xr-connector","card1-DP-1"]), patch.object(session.os,"chdir"), patch.object(session.subprocess,"Popen",side_effect=[watcher,child]) as spawn, patch.object(session.signal,"signal"):
                self.assertEqual(session.main(),0)
            self.assertEqual(spawn.call_count,2)
            self.assertIn("5120x1440",spawn.call_args_list[0].args[0])
            env=spawn.call_args_list[1].kwargs["env"]
            self.assertEqual(env["CRT_XR_SBS_SIZE"],"5120x1440")
            self.assertTrue(env["CRT_XR_DISPLAY_PROBE"].endswith("display.json"))
            watcher.terminate.assert_called_once();watcher.wait.assert_called_once()

    def test_default_gaming_glasses_launch_is_supervised(self):
        from unittest.mock import MagicMock
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            watcher=MagicMock();child=MagicMock();child.wait.return_value=0;child.poll.return_value=0
            with patch.dict(session.os.environ, {"XDG_STATE_HOME":directory,"XDG_CURRENT_DESKTOP":"gamescope"}), patch.object(session.sys,"argv",["steam-session.py"]), patch.object(session,"glasses_connected",return_value=True), patch.object(session.os,"chdir"), patch.object(session.subprocess,"Popen",side_effect=[watcher,child]) as spawn, patch.object(session.signal,"signal"):
                session.main()
            command=spawn.call_args.args[0]
            self.assertIn("--sbs-session-manual",command)
            self.assertIn("--last-game",command)
            self.assertNotIn("--sbs-prompt",command)

    def test_no_glasses_bypasses_sbs_and_preserves_mono_aspect(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            with patch.dict(session.os.environ, {"XDG_STATE_HOME":directory,"XDG_CURRENT_DESKTOP":"gamescope"}), patch.object(session.sys,"argv",["steam-session.py"]), patch.object(session,"glasses_connected",return_value=False), patch.object(session.os,"chdir"), patch.object(session.os,"execvpe") as execute, patch.object(session.subprocess,"Popen") as spawn:
                session.main()
            command=execute.call_args.args[1]
            self.assertIn("--windowed",command)
            self.assertIn("1280x800",command)
            self.assertNotIn("--sbs-session-manual",command)
            spawn.assert_not_called()



if __name__ == "__main__":
    unittest.main()
