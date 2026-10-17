"""Isolated beta regression suites; source checkout, no user data or commercial ROMs."""
from pathlib import Path
import concurrent.futures, json, os, re, subprocess, tempfile, time, sys
ROOT=Path(__file__).resolve().parents[1]
GODOT=ROOT/"tools/godot/Godot_v4.5.1-stable_win64_console.exe"
TESTS="smoke emulation multicore gamepad controller_menu menu_navigation stereo_menu picture_controls picture_pipeline preferences_startup rom_locations rom_index library_cards play_qol share_and_defaults showcase_defaults music_albums music_resume tv_audio tv_power_on console_prop room_contacts user_data_migration pose_prediction".split()
OUT=ROOT/"build/beta-review";OUT.mkdir(parents=True,exist_ok=True)
def run(name):
    env=dict(os.environ,APPDATA=tempfile.mkdtemp(prefix=name+"-",dir=OUT))
    try:
        flags=["--audio-driver","Dummy","--minimized"] if name in ["picture_controls","picture_pipeline","share_and_defaults"] else ["--headless"]
        result=subprocess.run([str(GODOT),*flags,"--path",str(ROOT),"--script",f"tests/{name}.gd"],cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding="utf-8",errors="replace",timeout=90)
        log=result.stdout
        ok=result.returncode==0 and not re.search(r"^FAIL:|SCRIPT ERROR",log,re.M)
        (OUT/(name+".log")).write_text(log,encoding="utf-8")
        return {"test":name,"passed":ok,"exit_code":result.returncode}
    except subprocess.TimeoutExpired as error:
        data=error.stdout or b""
        (OUT/(name+".log")).write_text(data if isinstance(data,str) else data.decode("utf-8",errors="replace"),encoding="utf-8")
        return {"test":name,"passed":False,"timeout":True}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results=list(pool.map(run,sys.argv[1:] or TESTS))
if sys.argv[1:] and (OUT/"results.json").exists():
    previous=json.loads((OUT/"results.json").read_text())
    updated={x["test"]:x for x in previous}
    updated.update({x["test"]:x for x in results})
    results=[updated[name] for name in TESTS if name in updated]
(OUT/"results.json").write_text(json.dumps(results,indent=2))
for result in results:print(("PASS " if result["passed"] else "FAIL ")+result["test"],flush=True)
print(f"BETA SUITES: {sum(x['passed'] for x in results)}/{len(results)} passed")
raise SystemExit(0 if all(x["passed"] for x in results) else 1)
