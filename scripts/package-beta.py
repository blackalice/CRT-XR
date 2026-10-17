"""Package a reviewed build, checking payload and recording checksums/modes.
Usage: python scripts/package-beta.py dist/CRT-XR-0.1.0-beta.4-windows windows
"""
from pathlib import Path
import hashlib,json,sys,tarfile,zipfile
folder=Path(sys.argv[1]).resolve();platform=sys.argv[2]
assert folder.is_dir()
required=["THIRD_PARTY.md","BETA-REVIEW.md","BETA-QUICKSTART.md","licenses/godot/LICENSE.txt","assets/optimised/cabinet.scn","assets/wood-table/table.scn","assets/room-bake/table_contact_albedo.res"]
required += ["CRT-XR.exe","crt_xr_libretro.windows.x86_64.dll"] if platform=="windows" else ["crt-xr.x86_64","crt-xr-engine.x86_64","crt-xr.pck","crt-xr-tracking-bridge","crt-xr-ipc-inventory","crt_xr_libretro.linux.x86_64.so"]
if platform=="linux":required += ["Install-CRT-XR.sh","installer/install.py","installer/steam_config.py","GETTING-STARTED.md"]
required += ["artwork/"+name+".png" for name in ["Portrait","Landscape","Hero","Logo","Icon"]]
for name in required:assert (folder/name).is_file(),f"Missing packaged asset: {name}"
for core in ["snes9x","nestopia","genesis_plus_gx"]:assert (folder/"cores"/(core+"_libretro."+("dll" if platform=="windows" else "so"))).is_file()
files=[p for p in folder.rglob("*") if p.is_file() and p.name not in ["SHA256SUMS.txt","package-manifest.json"]]
for p in files:
 assert p.suffix.lower() not in [".sfc",".smc",".nes",".gen",".smd",".sms",".gg",".mp3",".srm",".rst",".blend"],f"Private/source-only file in package: {p}"
 assert not p.name.lower().startswith("retrocrt"),f"Stale product binary: {p}"
if platform=="linux":
 for name in ["crt-xr.x86_64","launch-deck.sh","launch-steam.sh","launch-glasses.sh","Install-CRT-XR.sh"]:
  assert b"\r" not in (folder/name).read_bytes(),f"Linux launcher has Windows line endings: {name}"
manifest={p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(folder/"package-manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
(folder/"SHA256SUMS.txt").write_text("".join(digest+"  "+name+"\n" for name,digest in sorted(manifest.items())))
archive=folder.parent/(folder.name+(".zip" if platform=="windows" else ".tar.gz"))
if archive.exists():raise SystemExit("Archive already exists; do not replace a released version silently")
if platform=="windows":
 with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as output:
  for p in folder.rglob("*"):
   if p.is_file():output.write(p,p.relative_to(folder.parent).as_posix())
else:
 def permissions(info):
  name=Path(info.name).name
  info.mode=0o755 if info.isdir() or name.endswith(".x86_64") or name.startswith("launch-") or name=="Install-CRT-XR.sh" or name in ["crt-xr-tracking-bridge","crt-xr-ipc-inventory"] else 0o644
  return info
 with tarfile.open(archive,"w:gz") as output:output.add(folder,arcname=folder.name,filter=permissions)
print("Checked beta candidate archive:",archive)
