"""Desktop launcher resolves its own package; spaces and URI paths remain data."""
import configparser,os,shlex,subprocess,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class DesktopLauncherTests(unittest.TestCase):
 def command(self):
  cfg=configparser.ConfigParser(interpolation=None);cfg.read(ROOT/'scripts/installer/Install CRT XR.desktop')
  self.assertEqual(cfg['Desktop Entry']['Type'],'Application')
  self.assertEqual(cfg['Desktop Entry']['Terminal'],'false')
  args=shlex.split(cfg['Desktop Entry']['Exec']);self.assertEqual(args[-1],'%k');self.assertEqual(args[:2],['python3','-c'])
  return args
 def test_exec_field_is_a_single_quoted_python_program(self):self.command()
 @unittest.skipIf(os.name=='nt','Runs the real bash bootstrap on Linux')
 def test_launch_from_folder_with_spaces_and_symbols(self):self.launch(False)
 @unittest.skipIf(os.name=='nt','Runs the real bash bootstrap on Linux')
 def test_launch_file_uri_with_spaces_and_symbols(self):self.launch(True)
 @unittest.skipIf(os.name=='nt','Runs the real bash bootstrap on Linux')
 def test_launch_nested_payload_with_spaces_and_symbols(self):self.launch(False,True)
 @unittest.skipIf(os.name=='nt','Runs the real bash bootstrap on Linux')
 def test_launch_nested_payload_file_uri(self):self.launch(True,True)
 def launch(self,uri,nested=False):
  with tempfile.TemporaryDirectory() as tmp:
   folder=Path(tmp)/"Package with spaces & quote's";folder.mkdir()
   desktop=folder/'Install CRT XR.desktop';desktop.write_text('fixture')
   payload=folder/'CRT XR files' if nested else folder
   payload.mkdir(exist_ok=True)
   (payload/'Install-CRT-XR.sh').write_text('#!/usr/bin/env bash\nprintf launched > "$(dirname -- "$0")/marker"\n')
   args=self.command();args[0]=sys.executable;args[-1]=desktop.as_uri() if uri else str(desktop)
   subprocess.run(args,cwd='/',check=True)
   self.assertEqual((payload/'marker').read_text(),'launched')
if __name__=='__main__':unittest.main()
