"""Generate an original SH-4 idle-loop ELF for Flycast host smoke tests (CC0-1.0).
This tests core startup and vblank pacing, not game compatibility or performance.
"""
from pathlib import Path
import struct
import sys
out = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/flycast-probe.elf')
ident = b'\x7fELF\x01\x01\x01' + bytes(9)
header = ident + struct.pack('<HHIIIIIHHHHHH', 2, 42, 1, 0x8c010000, 52, 88, 0, 52, 32, 1, 40, 1, 0)
code = struct.pack('<HH', 0xaffe, 0x0009)  # bra . ; nop (delay slot)
segment = struct.pack('<IIIIIIII', 1, 84, 0x8c010000, 0x8c010000, len(code), len(code), 5, 4)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(header + segment + code + bytes(40))
print(out)
