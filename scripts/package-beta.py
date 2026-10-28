"""Arrange, check and archive an exported build for a release download.
Usage: python scripts/package-beta.py dist/CRT-XR-0.1.0-beta.14-SteamDeck linux [source-archive]
       python scripts/package-beta.py dist/CRT-XR-Linux-preview linux-desktop [source-archive]
       python scripts/package-beta.py dist/CRT-XR-0.1.0-beta.14-Windows windows [source-archive]
With a source archive (from package-corresponding-source.py), licenses/SOURCE-ACCESS.md
is written naming it and its SHA-256; otherwise an existing one is required.

The download shows only what a person needs first:
  Steam Deck: "Install CRT XR" (launcher), "HOW TO INSTALL.txt", "CRT XR files/"
  Windows:    CRT-XR.exe with its pack and extension, "HOW TO START.txt" and
              the cores/, assets/, tracking/, docs/ and licenses/ folders.
User guides go in docs/, notices in licenses/; developer notes stay on GitHub.
The installed Steam Deck app keeps the exported layout, so runtime paths and the
Steam shortcut are unchanged. Re-running on an arranged folder is safe.
"""
from pathlib import Path
import hashlib,json,shutil,sys,tarfile,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[1]
folder=Path(sys.argv[1]).resolve();target=sys.argv[2]
desktop=target=='linux-desktop'
platform='linux' if desktop else target
assert folder.is_dir() and platform in ["linux","windows"]
PAYLOAD="CRT XR files"
GUIDES={"linux":["GETTING-STARTED.md","PLAYING.md","GAMING-MODE.md","DISPLAY-SETUP.md"],"windows":["GETTING-STARTED.md","PLAYING.md","WINDOWS-SETUP.md"]}[platform]
if desktop:GUIDES=["LINUX-DESKTOP.md","PLAYING.md","DISPLAY-SETUP.md"]
NOTICES=["LICENSE","LICENSING.md","THIRD_PARTY.md","CORE-DISTRIBUTION.md","SOURCE-ACCESS.md","godot-cpp-LICENSE.md"]
DEVELOPER_NOTES=["BETA-REVIEW.md","BETA-QUICKSTART.md","PRE-LAUNCH-CHECKLIST.md","LICENCE-PROPOSAL.md","AUDIO.md","CRT-PERFORMANCE.md","INPUT-LATENCY.md","PICTURE-CONTROLS.md","ROOM-AND-VIEW.md","SCREEN-LIGHT.md","SETTINGS-AND-STARTUP.md","MENU-AND-SETTINGS.md"]

def move(source:Path,target:Path):
 if source.exists():target.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(source),str(target))

# Linux keeps the whole app in one folder beside the launcher.
app=folder/PAYLOAD if platform=="linux" else folder
if platform=="linux" and not app.is_dir():
 app.mkdir()
 for entry in list(folder.iterdir()):
  if entry!=app:move(entry,app/entry.name)
for name in GUIDES:move(app/name,app/"docs"/name)
for name in NOTICES:move(app/name,app/"licenses"/name)
for name in DEVELOPER_NOTES:(app/name).unlink(missing_ok=True)
if platform=="linux":
 if desktop:
  move(app/"Install CRT XR.desktop",app/"Install CRT XR Steam.desktop")
  move(app/"Install CRT XR Linux.desktop",folder/"Install CRT XR.desktop")
 else:move(app/"Install CRT XR.desktop",folder/"Install CRT XR.desktop")
 shutil.copy2(ROOT/"scripts/installer"/("HOW TO INSTALL LINUX.txt" if desktop else "HOW TO INSTALL.txt"),folder/"HOW TO INSTALL.txt")
else:
 move(app/"crt-xr-windows-tracking.exe",app/"tracking"/"crt-xr-windows-tracking.exe")
 # Steam artwork is only used by the Steam Deck installer.
 if (app/"artwork").is_dir():shutil.rmtree(app/"artwork")
 shutil.copy2(ROOT/"scripts/installer/HOW TO START.txt",folder/"HOW TO START.txt")

