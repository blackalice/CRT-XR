"""Exercise recovery decisions without changing a real display."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch, Mock

spec = importlib.util.spec_from_file_location("glasses_session", Path(__file__).resolve().parents[1] / "scripts/glasses-session.py")
session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(session)


def fixture():
    return {"outputs": [
        {"name": "eDP-1", "connected": True, "enabled": True, "currentModeId": "panel", "scale": 1.25,
         "pos": {"x": 3840, "y": 0}, "rotation": 1, "priority": 1,
         "modes": [{"id": "panel", "size": {"width": 1280, "height": 800}, "refreshRate": 90}]},
        {"name": "DP-1", "connected": True, "enabled": True, "currentModeId": "mono", "scale": 1,
         "pos": {"x": 0, "y": 0}, "rotation": 1, "priority": 2,
         "modes": [{"id": "mono", "size": {"width": 1920, "height": 1080}, "refreshRate": 60},
                   {"id": "sbs120", "size": {"width": 3840, "height": 1080}, "refreshRate": 120},
                   {"id": "sbs60", "size": {"width": 3840, "height": 1080}, "refreshRate": 60}]}]}


class DisplayTests(unittest.TestCase):
    def test_cancel_during_instructions_restores_without_a_second_launch(self):
        screens=Mock();screens.read.return_value=fixture()
        child=Mock();child.poll.return_value=0;child.returncode=0
        args=types.SimpleNamespace(output='DP-1',restore=False,wait=90,manual_sbs=True)
        with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1]/'build') as directory:
            with patch.object(session,'Screens',return_value=screens),patch.object(session,'activate') as activate,patch.object(session,'restore') as restore,patch.object(session,'notice'),patch.object(session.signal,'signal'),patch.object(session.subprocess,'Popen',return_value=child) as popen:
                self.assertEqual(session.run_session(args,[],Path(directory)),0)
                self.assertEqual(activate.call_count,1)
                popen.assert_called_once();restore.assert_called_once()
            self.assertFalse((Path(directory)/'display-before.json').exists())

    def test_one_fullscreen_process_spans_prompt_and_display_change(self):
        config=fixture()
        screens=Mock();screens.read.side_effect=lambda:copy.deepcopy(config)
        child=Mock();child.poll.side_effect=[None,None,0,0];child.returncode=0
        order=[];launch_env={}
        def activate(_screens,target,mode):
            order.append(mode['id'])
            config['outputs'][1]['currentModeId']=mode['id']
            config['outputs'][0]['enabled']=False
            if launch_env: self.assertFalse(Path(launch_env['CRT_XR_STARTUP_GATE']).exists())
        def spawn(command,**kwargs):
            order.append('spawn');launch_env.update(kwargs['env'])
            self.assertIn('--fullscreen',command)
            self.assertIn('--sbs-session',command)
            return child
        def healthy(path):
            self.assertEqual(json.loads(Path(launch_env['CRT_XR_STARTUP_GATE']).read_text()),{'start':True})
            return True
        args=types.SimpleNamespace(output='DP-1',restore=False,wait=90,manual_sbs=True)
        with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1]/'build') as directory:
            with patch.object(session,'Screens',return_value=screens),patch.object(session,'activate',side_effect=activate),patch.object(session,'restore') as restore,patch.object(session,'notice'),patch.object(session.signal,'signal'),patch.object(session.subprocess,'Popen',side_effect=spawn) as popen,patch.object(session,'healthy_status',side_effect=healthy),patch.object(session.time,'sleep'):
                self.assertEqual(session.run_session(args,[],Path(directory)),0)
                self.assertEqual(order,['mono','spawn','sbs60'])
                popen.assert_called_once();restore.assert_called_once()
            self.assertFalse(Path(launch_env['CRT_XR_STARTUP_GATE']).exists())

    def test_refuses_unidentified_ultrawide(self):
        with self.assertRaises(RuntimeError):
            session.select_output(fixture(), identify=lambda _: False)

    def test_explicit_connector_and_prefer_sixty(self):
        output = session.select_output(fixture(), explicit="DP-1")
        self.assertEqual(session.sbs_mode(output)["id"], "sbs60")

    def test_refuses_ambiguous_headsets(self):
        config = fixture()
        extra = copy.deepcopy(config["outputs"][1])
        extra["name"] = "DP-2"
        config["outputs"].append(extra)
        with self.assertRaises(RuntimeError):
            session.select_output(config, identify=lambda _: True)

    def test_no_internal_disable_if_mode_not_accepted(self):
        class RejectingScreens:
            def __init__(self): self.commands = []
            def read(self): return fixture()
            def apply(self, commands): self.commands.extend(commands)
        screens = RejectingScreens()
        target = fixture()["outputs"][1]
        with patch.object(session.time, "sleep"), self.assertRaises(RuntimeError):
            session.activate(screens, target, session.sbs_mode(target))
        self.assertNotIn("output.eDP-1.disable", screens.commands)

    def test_restore_after_mode_ids_change(self):
        saved = fixture()
        current = fixture()
        current["outputs"][1]["modes"][0]["id"] = "renumbered"
        commands = session.restore_commands(saved, current)
        self.assertIn("output.DP-1.mode.renumbered", commands)
        self.assertIn("output.eDP-1.position.3840,0", commands)
        self.assertIn("output.eDP-1.scale.1.25", commands)
        self.assertIn("output.eDP-1.priority.1", commands)

    def test_disconnect_recovers_previously_disabled_panel(self):
        saved = fixture()
        saved["outputs"][0]["enabled"] = False
        current = fixture()
        current["outputs"][1]["connected"] = False
        commands = session.restore_commands(saved, current)
        self.assertIn("output.eDP-1.enable", commands)
        self.assertNotIn("output.eDP-1.disable", commands)
        self.assertFalse(any(c.startswith("output.DP-1") for c in commands))

    def test_exit_policy_wakes_panel_even_with_glasses_connected(self):
        saved = fixture()
        saved["outputs"][0]["enabled"] = False
        saved["outputs"][0]["priority"] = 0
        saved["wake_internal_on_exit"] = True
        commands = session.restore_commands(saved, fixture())
        self.assertIn("output.eDP-1.enable", commands)
        self.assertIn("output.eDP-1.priority.1", commands)
        self.assertNotIn("output.eDP-1.disable", commands)

    def test_internal_recovered_before_external_restore_failure(self):
        class FailingScreens:
            def __init__(self): self.calls = []
            def read(self): return fixture()
            def apply(self, commands):
                self.calls.append(commands)
                if len(self.calls) == 2: raise RuntimeError("External mode rejected")
        screens = FailingScreens()
        with self.assertRaises(RuntimeError): session.restore(screens, fixture())
        self.assertEqual(screens.calls[0], ["output.eDP-1.enable"])

    def test_only_complete_fresh_sbs_report_accepted(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1] / "build") as directory:
            path = Path(directory) / "status.json"
            self.assertFalse(session.healthy_status(path))
            path.write_text('{"stereo":')
            self.assertFalse(session.healthy_status(path))
            report = {"stereo": True, "width": 3840, "height": 1080, "frames": 50}
            path.write_text(json.dumps(report))
            self.assertTrue(session.healthy_status(path))
            with patch.object(session.time, "time", return_value=path.stat().st_mtime + 10):
                self.assertFalse(session.healthy_status(path))
            report["width"] = 1280
            path.write_text(json.dumps(report))
            self.assertFalse(session.healthy_status(path))

    def test_launch_failure_runs_restore_and_clears_recovery_snapshot(self):
        class FakeScreens:
            def __init__(self):
                self.config = fixture()
                self.calls = []
            def read(self): return copy.deepcopy(self.config)
            def apply(self, commands):
                self.calls.append(commands)
                for cmd in commands:
                    for output in self.config["outputs"]:
                        if cmd == "output." + output["name"] + ".disable": output["enabled"] = False
                        if cmd == "output." + output["name"] + ".enable": output["enabled"] = True
                        if cmd == "output." + output["name"] + ".mode.sbs60": output["currentModeId"] = "sbs60"
        screens = FakeScreens()
        locks = types.SimpleNamespace(LOCK_EX=1, LOCK_NB=2, flock=lambda *_: None)
        with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1] / "build") as directory:
            with patch.dict("sys.modules", {"fcntl": locks}), patch.dict(session.os.environ, {"XDG_STATE_HOME": directory, "XDG_CURRENT_DESKTOP": "KDE"}), patch.object(session.sys, "argv", ["glasses-session.py", "--output", "DP-1"]), patch.object(session, "Screens", return_value=screens), patch.object(session, "notice"), patch.object(session.subprocess, "Popen", side_effect=FileNotFoundError("No app")):
                with self.assertRaises(FileNotFoundError): session.main()
            self.assertIn(["output.eDP-1.disable"], screens.calls)
            self.assertTrue(screens.config["outputs"][0]["enabled"])
            self.assertFalse((Path(directory) / "crt_xr/display-before.json").exists())


if __name__ == "__main__":
    unittest.main()
