import importlib.util, os, sys, tempfile
from pathlib import Path
spec = importlib.util.spec_from_file_location("ls", "/mnt/d/git/XR-CRT/scripts/linux-session.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
tmp = Path(tempfile.mkdtemp())
log = tmp / "runs.log"
fake = tmp / "fake.sh"
# First run asks for a restart (exit 86, leaving arguments); later runs just exit.
fake.write_text('''#!/bin/bash
echo "run: $*" >> %s
n=$(wc -l < %s)
if [ "$n" -eq 1 ]; then printf -- '--rom\n/games/B.iso\n--rom-play\n' > "$CRT_XR_RESTART_FILE"; exit 86; fi
exit ${FAKE_EXIT:-0}
''' % (log, log))
fake.chmod(0o755)
env = dict(os.environ, XDG_STATE_HOME=str(tmp))
(tmp / "crt_xr").mkdir()
app_args = ["--last-game"]
def rebuild(extra):
    global app_args
    app_args = m.with_restart(app_args, extra)
    return [str(fake), *app_args]
code = m.run_child([str(fake), *app_args], tmp, env, rebuild)
print("final exit:", code)
print(log.read_text())
# A genuine crash must not loop: exit 139 passes straight through.
log.write_text("")
fake.write_text('#!/bin/bash\necho x >> %s\nexit 139\n' % log); 
print("crash passes through:", m.run_child([str(fake)], tmp, env, rebuild), "runs:", len(log.read_text().splitlines()))
