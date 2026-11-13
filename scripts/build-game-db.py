"""Builds assets/game-db: small checksum/serial -> name tables the library uses
to name games whose file names say little.

Cartridges come from No-Intro DATs (libretro-database's metadat/no-intro copy,
in build/no-intro/); PlayStation 2 from PCSX2's GameIndex.yaml (tools/lrps2).
GameCube/Wii (GameTDB via Dolphin) and PSP (PPSSPP's redump.csv) are read from
core-data/ at run time, so they are not built here. See THIRD_PARTY.md.

Each table is gzip-compressed UTF-8 text, one game per line, tab-separated:
cartridges "crc32<TAB>sha1-prefix<TAB>name", PS2 "serial<TAB>name".
"""
from pathlib import Path
import gzip, re, sys

ROOT = Path(__file__).resolve().parents[1]
DATS = ROOT / "build/no-intro"
OUT = ROOT / "assets/game-db"
GAME_INDEX = ROOT / "tools/lrps2/bin/resources/GameIndex.yaml"

# CRT XR console -> No-Intro DATs (libretro file names).
CARTRIDGES = {
    "snes": ["Nintendo - Super Nintendo Entertainment System"],
    "nes": ["Nintendo - Nintendo Entertainment System"],
    "megadrive": ["Sega - Mega Drive - Genesis"],
    "mastersystem": ["Sega - Master System - Mark III"],
    "gamegear": ["Sega - Game Gear"],
    "gameboy": ["Nintendo - Game Boy", "Nintendo - Game Boy Color"],
    "gba": ["Nintendo - Game Boy Advance"],
    "pcengine": ["NEC - PC Engine - TurboGrafx 16"],
    "atari2600": ["Atari - 2600"],
    "atarilynx": ["Atari - Lynx"],
    "ngpc": ["SNK - Neo Geo Pocket", "SNK - Neo Geo Pocket Color"],
    "vectrex": ["GCE - Vectrex"],
    "n64": ["Nintendo - Nintendo 64"],
}
# The first 16 hex digits of a SHA-1 tell games apart; full digests would
# double the tables.
SHA1_DIGITS = 16
ROM = re.compile(r'rom \( name "((?:[^"\\]|\\.)*)" size (\d+) crc ([0-9A-Fa-f]{8})(?: md5 [0-9A-Fa-f]+)?(?: sha1 ([0-9A-Fa-f]{40}))?')
PS2_REGION = {"NTSC-U": "USA", "NTSC-J": "Japan", "NTSC-K": "Korea", "NTSC-C": "China", "NTSC-HK": "Hong Kong", "NTSC-T": "Taiwan"}


def write(name: str, lines: list[str]) -> int:
    data = ("\n".join(lines) + "\n").encode("utf-8")
    # mtime=0 keeps rebuilds byte-identical.
    (OUT / f"{name}.tsv.gz").write_bytes(gzip.compress(data, compresslevel=9, mtime=0))
    return len(lines)


def cartridge_lines(dat: Path) -> list[str]:
    lines = []
    for match in ROM.finditer(dat.read_text(encoding="utf-8", errors="replace")):
        rom_name, _size, crc, sha1 = match.groups()
        name = rom_name.replace('\\"', '"')
        name = name.rsplit(".", 1)[0] if "." in name else name
        lines.append(f"{crc.upper()}\t{(sha1 or '')[:SHA1_DIGITS].lower()}\t{name}")
    return lines


def ps2_lines() -> list[str]:
    lines, serial, name, english, region = [], "", "", "", ""

    def flush():
        title = english or name
        if serial and title:
            place = PS2_REGION.get(region, "Europe" if region.startswith("PAL") else "")
            lines.append(f"{serial}\t{title}" + (f" ({place})" if place else ""))

    for raw in GAME_INDEX.read_text(encoding="utf-8", errors="replace").splitlines():
        key = re.match(r"^([A-Z]{4}-\d{3,5}):", raw)
        if key:
            flush()
            serial, name, english, region = key.group(1), "", "", ""
            continue
        field = re.match(r'^  (name|name-en|region):\s*"?(.*?)"?\s*$', raw)
        if field and serial:
            value = field.group(2).replace('\\"', '"')
            if field.group(1) == "name": name = value
            elif field.group(1) == "name-en": english = value
            else: region = value
    flush()
    return lines


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    missing = [f for files in CARTRIDGES.values() for f in files if not (DATS / f"{f}.dat").exists()]
    if missing:
        print("Missing DATs in build/no-intro:", ", ".join(missing)); return 1
    for system, files in CARTRIDGES.items():
        lines = [line for f in files for line in cartridge_lines(DATS / f"{f}.dat")]
        print(f"{system}: {write(system, lines)} entries")
    if GAME_INDEX.exists(): print(f"ps2: {write('ps2', ps2_lines())} entries")
    else: print("ps2: skipped, no", GAME_INDEX)
    return 0


if __name__ == "__main__":
    sys.exit(main())
