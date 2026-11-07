extends RefCounted
## Cartridge-first support. Ambiguous .bin files require a Sega header; .cue files resolve their first image.
## Cartridges may also sit alone in a ZIP; Sega CD discs may be CHD files in a Sega CD folder.
## Systems with a "bios_any" list need one of those files in the bios folder next to the application;
## "bios_optional" files are staged when present but not required.
## PlayStation discs are .cue sheets, .bin/.iso images and PS1 .pbp eboots whose own
## data says PlayStation, .m3u playlists of those, or CHDs in a PlayStation folder.
## "controller" is the Libretro device in port 1; "analog" systems take the sticks
## (and leave the left stick off the D-pad); "triggers" systems take L2/R2; systems
## with "preview": false are too heavy to run a second time for input preview.
## "hardware" cores draw with OpenGL, on a thread of their own with a hidden
## context; "options" are core option values that replace the core's defaults.
const Archive = preload("res://scripts/content/rom_archive.gd")
const Folders = preload("res://scripts/content/console_folders.gd")
const DEFINITIONS := {
	"gamecube": {"name":"GameCube", "short":"GC", "core":"dolphin", "extensions":[], "aspect":4.0/3.0,
		"analog":true, "triggers":true, "preview":false, "hardware":true,
		"options":{"dolphin_efb_scale":"1", "dolphin_cpu_core":"1", "dolphin_dsp_hle":"enabled",
			"dolphin_main_cpu_thread":"enabled", "dolphin_aspect_ratio":"2", "dolphin_call_back_audio_method":"1",
			# Dolphin's own messages draw into the game picture; the room has its own.
			"dolphin_osd_enabled":"disabled"}},
	# The same Dolphin core and defaults. Port 1 is a Wii Remote with a Classic
	# Controller (RETRO_DEVICE_SUBCLASS(JOYPAD, 4)): its buttons and sticks match a
	# modern pad. Wii widescreen stays off: the picture is for a 4:3 CRT.
	"wii": {"name":"Wii", "core":"dolphin", "extensions":[], "aspect":4.0/3.0,
		"controller":(4 << 8) | 1, "analog":true, "triggers":true, "preview":false, "hardware":true,
		"options":{"dolphin_efb_scale":"1", "dolphin_cpu_core":"1", "dolphin_dsp_hle":"enabled",
			"dolphin_main_cpu_thread":"enabled", "dolphin_aspect_ratio":"2", "dolphin_call_back_audio_method":"1",
			"dolphin_osd_enabled":"disabled", "dolphin_widescreen":"disabled", "dolphin_wiimote_default_device":"frontend"}},
	# Experimental (CRT_XR_EXPERIMENTAL_PS2): LRPS2, a libretro PCSX2, on OpenGL 3.3
	# at native resolution. It needs a real BIOS: the first of "bios_any" found is
	# staged into its pcsx2/bios folder and chosen with "bios_option". Fast boot
	# skips the BIOS logo; MTVU runs VU1 on a thread of its own (the Deck has four
	# cores; the x86 default leaves it off).
	"ps2": {"name":"PlayStation 2", "short":"PS2", "core":"pcsx2", "extensions":[], "aspect":4.0/3.0,
		# LRPS2 takes the plain joypad as a DualShock 2 (pcsx2/PAD/PAD.cpp); any
		# other device, the PS1 DualShock subclass included, leaves the port empty.
		"controller":1, "analog":true, "triggers":true, "preview":false, "hardware":true,
		"bios_any":["scph39001.bin","scph70012.bin","scph77001.bin","scph90001.bin","SCPH-70004_BIOS_V12_PAL_200.BIN",
			"scph70004.bin","scph50004.bin","scph30004.bin","scph10000.bin"],
		"bios_option":"pcsx2_bios", "context_first":true,
		"options":{"pcsx2_renderer":"OpenGL", "pcsx2_upscale_multiplier":"1x (Native)", "pcsx2_fastboot":"enabled",
			"pcsx2_mtvu":"enabled"}},
	# Experimental (CRT_XR_EXPERIMENTAL_PSP): PPSSPP v1.20.4 on OpenGL at the
	# handheld's 480x272, uncropped, without duplicated frames (so the frame rate
	# is the game's). Its assets are staged as <system>/PPSSPP.
	"psp": {"name":"PlayStation Portable", "short":"PSP", "core":"ppsspp", "extensions":["cso"], "aspect":480.0/272.0,
		"analog":true, "preview":false, "hardware":true, "context_first":true,
		"core_data":{"source":"ppsspp/PPSSPP", "target":"PPSSPP", "required":["compat.ini", "ppge_atlas.zim"]},
		"options":{"ppsspp_backend":"opengl", "ppsspp_internal_resolution":"480x272", "ppsspp_cropto16x9":"disabled",
			"ppsspp_frame_duplication":"disabled", "ppsspp_cpu_core":"JIT", "ppsspp_frameskip":"disabled",
			"ppsspp_auto_frameskip":"disabled", "ppsspp_language":"English"}},
	"snes": {"name":"SNES", "core":"snes9x", "extensions":["sfc","smc","swc","fig"], "aspect":4.0/3.0},
	"nes": {"name":"NES", "core":"nestopia", "extensions":["nes","unf","unif"], "aspect":4.0/3.0},
	"megadrive": {"name":"Mega Drive", "short":"MD", "core":"genesis_plus_gx", "extensions":["md","gen","smd"], "aspect":4.0/3.0},
	"mastersystem": {"name":"Master System", "short":"SMS", "core":"genesis_plus_gx", "extensions":["sms"], "aspect":4.0/3.0},
	"gamegear": {"name":"Game Gear", "short":"GG", "core":"genesis_plus_gx", "extensions":["gg"], "aspect":10.0/9.0},
	"gameboy": {"name":"Game Boy / Color", "short":"GB/GBC", "core":"gambatte", "extensions":["gb","gbc"], "aspect":10.0/9.0},
	"gba": {"name":"Game Boy Advance", "short":"GBA", "core":"mgba", "extensions":["gba"], "aspect":240.0/160.0},
	"pcengine": {"name":"PC Engine / TurboGrafx-16", "short":"PC Engine", "core":"mednafen_pce_fast", "extensions":["pce"], "aspect":4.0/3.0},
	"segacd": {"name":"Sega CD / Mega-CD", "short":"Sega CD", "core":"genesis_plus_gx", "extensions":[], "aspect":4.0/3.0,
		"bios_any":["bios_CD_U.bin","bios_CD_E.bin","bios_CD_J.bin"]},
	"atari2600": {"name":"Atari 2600", "short":"2600", "core":"stella", "extensions":["a26"], "aspect":4.0/3.0},
	"atarilynx": {"name":"Atari Lynx", "short":"Lynx", "core":"mednafen_lynx", "extensions":["lynx"], "aspect":160.0/102.0,
		"bios_any":["lynxboot.img"]},
	"ngpc": {"name":"Neo Geo Pocket / Color", "short":"NGPC", "core":"mednafen_ngp", "extensions":["ngp","ngpc","ngc"], "aspect":16.0/15.0},
	"vectrex": {"name":"Vectrex", "core":"vecx", "extensions":["vec"], "aspect":4.0/3.0},
	# A DualShock (RETRO_DEVICE_SUBCLASS(ANALOG, 1)) stays digital until a game asks
	# for analog, so pad-only games behave as with the original controller. The core
	# has a built-in BIOS replacement; a real BIOS improves compatibility.
	"psx": {"name":"PlayStation", "short":"PS1", "core":"pcsx_rearmed", "extensions":[], "aspect":4.0/3.0,
		"controller":(2 << 8) | 5, "analog":true, "triggers":true, "preview":false,
		"bios_optional":["scph5501.bin","scph5500.bin","scph5502.bin","scph1001.bin","scph7001.bin","scph101.bin","psxonpsp660.bin","ps1_rom.bin"]},
	"dreamcast": {"name":"Dreamcast", "short":"DC", "core":"flycast", "extensions":["gdi","cdi"], "aspect":4.0/3.0,
		"analog":true, "triggers":true, "preview":false, "hardware":true,
		"bios_optional":["dc_boot.bin"],
		"options":{"reicast_internal_resolution":"640x480", "reicast_alpha_sorting":"per-triangle (normal)",
			"reicast_threaded_rendering":"disabled", "reicast_vblank_pacing":"enabled"}},
	# GLideN64 at the console's own 320x240, so the CRT draws native lines. The
	# host applies the stick deadzone, so the core's is off. Independent C-buttons
	# (alt-map) give every N64 button its own input, so controller layouts decide
	# the mapping; without it R2 is a C-button modifier and digital C is ignored.
	# The core reads all three byte orders (.z64, .v64, .n64).
	"n64": {"name":"Nintendo 64", "short":"N64", "core":"mupen64plus_next", "extensions":["z64","n64","v64"], "aspect":4.0/3.0,
		"analog":true, "triggers":true, "preview":false, "hardware":true,
		"options":{"mupen64plus-rdp-plugin":"gliden64", "mupen64plus-43screensize":"320x240", "mupen64plus-aspect":"4:3",
			"mupen64plus-astick-deadzone":"0", "mupen64plus-cpucore":"dynamic_recompiler", "mupen64plus-alt-map":"True"}}
}

