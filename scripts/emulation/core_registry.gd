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
const SYSTEMS := {
	"snes": {"name":"SNES", "core":"snes9x", "extensions":["sfc","smc","swc","fig"], "aspect":4.0/3.0},
	"nes": {"name":"NES", "core":"nestopia", "extensions":["nes","unf","unif"], "aspect":4.0/3.0},
	"megadrive": {"name":"Mega Drive", "core":"genesis_plus_gx", "extensions":["md","gen","smd"], "aspect":4.0/3.0},
	"mastersystem": {"name":"Master System", "core":"genesis_plus_gx", "extensions":["sms"], "aspect":4.0/3.0},
	"gamegear": {"name":"Game Gear", "core":"genesis_plus_gx", "extensions":["gg"], "aspect":10.0/9.0},
	"gameboy": {"name":"Game Boy / Color", "core":"gambatte", "extensions":["gb","gbc"], "aspect":10.0/9.0},
	"gba": {"name":"Game Boy Advance", "core":"mgba", "extensions":["gba"], "aspect":240.0/160.0},
	"pcengine": {"name":"PC Engine / TurboGrafx-16", "short":"PC Engine", "core":"mednafen_pce_fast", "extensions":["pce"], "aspect":4.0/3.0},
	"segacd": {"name":"Sega CD / Mega-CD", "core":"genesis_plus_gx", "extensions":[], "aspect":4.0/3.0,
		"bios_any":["bios_CD_U.bin","bios_CD_E.bin","bios_CD_J.bin"]},
	"atari2600": {"name":"Atari 2600", "core":"stella", "extensions":["a26"], "aspect":4.0/3.0},
	"atarilynx": {"name":"Atari Lynx", "core":"mednafen_lynx", "extensions":["lynx"], "aspect":160.0/102.0,
		"bios_any":["lynxboot.img"]},
	"ngpc": {"name":"Neo Geo Pocket / Color", "short":"Neo Geo Pocket", "core":"mednafen_ngp", "extensions":["ngp","ngpc","ngc"], "aspect":16.0/15.0},
	"vectrex": {"name":"Vectrex", "core":"vecx", "extensions":["vec"], "aspect":4.0/3.0},
	# A DualShock (RETRO_DEVICE_SUBCLASS(ANALOG, 1)) stays digital until a game asks
	# for analog, so pad-only games behave as with the original controller. The core
	# has a built-in BIOS replacement; a real BIOS improves compatibility.
	"psx": {"name":"PlayStation", "core":"pcsx_rearmed", "extensions":[], "aspect":4.0/3.0,
		"controller":(2 << 8) | 5, "analog":true, "triggers":true, "preview":false,
		"bios_optional":["scph5501.bin","scph5500.bin","scph5502.bin","scph1001.bin","scph7001.bin","scph101.bin","psxonpsp660.bin","ps1_rom.bin"]},
	# GLideN64 at the console's own 320x240, so the CRT draws native lines. The
	# host applies the stick deadzone, so the core's is off. The core reads all
	# three byte orders (.z64, .v64, .n64).
	"n64": {"name":"Nintendo 64", "short":"N64", "core":"mupen64plus_next", "extensions":["z64","n64","v64"], "aspect":4.0/3.0,
		"analog":true, "triggers":true, "preview":false, "hardware":true,
		"options":{"mupen64plus-rdp-plugin":"gliden64", "mupen64plus-43screensize":"320x240", "mupen64plus-aspect":"4:3",
			"mupen64plus-astick-deadzone":"0", "mupen64plus-cpucore":"dynamic_recompiler"}}
}

