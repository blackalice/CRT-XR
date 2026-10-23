extends RefCounted
## Cartridge-first support. Ambiguous .bin files require a Sega header; .cue files resolve their first image.
## Cartridges may also sit alone in a ZIP; Sega CD discs may be CHD files in a Sega CD folder.
## Systems with a "bios_any" list need one of those files in the bios folder next to the application.
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
	"vectrex": {"name":"Vectrex", "core":"vecx", "extensions":["vec"], "aspect":4.0/3.0}
}

static func identify(path: String) -> String:
	var extension := path.get_extension().to_lower()
	if extension == "cue": return disc_identify(path)
	if extension == "zip": return archive_game(path).get("system", "")
	# A CHD's sectors are compressed, so its console folder says what it holds.
	if extension == "chd": return "segacd" if folder_system(path) == "segacd" else ""
	var system := extension_system(extension)
	if not system.is_empty(): return system
	# .md also means Markdown, so do not list arbitrary documentation as ROMs.
	if extension in ["bin", "md"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null: return header_system(file.get_buffer(0x110), extension)
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
## none. Discs are never read from ZIPs: they would be unpacked whole.
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
	archive_cache[path] = {"stamp": stamp, "game": game}
	return game

## Hashes of plain files by path, with the size and modified time they were
## made at: menus ask for a game's resume point on every redraw.
static var hash_cache := {}

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
	if extension != "zip":
		var stamp := [FileAccess.get_modified_time(path), FileAccess.get_size(path)]
		var known: Dictionary = hash_cache.get(path, {})
		if known.get("stamp") != stamp: known = {"stamp": stamp, "sha256": FileAccess.get_sha256(path)}; hash_cache[path] = known
		return known.sha256
	var game := archive_game(path)
	if game.is_empty(): return ""
	if not game.has("sha256"):
		var bytes := Archive.read(path, game.entry)
		if bytes.is_empty(): return ""
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		game["sha256"] = hashing.finish().hex_encode()
	return game.sha256

## A file a core can open: the game itself, or its cartridge unpacked from a
## ZIP into the content cache. "" when it cannot be unpacked.
static func content_file(path: String) -> String:
	if path.get_extension().to_lower() != "zip": return path
	var game := archive_game(path)
	return "" if game.is_empty() else Archive.extract(path, game.entry)

static func disc_identify(cue_path: String) -> String:
	var text := FileAccess.get_file_as_string(cue_path)
	for line in text.split("\n"):
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
		var image := FileAccess.open(cue_path.get_base_dir().path_join(name).simplify_path(), FileAccess.READ)
		var found := image != null and tag_at(image.get_buffer(0x110), 0x100, "SEGADISCSYSTEM")
		if image != null: image.close()
		# The first image decides; a PlayStation cue stays an unsupported disc.
		return "segacd" if found else ""
	return ""

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
	return ""

static func bios_satisfied(system: String) -> bool:
	var names: Array = SYSTEMS[system].get("bios_any", [])
	if names.is_empty(): return true
	for name in names:
		if not bios_file(name).is_empty(): return true
	return false

static func stage_bios(system: String, destination: String) -> void:
	for name in SYSTEMS[system].get("bios_any", []):
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
	return "SNES: bottom/right/left/top = B/A/Y/X. L1/R1 = L/R. Back = Select."