## Where the console collection comes from: names and icons follow it. PAL is the base
## in DEFINITIONS; each region overrides only what differs (name, short, icon file).
const REGIONS := ["pal", "ntsc", "japan"]
const REGION_LABELS := ["PAL (Europe)", "NTSC (Americas)", "Japan"]
const REGIONAL := {
	"snes": {"ntsc":{"icon":"snes_ntsc"}, "japan":{"name":"Super Famicom", "short":"SFC"}},
	"nes": {"japan":{"name":"Famicom", "short":"FC", "icon":"famicom"}},
	"megadrive": {"pal":{"icon":"megadrive_eu"}, "japan":{"icon":"megadrive_eu"},
		"ntsc":{"name":"Genesis", "short":"GEN", "icon":"megadrive"}},
	"mastersystem": {"japan":{"name":"Mark III", "short":"Mark III", "icon":"mastersystem_jp"}},
	"pcengine": {"pal":{"name":"PC Engine"}, "japan":{"name":"PC Engine"},
		"ntsc":{"name":"TurboGrafx-16", "short":"TG-16", "icon":"turbografx"}},
	"segacd": {"pal":{"name":"Mega-CD", "short":"Mega-CD", "icon":"megacd"}, "japan":{"name":"Mega-CD", "short":"Mega-CD", "icon":"megacd"},
		"ntsc":{"name":"Sega CD", "short":"Sega CD"}},
	"dreamcast": {"pal":{"icon":"dreamcast_blue"}, "ntsc":{"icon":"dreamcast_blue"}}
}
static var region := "pal"

