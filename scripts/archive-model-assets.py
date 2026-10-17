"""Local recovery bundle of original/prepared model assets; excluded from Git."""
from pathlib import Path
import hashlib,json,zipfile,re
ROOT=Path(__file__).resolve().parents[1]
files=set()
for item in json.loads((ROOT/"assets/model-sources.json").read_text()):
 files.add(ROOT/item["source"])
 files.update(p for p in (ROOT/item["prepared"]).parent.iterdir() if p.is_file() and p.suffix in [".scn",".json"])
files.add(ROOT/"build/console-source/console-4k.glb")
for folder in ["build/crt-model/ao","build/room-bake"]:
 files.update(p for p in (ROOT/folder).iterdir() if p.is_file() and p.suffix in [".png",".res",".json"] and p.name!="geometry.json")
version=re.search(r'config/version="([^"]+)"',(ROOT/"project.godot").read_text()).group(1)
out=ROOT/("archive/CRT-XR-model-assets-"+version+".zip")
if out.exists():raise SystemExit("Recovery bundle already exists; preserve it or choose a new version.")
manifest={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
with zipfile.ZipFile(out,"w",zipfile.ZIP_DEFLATED,compresslevel=5) as archive:
 for p in sorted(files):archive.write(p,p.relative_to(ROOT).as_posix())
 archive.writestr("CRT-XR-ASSET-SHA256.json",json.dumps(manifest,indent=2))
with zipfile.ZipFile(out) as archive:
 for name,digest in manifest.items():assert hashlib.sha256(archive.read(name)).hexdigest()==digest,name
print(f"Verified model recovery bundle: {out} ({len(manifest)} files)")