if len(sys.argv)>3:
 source=Path(sys.argv[3]).resolve();assert source.is_file(),f"Missing source archive: {source}"
 version=(ROOT/'project.godot').read_text(encoding='utf-8').split('config/version="',1)[1].split('"',1)[0]
 (app/"licenses").mkdir(exist_ok=True)
 location=("This preview's source archive is supplied alongside it; keep both files together." if desktop else
           f"It is published beside this download on the same GitHub release:\nhttps://github.com/blackalice/CRT-XR/releases/tag/v{version}")
 (app/"licenses"/"SOURCE-ACCESS.md").write_text(f"""# Corresponding source: {version}

Exact source and build inputs for this package: {source.name}
SHA-256: {hashlib.sha256(source.read_bytes()).hexdigest()}

{location}

Original CRT XR code is MIT; the emulator cores and other components keep their
own licences. See CORE-DISTRIBUTION.md and THIRD_PARTY.md in this folder.
""",encoding="utf-8")
required=["licenses/LICENSE","licenses/LICENSING.md","licenses/CORE-DISTRIBUTION.md","licenses/SOURCE-ACCESS.md","licenses/THIRD_PARTY.md","licenses/godot/LICENSE.txt","licenses/fonts/OpenSans-OFL.txt","assets/optimised/cabinet.scn","assets/wood-table/table.scn","assets/room-bake/table_contact_albedo.res"]+["docs/"+name for name in GUIDES]
required += ["CRT-XR.exe","CRT-XR.pck","tracking/crt-xr-windows-tracking.exe","crt_xr_libretro.windows.x86_64.dll"] if platform=="windows" else ["crt-xr.x86_64","crt-xr-engine.x86_64","crt-xr.pck","crt-xr-tracking-bridge","crt-xr-ipc-inventory","crt_xr_libretro.linux.x86_64.so","Install-CRT-XR.sh","installer/install.py","installer/steam_config.py","tracking-session.py"]+["artwork/"+name+".png" for name in ["Portrait","Landscape","Hero","Logo","Icon"]]
for name in required:assert (app/name).is_file(),f"Missing packaged asset: {name}"
if desktop:
 for name in ["launch-linux.sh","linux-session.py","installer/runtime_check.py","Install-CRT-XR-Linux.sh"]:
  assert (app/name).is_file(),f"Missing desktop installer asset: {name}"
for core in ["snes9x","nestopia","genesis_plus_gx","gambatte","mgba","mednafen_pce_fast","mednafen_lynx","mednafen_ngp","stella","vecx"]:assert (app/"cores"/(core+"_libretro."+("dll" if platform=="windows" else "so"))).is_file(),f"Missing packaged core: {core}"
top=sorted(p.name for p in folder.iterdir())
expected={"linux":sorted(["Install CRT XR.desktop","HOW TO INSTALL.txt",PAYLOAD]),"windows":sorted(["CRT-XR.exe","CRT-XR.pck","crt_xr_libretro.windows.x86_64.dll","HOW TO START.txt","cores","assets","tracking","docs","licenses"])}[platform]
assert top==expected,f"Unexpected top-level download contents: {top}"
subprocess.run([sys.executable,str(Path(__file__).with_name('check-core-sources.py')),str(app)],check=True)
checksums=app/"docs" if platform=="windows" else app
files=[p for p in app.rglob("*") if p.is_file() and p.name not in ["SHA256SUMS.txt","package-manifest.json"]]
for p in files:
 assert p.relative_to(app).parts[0].lower()!="sdk",f"Vendor SDK must not be bundled: {p}"
 assert p.name.lower() not in ["glasses.dll","libglasses.dll","carina_vio.dll","libusb-1.0.dll","opencv_world4100.dll"],f"Vendor runtime must not be bundled: {p}"
 assert p.suffix.lower() not in [".sfc",".smc",".nes",".gen",".smd",".sms",".gg",".gb",".gbc",".gba",".pce",".a26",".lynx",".ngp",".ngc",".vec",".cue",".mp3",".srm",".rst",".blend"],f"Private/source-only file in package: {p}"
 assert not p.name.lower().startswith("retrocrt"),f"Stale product binary: {p}"
if platform=="linux":
 for path in [app/name for name in ["crt-xr.x86_64","launch-deck.sh","launch-steam.sh","launch-glasses.sh","Install-CRT-XR.sh"]+(["launch-linux.sh","Install-CRT-XR-Linux.sh"] if desktop else [])]+[folder/"Install CRT XR.desktop"]:
  assert b"\r" not in path.read_bytes(),f"Linux launcher has Windows line endings: {path.name}"
# The installer verifies every file against this manifest before installing.
manifest={p.relative_to(app).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(checksums/"package-manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
(checksums/"SHA256SUMS.txt").write_text("".join(digest+"  "+name+"\n" for name,digest in sorted(manifest.items())))
archive=folder.parent/(folder.name+(".zip" if platform=="windows" else ".tar.gz"))
if archive.exists():raise SystemExit("Archive already exists; do not replace a released version silently")
if platform=="windows":
 with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as output:
  for p in folder.rglob("*"):
   if p.is_file():output.write(p,p.relative_to(folder.parent).as_posix())
else:
 def permissions(info):
  name=Path(info.name).name
  info.mode=0o755 if info.isdir() or name.endswith(".x86_64") or name.startswith("launch-") or name in ["Install-CRT-XR.sh","Install-CRT-XR-Linux.sh","Install CRT XR.desktop"] or name in ["crt-xr-tracking-bridge","crt-xr-ipc-inventory"] else 0o644
  return info
 with tarfile.open(archive,"w:gz") as output:output.add(folder,arcname=folder.name,filter=permissions)
print("Checked release download:",archive)
print("Top level:"," | ".join(top))
