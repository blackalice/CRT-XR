import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('display_probe',ROOT/'scripts/display-probe.py')
probe=importlib.util.module_from_spec(spec);spec.loader.exec_module(probe)

class DisplayProbeTests(unittest.TestCase):
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

