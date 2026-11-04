"""Read accessible journal metadata, without opening root-owned core files."""
import json
import subprocess
import sys

pid = sys.argv[1]
data = subprocess.check_output(["journalctl", "COREDUMP_PID=" + pid, "-o", "json", "--no-pager"], text=True)
for line in data.splitlines():
    record = json.loads(line)
    for key in ("COREDUMP_TIMESTAMP", "COREDUMP_SIGNAL_NAME", "COREDUMP_CMDLINE", "MESSAGE"):
        print(key, record.get(key, ""))
    maps = record.get("COREDUMP_PROC_MAPS") or ""
    ip = int(sys.argv[2], 16)
    for mapping in maps.splitlines():
        span = mapping.split()[0].split("-")
        if len(span) == 2 and int(span[0], 16) <= ip < int(span[1], 16):
            print("FAULT MAPPING", mapping)
