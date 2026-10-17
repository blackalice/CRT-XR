"""Fail release builds rather than silently shipping procedural/missing models."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
for item in json.loads((ROOT/"assets/model-sources.json").read_text()):
 if not item.get("included_in_launch",True):continue
 source=ROOT/item["source"]
 assert source.is_file(),f"Missing {source}; restore the model-asset backup"
 assert hashlib.sha256(source.read_bytes()).hexdigest()==item["source_sha256"],f"Changed source: {source}"
 assert (ROOT/item["prepared"]).is_file(),f"Prepare {item['name']} before export"
for path in ["build/room-bake/table_contact_albedo.res","build/room-bake/floor_ao.png","build/crt-model/ao/tvfront_ao.png","third_party/godot/LICENSE.txt","third_party/godot/COPYRIGHT.txt"]:
 assert (ROOT/path).is_file(),f"Missing release input: {path}"
assert not json.loads((ROOT/"build/room-bake/bake.json").read_text())["console_present"],"Rebake the launch layout without the console"
print("Release model sources, prepared assets, bakes and engine notices verified.")