static var SYSTEMS: Dictionary = available_systems()

## Names and icons for a region; run again to switch. Mutates SYSTEMS in place so
## everything reading a console's name, short or icon follows.
static func apply_region(id: String) -> void:
	region = id if id in REGIONS else "pal"
	for system in SYSTEMS:
		var spec: Dictionary = SYSTEMS[system]
		var base: Dictionary = DEFINITIONS[system]
		spec["name"] = base.name
		if base.has("short"): spec["short"] = base.short
		else: spec.erase("short")
		spec["icon"] = base.get("icon", system)
		for key in REGIONAL.get(system, {}).get(region, {}): spec[key] = REGIONAL[system][region][key]

static func available_systems() -> Dictionary:
	var systems := DEFINITIONS.duplicate(true)
	for console in Folders.EXPERIMENTAL:
		if not Folders.experimental_enabled(console): systems.erase(console)
	return systems

static func identify(path: String) -> String:
	var extension := path.get_extension().to_lower()
	if extension in ["iso", "gcm", "rvz", "wia", "wbfs"]:
		var console := nintendo_disc(path)
		if not console.is_empty(): return console if SYSTEMS.has(console) else ""
	if extension == "cue": return disc_identify(path)
	if extension == "m3u": return playlist_identify(path)
	if extension == "pbp":
		if psx_eboot(path): return "psx"
		return "psp" if SYSTEMS.has("psp") and psp_eboot(path) else ""
	if extension == "zip": return archive_game(path).get("system", "")
	# A CHD's sectors are compressed, so its console folder says what it holds.
	if extension == "chd":
		var folder := folder_system(path)
		return folder if folder in ["segacd", "psx", "dreamcast", "ps2", "psp"] else ""
	var system := extension_system(extension)
	if not system.is_empty(): return system
	# .md also means Markdown, so do not list arbitrary documentation as ROMs.
	if extension in ["bin", "md"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			system = header_system(file.get_buffer(0x110), extension)
			if system.is_empty() and extension == "bin" and psx_disc(file): system = "psx"
			return system
	if extension == "iso": return sony_disc(FileAccess.open(path, FileAccess.READ))
	return ""

## PlayStation, PlayStation 2 or PSP from an ISO's volume, or "" (also when that
## console is not enabled).
static func sony_disc(file: FileAccess) -> String:
	if psx_disc(file): return "psx"
	if SYSTEMS.has("ps2") and ps2_disc(file): return "ps2"
	if SYSTEMS.has("psp") and psp_disc(file): return "psp"
	return ""

static func extension_system(extension: String) -> String:
	for system in SYSTEMS:
		if extension != "md" and extension in SYSTEMS[system].extensions: return system
	return ""

## Mega Drive or Sega CD from the header at 0x100, for .bin and .md files.
static func header_system(header: PackedByteArray, extension: String) -> String:
	if header.size() < 0x104: return ""
	if extension == "bin" and tag_at(header, 0x100, "SEGADISCSYSTEM"): return "segacd"
	if not tag_at(header, 0x100, "SEGA"): return ""
	# Genesis Plus GX has no 32X hardware; those images would boot to a black screen.
	return "" if tag_at(header, 0x100, "SEGA 32X") else "megadrive"

static func tag_at(header: PackedByteArray, offset: int, tag: String) -> bool:
	if header.size() < offset + tag.length(): return false
	return header.slice(offset, offset + tag.length()).get_string_from_ascii() == tag

## The console named by the nearest folder above a file, or "".
static func folder_system(path: String) -> String:
	var folder := path.get_base_dir()
	for depth in range(4):
		var system := Folders.system(folder.get_file())
		if not system.is_empty() or folder.get_base_dir() == folder: return system
		folder = folder.get_base_dir()
	return ""

## Archive lookups by path, with the modified time they were made at: scans,
## the browser and menus ask about the same ZIPs often.
static var archive_cache := {}

## The cartridge inside a ZIP as {system, entry, size}, or {} when it holds
## none. A PlayStation disc ZIP (its cue and tracks, or one image) in a
## PlayStation folder is {system, entry, size, disc: true}: it is unpacked whole
## before play. Other discs are not read from ZIPs.
static func archive_game(path: String) -> Dictionary:
	var stamp := FileAccess.get_modified_time(path)
	var cached: Dictionary = archive_cache.get(path, {})
	if cached.get("stamp", -1) == stamp: return cached.game
	var game := {}
	for entry in Archive.entries(path):
		var extension: String = entry.name.get_extension().to_lower()
		var system := extension_system(extension)
		if system.is_empty() and extension in ["bin", "md"] and entry.size <= Archive.HEADER_LIMIT:
			system = header_system(Archive.read(path, entry.name).slice(0, 0x110), extension)
			if system == "segacd": system = ""
		if not system.is_empty() and entry.size <= Archive.PLAY_LIMIT:
			game = {"system": system, "entry": entry.name, "size": entry.size}
			break
	if game.is_empty(): game = archived_disc(path)
	archive_cache[path] = {"stamp": stamp, "game": game}
	return game

## A disc in a ZIP, judged by its folder like a CHD: its tracks are compressed.
## The cue leads; a ZIP holding just one image plays that image.
static func archived_disc(path: String) -> Dictionary:
	if folder_system(path) != "psx": return {}
	var items := Archive.entries(path)
	var total := 0
	for item in items: total += item.size
	for wanted in ["cue", "pbp", "iso", "bin"]:
		for item in items:
			if item.name.get_extension().to_lower() == wanted and (wanted == "cue" or items.size() == 1):
				return {"system": "psx", "entry": item.name, "size": total, "disc": true}
	return {}

## Hashes of plain files by path, with the size and modified time they were
## made at: menus ask for a game's resume point on every redraw.
static var hash_cache := {}
const LARGE_IMAGE := 64 * 1024 * 1024

## SHA-256 naming the game's saves: of the file; for a ZIP, of the cartridge
## inside, so saves are shared with the same game unzipped; for a CHD, of its
## header, which carries a SHA-1 of the whole disc, so a 300 MB+ image is not
## read end to end on the main thread.
static func content_hash(path: String) -> String:
	var extension := path.get_extension().to_lower()
	if extension == "chd":
		var disc := FileAccess.open(path, FileAccess.READ)
		if disc == null: return ""
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(disc.get_buffer(4096))
		return hashing.finish().hex_encode()
	# PlayStation images run to hundreds of megabytes: their opening megabyte holds
	# the volume and boot data that tell discs apart, and the size goes in too.
	if extension in ["pbp", "iso", "cdi", "gcm", "rvz", "wia", "wbfs", "cso"] or (extension == "bin" and FileAccess.get_size(path) > LARGE_IMAGE and identify(path) == "psx"):
		var image := FileAccess.open(path, FileAccess.READ)
		if image == null: return ""
		var sampled := HashingContext.new()
		sampled.start(HashingContext.HASH_SHA256)
		sampled.update(var_to_bytes(image.get_length()))
		sampled.update(image.get_buffer(1024 * 1024))
		return sampled.finish().hex_encode()
	if extension != "zip":
		var stamp := [FileAccess.get_modified_time(path), FileAccess.get_size(path)]
		var known: Dictionary = hash_cache.get(path, {})
		if known.get("stamp") != stamp: known = {"stamp": stamp, "sha256": FileAccess.get_sha256(path)}; hash_cache[path] = known
		return known.sha256
	var game := archive_game(path)
	if game.is_empty(): return ""
	# A disc ZIP's directory already carries each track's CRC-32 and size.
	if game.get("disc", false) and not game.has("sha256"):
		var listing := HashingContext.new()
		listing.start(HashingContext.HASH_SHA256)
		for item in Archive.entries(path): listing.update(("%s|%08x|%d\n" % [item.name.get_file(), item.crc, item.size]).to_utf8_buffer())
		game["sha256"] = listing.finish().hex_encode()
	if not game.has("sha256"):
		var bytes := Archive.read(path, game.entry)
		if bytes.is_empty(): return ""
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		game["sha256"] = hashing.finish().hex_encode()
	return game.sha256

## A file a core can open: the game itself, or its cartridge unpacked from a
## ZIP into the content cache. "" when it cannot be unpacked, or for a disc ZIP
## that has not been unpacked yet (see needs_unpacking).
static func content_file(path: String) -> String:
	if path.get_extension().to_lower() != "zip": return path
	var game := archive_game(path)
	if game.is_empty(): return ""
	if game.get("disc", false): return Archive.unpacked_disc(path, game.entry)
	return Archive.extract(path, game.entry)

## A disc ZIP whose files are not yet in the content cache: too large to unpack
## while the view waits, so the caller unpacks it in the background first.
static func needs_unpacking(path: String) -> bool:
	if path.get_extension().to_lower() != "zip": return false
	var game := archive_game(path)
	return game.get("disc", false) and Archive.unpacked_disc(path, game.entry).is_empty()

## The images a cue sheet names, as full paths, in order.
static func cue_files(cue_path: String) -> Array[String]:
	var files: Array[String] = []
	for line in FileAccess.get_file_as_string(cue_path).split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.to_upper().begins_with("FILE"): continue
		var name := ""
		var quote := trimmed.find("\"")
		if quote >= 0:
			var closing := trimmed.find("\"", quote + 1)
			if closing < 0: continue
			name = trimmed.substr(quote + 1, closing - quote - 1)
		else:
			var words := trimmed.split(" ", true)
			if words.size() < 2: continue
			name = words[1]
		files.append(cue_path.get_base_dir().path_join(name).simplify_path())
	return files

static func disc_identify(cue_path: String) -> String:
	var files := cue_files(cue_path)
	if files.is_empty(): return ""
	# The first image (the data track) decides.
	var image := FileAccess.open(files[0], FileAccess.READ)
	if image == null: return ""
	if tag_at(image.get_buffer(0x110), 0x100, "SEGADISCSYSTEM"): return "segacd"
	return sony_disc(image)

## The discs an .m3u playlist lists, as full paths; comments and blank lines skipped.
static func playlist_files(m3u_path: String) -> Array[String]:
	var files: Array[String] = []
	for line in FileAccess.get_file_as_string(m3u_path).split("\n"):
		var name := line.strip_edges()
		if name.is_empty() or name.begins_with("#"): continue
		files.append(name if name.is_absolute_path() else m3u_path.get_base_dir().path_join(name).simplify_path())
	return files

## A playlist of matching PlayStation or Dreamcast discs; reject mixed systems.
static func playlist_identify(m3u_path: String) -> String:
	var files := playlist_files(m3u_path)
	if files.is_empty() or files[0].get_extension().to_lower() in ["m3u", "zip"]: return ""
	var system := identify(files[0])
	for file in files:
		if file.get_extension().to_lower() in ["m3u", "zip"] or identify(file) != system: return ""
	return system if system in ["psx", "dreamcast", "gamecube", "wii", "ps2"] else ""

## Files a cue sheet or playlist among paths already stands for, so a game appears
## once rather than as its cue, its tracks and each disc of its playlist.
static func gdi_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var pattern := RegEx.new()
	pattern.compile('^[0-9]+\\s+[0-9]+\\s+[0-9]+\\s+[0-9]+\\s+(?:"([^"\\r\\n]+)"|([^\\s]+))\\s+[0-9]+\\s*$')
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var found := pattern.search(line.strip_edges())
		if found != null:
			var name := found.get_string(1) if not found.get_string(1).is_empty() else found.get_string(2)
			files.append(path.get_base_dir().path_join(name).simplify_path())
	return files

static func playlist_members(paths: Array) -> Dictionary:
	var members := {}
	for path in paths:
		var extension: String = path.get_extension().to_lower()
		if extension == "cue":
			for file in cue_files(path): members[file] = true
		elif extension == "gdi":
			for file in gdi_files(path): members[file] = true
		elif extension == "m3u" and not playlist_identify(path).is_empty():
			for file in playlist_files(path):
				members[file] = true
				if file.get_extension().to_lower() == "gdi":
					for track in gdi_files(file): members[track] = true
	return members

## Sector layouts of disc images: raw 2352-byte sectors (Mode 2, then Mode 1),
## then plain 2048-byte ISO sectors, each as [sector size, data offset].
const DISC_LAYOUTS := [[2352, 24], [2352, 16], [2048, 0]]

## ISO/GCM carry a big-endian GameCube magic at 0x1c, Wii discs theirs at 0x18.
## WIA/RVZ retain the disc header uncompressed at 0x58 and declare the disc type
## (1 GameCube, 2 Wii) at 0x48 (Dolphin docs/WiaAndRvz.md). WBFS keeps the Wii
## disc header at 0x200. Neither a folder name nor the extension establishes the console.
const GAMECUBE_MAGIC := [0xc2, 0x33, 0x9f, 0x3d]
const WII_MAGIC := [0x5d, 0x1c, 0x9e, 0xa3]

## "gamecube", "wii" or "" from a disc image's header.
static func nintendo_disc(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var extension := path.get_extension().to_lower()
	var header := file.get_buffer(0x220)
	var offset := 0
	var declared := 0
	if extension in ["rvz", "wia"]:
		var expected := PackedByteArray([0x52, 0x56, 0x5a, 1]) if extension == "rvz" else PackedByteArray([0x57, 0x49, 0x41, 1])
		if header.size() < 0xd8 or header.slice(0, 4) != expected: return ""
		declared = big_u32(header, 0x48)
		offset = 0x58
	elif extension == "wbfs":
		if not tag_at(header, 0, "WBFS"): return ""
		offset = 0x200
	if header.size() < offset + 0x20: return ""
	var gamecube := header.slice(offset + 0x1c, offset + 0x20) == PackedByteArray(GAMECUBE_MAGIC)
	var wii := header.slice(offset + 0x18, offset + 0x1c) == PackedByteArray(WII_MAGIC)
	# The declared type and the embedded magic must agree.
	if wii and not gamecube and declared in [0, 2]: return "wii"
	if gamecube and not wii and declared in [0, 1] and extension != "wbfs": return "gamecube"
	return ""

static func big_u32(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]

static func gamecube_disc(path: String) -> bool:
	return nintendo_disc(path) == "gamecube"

static func disc_sector(file: FileAccess, layout: Array, sector: int) -> PackedByteArray:
	var offset: int = sector * layout[0] + layout[1]
	if offset + 2048 > file.get_length(): return PackedByteArray()
	file.seek(offset)
	return file.get_buffer(2048)

## A PlayStation disc: its ISO 9660 volume names the PLAYSTATION system. PS2 discs
## share that name, so one whose SYSTEM.CNF boots with BOOT2 is not one.
static func psx_disc(file: FileAccess) -> bool:
	if file == null: return false
	for layout in DISC_LAYOUTS:
		var volume := disc_sector(file, layout, 16)
		if volume.size() < 2048 or not tag_at(volume, 1, "CD001") or not tag_at(volume, 8, "PLAYSTATION"): continue
		return not system_cnf(file, layout, volume).contains("BOOT2")
	return false

## The text of SYSTEM.CNF in the disc's root directory, or "".
static func system_cnf(file: FileAccess, layout: Array, volume: PackedByteArray) -> String:
	var root := volume.decode_u32(156 + 2)
	var length := mini(volume.decode_u32(156 + 10), 4 * 2048)
	for index in range(ceili(length / 2048.0)):
		var sector := disc_sector(file, layout, root + index)
		var at := 0
		while at + 33 < sector.size():
			var size := sector[at]
			if size == 0: break
			var name := sector.slice(at + 33, at + 33 + sector[at + 32]).get_string_from_ascii()
			if name.to_upper().begins_with("SYSTEM.CNF"):
				return disc_sector(file, layout, sector.decode_u32(at + 2)).get_string_from_ascii()
			at += size
	return ""

## A PlayStation 2 disc: a PLAYSTATION volume whose SYSTEM.CNF boots with BOOT2.
static func ps2_disc(file: FileAccess) -> bool:
	if file == null: return false
	for layout in DISC_LAYOUTS:
		var volume := disc_sector(file, layout, 16)
		if volume.size() < 2048 or not tag_at(volume, 1, "CD001") or not tag_at(volume, 8, "PLAYSTATION"): continue
		return system_cnf(file, layout, volume).contains("BOOT2")
	return false

## A PSP UMD image: its ISO 9660 volume names the PSP GAME system.
static func psp_disc(file: FileAccess) -> bool:
	if file == null: return false
	var volume := disc_sector(file, [2048, 0], 16)
	return volume.size() >= 2048 and tag_at(volume, 1, "CD001") and tag_at(volume, 8, "PSP GAME")

## A PSP eboot: a .pbp that is not a PlayStation one.
static func psp_eboot(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	return file != null and file.get_length() >= 0x28 and file.get_buffer(4) == PackedByteArray([0, 0x50, 0x42, 0x50])

## A PlayStation eboot (a PSP-format .pbp holding a PS1 disc): its DATA.PSAR
## starts with PSISOIMG (one disc) or PSTITLEIMG (several). PSP games do not.
static func psx_eboot(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 0x28: return false
	var header := file.get_buffer(0x28)
	if header.slice(0, 4) != PackedByteArray([0, 0x50, 0x42, 0x50]): return false
	var data := header.decode_u32(0x24)
	if data + 12 > file.get_length(): return false
	file.seek(data)
	var magic := file.get_buffer(12).get_string_from_ascii()
	return magic.begins_with("PSISOIMG") or magic.begins_with("PSTITLEIMG")

static func core_path(system: String) -> String:
	var override := OS.get_environment("CRT_XR_CORE")
	if override.is_empty(): override=OS.get_environment("RETROCRT_CORE")
	if not override.is_empty(): return override
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	return base.path_join("cores/" + SYSTEMS[system].core + "_libretro." + ("dll" if OS.get_name()=="Windows" else "so"))

## Cores whose audio survives the same-instance preview (save/run/restore) unchanged.
## Only used when Separate preview core is off: the default second copy of the core
## is never rewound, so its audio is identical to having no preview at all.
## Gambatte, Genesis Plus GX and NeoPop keep audio buffers outside their save states,
## so each restore drops or repeats samples: a buzz at the frame rate. Nestopia and
## mGBA show milder frame-edge artefacts; the remaining cores are unmeasured.
## Add a core only after tests/preview_audio_test.py passes with a game that has sound.
const PREVIEW_SAFE_CORES := ["snes9x"]

static func preview_safe(system: String) -> bool:
	return SYSTEMS.has(system) and SYSTEMS[system].core in PREVIEW_SAFE_CORES

## The user's main ROM folder, kept current by the app; its EmuDeck-style sibling
## bios folder is searched too.
static var library_root := ""

## Folders searched for BIOS files, in order: CRT_XR_BIOS; a bios folder beside the
## application; on the Steam Deck install, ~/Applications/CRT-XR/bios (release
## folders are replaced on update, so files beside the app would not survive);
## and the bios folder next to the ROM folder (EmuDeck keeps roms and bios side by
## side). The host gives cores one system/save directory, so the system's own BIOS
## files are staged there. Only declared names are copied: shared emulator bios
## folders can be huge.
static func bios_sources() -> Array[String]:
	var folders: Array[String] = []
	var override := OS.get_environment("CRT_XR_BIOS")
	if not override.is_empty(): folders.append(override)
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	folders.append(base.path_join("bios"))
	if base.get_base_dir().get_file() == "releases": folders.append(base.get_base_dir().get_base_dir().path_join("bios"))
	if not library_root.is_empty(): folders.append(library_root.get_base_dir().path_join("bios"))
	return folders

## Where to tell users to put BIOS files: a folder that survives app updates.
static func preferred_bios_folder() -> String:
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	if base.get_base_dir().get_file() == "releases": return base.get_base_dir().get_base_dir().path_join("bios")
	return base.path_join("bios")

static func bios_file(name: String) -> String:
	for source_folder in bios_sources():
		var folder: String = source_folder.path_join(name.get_base_dir())
		var filename := name.get_file()
		if FileAccess.file_exists(folder.path_join(filename)): return folder.path_join(filename)
		# Dumps are named SCPH5501.BIN as often as scph5501.bin, and the Steam
		# Deck's file system tells the two apart.
		if not DirAccess.dir_exists_absolute(folder): continue
		for file in DirAccess.get_files_at(folder):
			if file.to_lower() == filename.to_lower(): return folder.path_join(file)
	return ""

## The first required BIOS file present, by its staged name, or "".
static func first_bios(system: String) -> String:
	for name in SYSTEMS[system].get("bios_any", []):
		if not bios_file(name).is_empty(): return name
	return ""

static func bios_satisfied(system: String) -> bool:
	var names: Array = SYSTEMS[system].get("bios_any", [])
	if names.is_empty(): return true
	for name in names:
		if not bios_file(name).is_empty(): return true
	return false

## Where in the system directory a core looks for its BIOS.
const BIOS_FOLDERS := {"dreamcast": "dc", "ps2": "pcsx2/bios"}

static func stage_bios(system: String, destination: String) -> void:
	if system in BIOS_FOLDERS:
		destination = destination.path_join(BIOS_FOLDERS[system])
		DirAccess.make_dir_recursive_absolute(destination)
	var names: Array = SYSTEMS[system].get("bios_any", []) + SYSTEMS[system].get("bios_optional", [])
	# A core that is told which BIOS to use gets only that one.
	if SYSTEMS[system].has("bios_option"): names = [first_bios(system)] if not first_bios(system).is_empty() else []
	for name in names:
		var source := bios_file(name)
		if source.is_empty() and system == "dreamcast": source = bios_file("dc/" + name)
		if source.is_empty(): continue
		var target := destination.path_join(name)
		# Refresh a staged copy the user has since replaced.
		if FileAccess.file_exists(target) and FileAccess.get_sha256(target) == FileAccess.get_sha256(source): continue
		var bytes := FileAccess.get_file_as_bytes(source)
		if bytes.is_empty(): continue
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file != null:
			file.store_buffer(bytes)
			file.close()
