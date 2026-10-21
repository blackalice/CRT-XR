import importlib.util,json,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("tracking",ROOT/"scripts/tracking-session.py")
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class TrackingOnlyTests(unittest.TestCase):
 def fixture(self,base,text="disabled=true\nexternal_mode=virtual_display\noutput_mode=mouse\ncustom=keep\n"):
  config=base/"config.ini";config.write_text(text,encoding="utf-8")
  return config,module.TrackingSession(config,base/"state")
 def test_tracking_without_compositor_and_exact_restoration(self):
  with tempfile.TemporaryDirectory(dir=ROOT/"build") as temp:
   config,lease=self.fixture(Path(temp));original=config.read_bytes()
   with lease:
    text=config.read_text()
    for key,value in module.TRACKING_ONLY.items(): self.assertIn(key+"="+value,text)
    self.assertIn("custom=keep",text)
   self.assertEqual(config.read_bytes(),original)
   self.assertFalse(lease.journal.exists())
 def test_exception_restores_settings(self):
  with tempfile.TemporaryDirectory(dir=ROOT/"build") as temp:
   config,lease=self.fixture(Path(temp));original=config.read_bytes()
   with self.assertRaises(ValueError):
    with lease:raise ValueError("test child failure")
   self.assertEqual(config.read_bytes(),original)
 def test_user_changes_are_preserved(self):
  with tempfile.TemporaryDirectory(dir=ROOT/"build") as temp:
   config,lease=self.fixture(Path(temp))
   with lease:config.write_text(config.read_text().replace("external_mode=none","external_mode=sideview").replace("custom=keep","custom=changed"))
   text=config.read_text();self.assertIn("external_mode=sideview",text);self.assertIn("custom=changed",text);self.assertIn("disabled=true",text)
 def test_interrupted_session_is_recovered_before_next_start(self):
  with tempfile.TemporaryDirectory(dir=ROOT/"build") as temp:
   base=Path(temp);config,lease=self.fixture(base);original=config.read_bytes()
   lease.__enter__();lease.lock.close();lease.lock=None
   with module.TrackingSession(config,base/"state"):self.assertIn("disabled=false",config.read_text())
   self.assertEqual(config.read_bytes(),original)
 def test_missing_configuration_is_left_untouched(self):
  with tempfile.TemporaryDirectory(dir=ROOT/"build") as temp:
   base=Path(temp)
   with module.TrackingSession(base/"missing.ini",base/"state") as lease:self.assertFalse(lease.active)
   self.assertFalse((base/"missing.ini").exists())
if __name__=="__main__":unittest.main()
