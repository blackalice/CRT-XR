"""Original, asset-free diagnostic cartridges. CC0-1.0. No game data.

NES: palette backdrop changes from green to red while NES B is held.
Mega Drive: green CRAM backdrop, red while B is held (active-low port 1).
Master System/Game Gear: green backdrop; verifies Z80/VDP boot paths.
"""
from pathlib import Path
import struct

out = Path(__file__).resolve().parents[1] / 'build'
out.mkdir(exist_ok=True)

def nes():
    code = bytearray()
    def emit(*b): code.extend(b)
    emit(0x78,0xD8,0xA2,0xFF,0x9A)  # SEI CLD LDX #FF TXS
    emit(0xA9,0,0x8D,0,0x20,0x8D,1,0x20)  # disable NMI/rendering
    emit(0xA9,0x5A,0x8D,0,0x60)  # battery RAM sentinel
    loop = len(code)
    emit(0xA9,1,0x8D,0x16,0x40,0xA9,0,0x8D,0x16,0x40)
    emit(0xAD,0x16,0x40,0xAD,0x16,0x40,0x29,1)  # read A then B
    emit(0xF0,4,0xA9,0x16,0xD0,2,0xA9,0x1A)  # red/green
    emit(0x48,0xAD,2,0x20,0xA9,0x3F,0x8D,6,0x20,0xA9,0,0x8D,6,0x20)
    emit(0x68,0x8D,7,0x20,0x4C,loop & 255,0x80+(loop >> 8))
    prg = bytearray(16384); prg[:len(code)] = code
    for offset in (0x3FFA,0x3FFC,0x3FFE): struct.pack_into('<H',prg,offset,0x8000)
    (out/'crt-xr-probe.nes').write_bytes(b'NES\x1a'+bytes([1,1,2])+bytes(9)+prg+bytes(8192))

def megadrive():
    rom = bytearray(32768)
    struct.pack_into('>II',rom,0,0x00FFFF00,0x200)
    rom[0x100:0x110] = b'SEGA MEGA DRIVE '
    rom[0x120:0x150] = b'RETROCRT ORIGINAL CORE PROBE'.ljust(48,b' ')
    rom[0x150:0x180] = rom[0x120:0x150]
    rom[0x190:0x1A0] = b'J'.ljust(16,b' ')
    struct.pack_into('>IIII',rom,0x1A0,0,len(rom)-1,0xFF0000,0xFFFFFF)
    rom[0x1B0:0x1B4] = b'RA\xF8\x20'
    struct.pack_into('>II',rom,0x1B4,0x200001,0x203FFF)
    rom[0x1F0:0x200] = b'JUE'.ljust(16,b' ')
    code = bytearray()
    def word(*values):
        for v in values: code.extend(struct.pack('>H',v))
    def write(value,address): word(0x33FC,value,address>>16,address&65535)
    word(0x46FC,0x2700) # interrupts off
    word(0x13FC,0x005A,0x0020,0x0001) # battery RAM sentinel
    # Unlock TMSS on later machines, initialise VDP and backdrop register.
    word(0x23FC,0x5345,0x4741,0x00A1,0x4000)
    for index,value in enumerate([4,0x44,0x30,0x3C,7,0x6C,0,0,0,0,0,0,0x81,0x3F,0,2,1,0,0,0,0,0,0,0]):
        write(0x8000 | (index<<8) | value,0xC00004)
    # TH high, input port direction.
    word(0x13FC,0x40,0x00A1,0x0009,0x13FC,0x40,0x00A1,0x0003)
    loop = len(code)
    word(0x1039,0x00A1,0x0003,0x0200,0x0010) # MOVE.B pad,D0; ANDI.B #B
    word(0x6704,0x7000,0x6002,0x7001) # D0=0 normally,1 pressed
    word(0x23FC,0xC000,0,0x00C0,4) # CRAM write address 0
    word(0x4A00,0x670A) # test pressed; skip red write+branch
    write(0x000E,0xC00000)
    word(0x6008)
    write(0x00E0,0xC00000)
    displacement = loop-(len(code)+2)
    word(0x6000,displacement & 65535)
    rom[0x200:0x200+len(code)] = code
    struct.pack_into('>H',rom,0x18E,sum(struct.unpack('>'+str((len(rom)-0x200)//2)+'H',rom[0x200:])) & 65535)
    (out/'crt-xr-probe.md').write_bytes(rom)

def sega8(gamegear=False):
    code = bytearray([0xF3,0x31,0xF0,0xDF]) # DI, stack
    def emit(*b): code.extend(b)
    def reg(index,value): emit(0x3E,value,0xD3,0xBF,0x3E,0x80|index,0xD3,0xBF)
    for i,v in enumerate([4,0x40,0x0E,0,0,0x7E,0,0,0,0,0xFF]): reg(i,v)
    emit(0x3E,0,0xD3,0xBF,0x3E,0xC0,0xD3,0xBF)
    if gamegear: emit(0x3E,0xF0,0xD3,0xBE,0x3E,0,0xD3,0xBE)
    else: emit(0x3E,0x0C,0xD3,0xBE)
    emit(0x18,0xFE)
    rom = bytearray(32768); rom[:len(code)] = code
    rom[0x7FF0:0x7FF8] = b'TMR SEGA'
    rom[0x7FFF] = 0x6C if gamegear else 0x4C
    (out/('crt-xr-probe.gg' if gamegear else 'crt-xr-probe.sms')).write_bytes(rom)

nes(); megadrive(); sega8(); sega8(True)
pal_nes = bytearray((out/'crt-xr-probe.nes').read_bytes()); pal_nes[9] = 1
(out/'crt-xr-probe-pal.nes').write_bytes(pal_nes)
pal_md = bytearray((out/'crt-xr-probe.md').read_bytes()); pal_md[0x1F0:0x200] = b'E'.ljust(16,b' ')
(out/'crt-xr-probe-pal.md').write_bytes(pal_md)