static func identify(path: String) -> String:
	var extension := path.get_extension().to_lower()
	if extension == "cue": return disc_identify(path)
	if extension == "m3u": return playlist_identify(path)
	if extension == "pbp": return "psx" if psx_eboot(path) else ""
	if extension == "zip": return archive_game(path).get("system", "")
	# A CHD's sectors are compressed, so its console folder says what it holds.
	if extension == "chd":
		var folder := folder_system(path)
		return folder if folder in ["segacd", "psx"] else ""
	var system := extension_system(extension)
	if not system.is_empty(): return system
	# .md also means Markdown, so do not list arbitrary documentation as ROMs.
	if extension in ["bin", "md"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			system = header_system(file.get_buffer(0x110), extension)
			if system.is_empty() and extension == "bin" and psx_disc(file): system = "psx"
			return system
	if extension == "iso": return "psx" if psx_disc(FileAccess.open(path, FileAccess.READ)) else ""
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
	if extension in ["pbp", "iso"] or (extension == "bin" and FileAccess.get_size(path) > LARGE_IMAGE and identify(path) == "psx"):
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
	return "psx" if psx_disc(image) else ""

## The discs an .m3u playlist lists, as full paths; comments and blank lines skipped.
static func playlist_files(m3u_path: String) -> Array[String]:
	var files: Array[String] = []
	for line in FileAccess.get_file_as_string(m3u_path).split("\n"):
		var name := line.strip_edges()
		if name.is_empty() or name.begins_with("#"): continue
		files.append(name if name.is_absolute_path() else m3u_path.get_base_dir().path_join(name).simplify_path())
	return files

## A playlist of PlayStation discs (multi-disc games); its first disc decides.
static func playlist_identify(m3u_path: String) -> String:
	var files := playlist_files(m3u_path)
	if files.is_empty() or files[0].get_extension().to_lower() in ["m3u", "zip"]: return ""
	return "psx" if identify(files[0]) == "psx" else ""

## Files a cue sheet or playlist among paths already stands for, so a game appears
## once rather than as its cue, its tracks and each disc of its playlist.
static func playlist_members(paths: Array) -> Dictionary:
	var members := {}
	for path in paths:
		var extension: String = path.get_extension().to_lower()
		if extension == "cue":
			for file in cue_files(path): members[file] = true
		elif extension == "m3u":
			for file in playlist_files(path): members[file] = true
	return members

## Sector layouts of disc images: raw 2352-byte sectors (Mode 2, then Mode 1),
## then plain 2048-byte ISO sectors, each as [sector size, data offset].
const DISC_LAYOUTS := [[2352, 24], [2352, 16], [2048, 0]]

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
	for folder in bios_sources():
		if FileAccess.file_exists(folder.path_join(name)): return folder.path_join(name)
		# Dumps are named SCPH5501.BIN as often as scph5501.bin, and the Steam
		# Deck's file system tells the two apart.
		if not DirAccess.dir_exists_absolute(folder): continue
		for file in DirAccess.get_files_at(folder):
			if file.to_lower() == name.to_lower(): return folder.path_join(file)
	return ""

static func bios_satisfied(system: String) -> bool:
	var names: Array = SYSTEMS[system].get("bios_any", [])
	if names.is_empty(): return true
	for name in names:
		if not bios_file(name).is_empty(): return true
	return false

static func stage_bios(system: String, destination: String) -> void:
	for name in SYSTEMS[system].get("bios_any", []) + SYSTEMS[system].get("bios_optional", []):
		var source := bios_file(name)
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

static func controls(system: String) -> String:
	match system:
		"nes": return "NES: bottom = B, right = A; left/top = turbo B/A. Back = Select."
		"megadrive": return "Mega Drive: left/bottom/right = A/B/C; L1/top/R1 = X/Y/Z. Back = Mode."
		"mastersystem", "gamegear": return "Sega: bottom = button 1, right = button 2. Start = Pause/Start."
		"segacd": return "Sega CD: same layout as Mega Drive. Start = Start/Play."
		"gameboy": return "Game Boy: bottom = B, right = A. Back = Select, Start = Start."
		"gba": return "Game Boy Advance: bottom = B, right = A; L1/R1 = L/R. Back = Select, Start = Start."
		"pcengine": return "PC Engine: bottom = II, right = I; L1/R1 = V/VI on the 6-button pad. Start = Run."
		"ngpc": return "Neo Geo Pocket: bottom = A, right = B. Start = Option."
		"atarilynx": return "Atari Lynx: bottom = A, right = B; L1/R1 = Option 1/2. Start = Option."
		"atari2600": return "Atari 2600: bottom = the joystick Fire button. Start = console Reset."
		"vectrex": return "Vectrex: right = button 1, bottom = 2, top = 3, left = 4."
		"n64": return "Nintendo 64: bottom = A, left = B; right stick or right/top/L1/R1 = C-buttons. L2 = Z, R2 = R, Back = L. Left stick = the analog stick."
		"psx": return "PlayStation: bottom/right/left/top = Cross/Circle/Square/Triangle. L1/R1 and the triggers = L1/R1/L2/R2. Sticks = DualShock sticks. Back = Select."
	return "SNES: bottom/right/left/top = B/A/Y/X. L1/R1 = L/R. Back = Select."
