extends RefCounted
## Folder names guide discovery; file contents/extensions still choose the core.
const ALIASES := {
	"snes":"snes","supernintendo":"snes","supernintendoentertainmentsystem":"snes","nintendosuperfamicom":"snes","supernes":"snes","superfamicom":"snes","sfc":"snes",
	"nes":"nes","famicom":"nes","nintendoentertainmentsystem":"nes",
	"megadrive":"megadrive","genesis":"megadrive","segagenesis":"megadrive","segamegadrive":"megadrive","gen":"megadrive","md":"megadrive",
	"mastersystem":"mastersystem","segamastersystem":"mastersystem","sms":"mastersystem",
	"gamegear":"gamegear","segagamegear":"gamegear","gg":"gamegear",
	"gameboy":"gameboy","gb":"gameboy","gbc":"gameboy","gameboycolor":"gameboy",
	"gba":"gba","gameboyadvance":"gba","advance":"gba",
	"pcengine":"pcengine","pce":"pcengine","turbografx":"pcengine","turbografx16":"pcengine","tg16":"pcengine",
	"segacd":"segacd","megacd":"segacd",
	"atari2600":"atari2600","atarivcs":"atari2600","vcs":"atari2600","2600":"atari2600","atari":"atari2600",
	"atarilynx":"atarilynx","lynx":"atarilynx",
	"ngpc":"ngpc","ngp":"ngpc","neogeopocket":"ngpc","neogeopocketcolor":"ngpc","neopocketcolor":"ngpc",
	"vectrex":"vectrex"}
const UNSUPPORTED := ["32x","3do","amiga","amiga600","amiga1200","amigacd32","amstradcpc","arcade","atari5200","atari7800","atarijaguar","atarist","atomiswave","c64","cdi","colecovision","dreamcast","fbneo","fds","gamecube","gc","intellivision","mame","mame2003","mame2010","mame2015","mame2016","mamecurrent","model2","model3","msx","msx2","n3ds","n64","nintendo3ds","nintendods","nintendo64","naomi","nds","neogeo","neogeocd","odyssey2","pc","pcenginecd","pcfx","pico8","ports","ps1","ps2","ps3","ps4","psp","psvita","psx","playstation","playstation2","playstation3","saturn","scummvm","sega32x","supergrafx","switch","tgcd","wii","wiiu","wonderswan","wonderswancolor","xbox","xbox360","zx81","zxspectrum"]

static func key(name: String) -> String:
	return name.to_lower().replace(" ","").replace("-","").replace("_","")

static func system(name: String) -> String:
	return ALIASES.get(key(name),"")

static func unsupported(name: String) -> bool:
	return key(name) in UNSUPPORTED
