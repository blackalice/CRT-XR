import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('display_probe',ROOT/'scripts/display-probe.py')
probe=importlib.util.module_from_spec(spec);spec.loader.exec_module(probe)

class DisplayProbeTests(unittest.TestCase):
 def test_connected_glasses_with_power_off_remain_visible_in_diagnostics(self):
  with tempfile.TemporaryDirectory(dir=ROOT / "build") as temp:
   root=Path(temp);connector=root/'card1-DP-1';connector.mkdir()
   for name,value in {'status':'connected','modes':'3840x1080','enabled':'enabled','dpms':'Off'}.items():
    (connector/name).write_text(value)
   (connector/'edid').write_bytes(b'VITURE')
   report=probe.report((3840,1080),root)
   self.assertTrue(report['advertised'])
   self.assertEqual(report['outputs'][0]['dpms'],'Off')
   self.assertEqual(report['outputs'][0]['enabled'],'enabled')
   self.assertFalse(report['physical_mode_verified'])
 def test_runtime_report_preserves_age_and_partial_writes_do_not_break_probe(self):
  with tempfile.TemporaryDirectory(dir=ROOT / "build") as temp:
   path=Path(temp)/'runtime.json'
   self.assertIsNone(probe.runtime_snapshot(path,100))
   path.write_text('{"frames":')
   self.assertIsNone(probe.runtime_snapshot(path,100))
   path.write_text(json.dumps({'frames':420,'draws':419,'msaa':1}))
   snapshot=probe.runtime_snapshot(path,path.stat().st_mtime+8)
   self.assertEqual(snapshot['age_seconds'],8)
   self.assertEqual(snapshot['report']['draws'],419)
   path.write_text('[]')
   self.assertIsNone(probe.runtime_snapshot(path,100))
 def test_profile_dimensions(self):
  self.assertEqual(probe.dimensions('5120x1440'),(5120,1440))
  for value in ['3841x1080','1920','-3840x1080','99999x1080','0x0']:
   with self.assertRaises(ValueError): probe.dimensions(value)
 def test_modes_after_hotplug_and_explicit_identity(self):
  with tempfile.TemporaryDirectory(dir=ROOT / "build") as temp:
   root=Path(temp); connector=root/'card1-DP-1';connector.mkdir()
   (connector/'status').write_text('connected');(connector/'edid').write_bytes(b'Unknown XR')
   (connector/'modes').write_text('2560x1440\n')
   self.assertFalse(probe.report((5120,1440),root)['advertised'])
   self.assertFalse(probe.report((5120,1440),root,'card1-DP-1')['advertised'])
   (connector/'modes').write_text('5120x1440\n2560x1440\n')
   report=probe.report((5120,1440),root,'card1-DP-1')
   self.assertTrue(report['advertised']);self.assertFalse(report['physical_mode_verified'])
   self.assertIsNone(report['outputs'][0]['active_mode'])
   (connector/'status').write_text('disconnected')
   self.assertFalse(probe.report((5120,1440),root,'card1-DP-1')['advertised'])
 def test_ambiguous_identity_is_not_selected(self):
  with tempfile.TemporaryDirectory(dir=ROOT / "build") as temp:
   root=Path(temp)
   for name in ['card1-DP-1','card1-DP-2']:
    p=root/name;p.mkdir();(p/'status').write_text('connected');(p/'edid').write_bytes(b'VITURE');(p/'modes').write_text('3840x1080\n')
   self.assertFalse(probe.report((3840,1080),root)['advertised'])

if __name__=='__main__':unittest.main()

