"""Runtime checks for the current x86-64 Linux build; no package-manager changes."""
import os
from pathlib import Path
import platform
import shutil
import subprocess


def check_runtime(package):
    if platform.system() != 'Linux' or platform.machine().lower() not in ('x86_64', 'amd64'):
        raise RuntimeError('This download needs x86-64 Linux. ARM devices and Android need a different build.')
    libc, version = platform.libc_ver()
    try:
        compatible = libc == 'glibc' and tuple(int(p) for p in version.split('.')[:2]) >= (2, 38)
    except ValueError:
        compatible = False
    if not compatible:
        raise RuntimeError('This build needs glibc 2.38 or newer; detected %s %s. Musl-based systems are not supported by this build.' % (libc or 'unknown libc', version))
    ldd = shutil.which('ldd')
    if not ldd:
        raise RuntimeError('Cannot check Linux runtime libraries: ldd is missing. Install your distribution\'s libc runtime tools.')
    package = Path(package)
    binaries = [package / 'crt-xr-engine.x86_64', *sorted(package.glob('*.so')), *sorted((package / 'cores').glob('*_libretro.so'))]
    errors = []
    for binary in binaries:
        result = subprocess.run([ldd, str(binary)], env=dict(os.environ, LC_ALL='C'), capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        missing = [line.strip() for line in output.splitlines() if 'not found' in line]
        if missing:
            errors.append(binary.name + ': ' + '; '.join(missing))
        elif result.returncode and 'not a dynamic executable' not in output and 'statically linked' not in output:
            errors.append(binary.name + ': ' + output.strip())
    if errors:
        raise RuntimeError('Required Linux libraries are unavailable. This build also needs libstdc++ with GLIBCXX_3.4.32.\n' + '\n'.join(errors))
    return {'architecture': 'x86_64', 'glibc': version}
