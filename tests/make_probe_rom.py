"""Generate an original, asset-free SNES diagnostic cartridge (CC0-1.0).

Cycles backdrop color, turns red while SNES B is held, writes 0x5A to SRAM.
This is a tiny test program, not an emulator. No commercial game data is used.
"""
from pathlib import Path
import struct
import sys


def make_rom(path: Path, input_delay: bool = False) -> None:
    code = bytearray()
    labels = {}
    branches = []
    jumps = []

    def emit(*values):
        code.extend(values)

    def label(name):
        labels[name] = len(code)

    def branch(opcode, name):
        emit(opcode, 0)
        branches.append((len(code) - 1, name))

    emit(0x78, 0x18, 0xFB, 0xC2, 0x30)  # SEI; CLC; XCE; REP #$30
    emit(0xA2, 0xFF, 0x1F, 0x9A)  # LDX #$1FFF; TXS
    emit(0xA9, 0, 0, 0x5B, 0xE2, 0x20)  # LDA #0; TCD; SEP #$20
    emit(0xA9, 0x80, 0x8D, 0, 0x21)  # force blank
    for address in (0x4200, 0x212C, 0x212D, 0x2130, 0x2131, 0x2105):
        emit(0x9C, address & 255, address >> 8)  # STZ absolute
    emit(0x64, 0)  # STZ direct counter
    if input_delay:
        emit(0x64, 1)  # previous-frame controller value for the latency fixture
    emit(0xA9, 0x5A, 0x8F, 0, 0, 0x70)  # STA.l SRAM sentinel
    emit(0xA9, 1, 0x8D, 0, 0x42)  # enable auto joypad
    emit(0xA9, 15, 0x8D, 0, 0x21)  # display on / full brightness
    label("visible")
    emit(0xAD, 0x12, 0x42, 0x29, 0x80)
    branch(0xD0, "visible")  # wait until outside VBlank
    label("vblank")
    emit(0xAD, 0x12, 0x42, 0x29, 0x80)
    branch(0xF0, "vblank")
    label("joy")
    emit(0xAD, 0x12, 0x42, 0x29, 1)
    branch(0xD0, "joy")
    emit(0xE6, 0, 0x9C, 0x21, 0x21)  # increment frame counter; CGADD=0
    emit(0xAD, 0x19, 0x42, 0x29, 0x80)  # auto joypad B
    if input_delay:
        # Intentionally delay the fixture's reaction by one frame, so the test
        # can distinguish ordinary output from a restored speculative frame.
        emit(0x85, 2, 0xA5, 1, 0x48, 0xA5, 2, 0x85, 1, 0x68)
    branch(0xF0, "normal")
    emit(0xA9, 0x1F, 0x8D, 0x22, 0x21, 0xA9, 0, 0x8D, 0x22, 0x21)
    branch(0x80, "done")
    label("normal")
    emit(0xA5, 0, 0x29, 0x1F, 0x8D, 0x22, 0x21)
    emit(0xA9, 0x7C, 0x8D, 0x22, 0x21)
    label("done")
    emit(0x4C, 0, 0)
    jumps.append((len(code) - 2, "visible"))
    label("interrupt")
    emit(0x40)  # RTI (interrupts are disabled)
    for location, name in branches:
        offset = labels[name] - (location + 1)
        assert -128 <= offset <= 127
        code[location] = offset & 255
    for location, name in jumps:
        struct.pack_into("<H", code, location, 0x8000 + labels[name])

    rom = bytearray([0xEA] * 131072)
    rom[:len(code)] = code
    rom[0x7FC0:0x7FD5] = b"RETROCRT OPEN PROBE".ljust(21)
    rom[0x7FD5:0x7FDC] = bytes([0x20, 0x02, 7, 1, 1, 0, 0])
    rom[0x7FDC:0x7FE0] = bytes(4)
    for offset in range(0x7FE4, 0x8000, 2):
        struct.pack_into("<H", rom, offset, 0x8000 + labels["interrupt"])
    struct.pack_into("<H", rom, 0x7FFC, 0x8000)
    checksum = (sum(rom) + 0x1FE) & 0xFFFF
    struct.pack_into("<HH", rom, 0x7FDC, checksum ^ 0xFFFF, checksum)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(rom)
    print(f"Original CC0 diagnostic ROM: {path} ({len(rom)} bytes)")


if __name__ == "__main__":
    make_rom(Path(sys.argv[1]) if len(sys.argv) > 1 else Path("build/retrocrt-probe.sfc"),
             input_delay="--input-delay" in sys.argv[2:])
