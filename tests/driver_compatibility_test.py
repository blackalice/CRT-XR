"""Updated XR driver/API builds should use capabilities, not binary fingerprints."""
import importlib.util, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('driver_sbs',Path(__file__).resolve().parents[1]/'scripts/driver-sbs.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class DriverCompatibility(unittest.TestCase):
 def test_changed_driver_and_api_with_supported_state(self):
  with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1]/"build") as temp:
   home=Path(temp);driver=home/'.local/bin/xrDriver';driver.parent.mkdir(parents=True);driver.write_bytes(b'new upstream driver build')
   api=home/'homebrew/plugins/decky-XRGaming/PyXRLinuxDriverIPC/xrdriveripc.py';api.parent.mkdir(parents=True)
   api.write_text("class XRDriverIPC:\n def retrieve_driver_state(self):\n  return {'ui_view':{'driver_running':True},'connected_device_brand':'VITURE','connected_device_model':'Pro 2','sbs_mode_supported':True,'sbs_mode_enabled':True}\n",encoding='utf-8')
   with patch.object(Path,'home',return_value=home):
    self.assertTrue(module.DriverSBS().enabled())
 def test_missing_driver_is_actionable(self):
  with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1]/"build") as temp,patch.object(Path,'home',return_value=Path(temp)):
   with self.assertRaisesRegex(RuntimeError,'driver missing'): module.DriverSBS()
if __name__=='__main__':unittest.main()
