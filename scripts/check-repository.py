"""Review Git publication inputs, not ignored local builds. No network or writes."""
from pathlib import Path
import re, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
def git(*args, **kwargs):
    return subprocess.check_output(['git', *args], cwd=ROOT, **kwargs)

failures = []
def problem(message):
    failures.append(message)
    print('FAIL:', message)

files = sorted(set(git('ls-files', '-c', '-o', '--exclude-standard', '-z').decode('utf-8').split('\0')) - {''})
for name in files:
    path = ROOT / name
    if not path.is_file():
        continue
    if name.split('/')[0] in {'tools', 'build', 'dist', 'archive', 'cores', 'userdata', 'saves', 'roms'}:
        problem('Local-only path in publication inputs: ' + name)
    if path.stat().st_size > 50 * 1024 * 1024:
        problem('File exceeds repository size budget: ' + name)
    if path.suffix.lower() in {'.sfc', '.smc', '.swc', '.fig', '.nes', '.unf', '.unif', '.gen', '.smd', '.sms', '.gg', '.srm', '.sav', '.pem', '.key', '.mp3', '.flac', '.m4a', '.bin'}:
        problem('Private cartridge/save/key file in publication inputs: ' + name)
    if path.suffix.lower() in {'.png', '.jpg', '.wav', '.res', '.scn'}:
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except (UnicodeError, OSError):
        continue
    # Report filenames only: never print a credential if one is detected.
    if re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgithub_pat_[A-Za-z0-9_]{30,}|\bgh[pousr]_[A-Za-z0-9]{30,}', text):
        problem('Possible credential; review locally: ' + name)

for required in ['LICENSE', 'LICENSING.md', 'THIRD_PARTY.md', 'docs/DEVELOPMENT.md']:
    if not (ROOT / required).is_file(): problem('Missing publication notice: ' + required)

objects = git('rev-list', '--objects', '--all')
result = subprocess.run(['git', 'cat-file', '--batch-check=%(objecttype) %(objectsize) %(rest)'], input=objects, cwd=ROOT, capture_output=True, check=True)
for line in result.stdout.decode('utf-8').splitlines():
    kind, size, *name = line.split(' ', 2)
    if kind == 'blob' and int(size) > 50 * 1024 * 1024:
        problem('Historical blob exceeds repository size budget: ' + (name[0] if name else '(unnamed)'))
whitespace = subprocess.run(['git', 'diff', '--check'], cwd=ROOT, capture_output=True)
if whitespace.returncode:
    problem('git diff --check reports whitespace errors; inspect locally')
print('Reviewed', len(files), 'publication inputs and reachable Git object sizes.')
print('This targeted check is not a full secret/history audit or binary-licensing clearance.')
sys.exit(1 if failures else 0)
