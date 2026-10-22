extends RefCounted
## Cartridge-first support. Ambiguous .bin files require a Sega header; .cue files resolve their first image.
## Systems with a "bios_any" list need one of those files in the bios folder next to the application.
const SYSTEMS := {
	"snes": {"name":"SNES", "core":"snes9x", "extensions":["sfc","smc","swc","fig"], "aspect":4.0/3.0},
	"nes": {"name":"NES", "core":"nestopia", "extensions":["nes","unf","unif"], "aspect":4.0/3.0},
	"megadrive": {"name":"Mega Drive", "core":"genesis_plus_gx", "extensions":["md","gen","smd"], "aspect":4.0/3.0},
	"mastersystem": {"name":"Master System", "core":"genesis_plus_gx", "extensions":["sms"], "aspect":4.0/3.0},
	"gamegear": {"name":"Game Gear", "core":"genesis_plus_gx", "extensions":["gg"], "aspect":10.0/9.0},
	"gameboy": {"name":"Game Boy / Color", "core":"gambatte", "extensions":["gb","gbc"], "aspect":10.0/9.0},
	"gba": {"name":"Game Boy Advance", "core":"mgba", "extensions":["gba"], "aspect":240.0/160.0},
	"pcengine": {"name":"PC Engine / TurboGrafx-16", "core":"mednafen_pce_fast", "extensions":["pce"], "aspect":4.0/3.0},
	"segacd": {"name":"Sega CD / Mega-CD", "core":"genesis_plus_gx", "extensions":[], "aspect":4.0/3.0,
		"bios_any":["bios_CD_U.bin","bios_CD_E.bin","bios_CD_J.bin"]},
	"atari2600": {"name":"Atari 2600", "core":"stella", "extensions":["a26"], "aspect":4.0/3.0},
	"atarilynx": {"name":"Atari Lynx", "core":"mednafen_lynx", "extensions":["lynx"], "aspect":160.0/102.0,
		"bios_any":["lynxboot.img"]},
	"ngpc": {"name":"Neo Geo Pocket / Color", "core":"mednafen_ngp", "extensions":["ngp","ngpc","ngc"], "aspect":16.0/15.0},
	"vectrex": {"name":"Vectrex", "core":"vecx", "extensions":["vec"], "aspect":4.0/3.0}
}

static func identify(path: String) -> String:
	var extension := path.get_extension().to_lower()
	if extension == "cue": return disc_identify(path)
	for system in SYSTEMS:
		if extension != "md" and extension in SYSTEMS[system].extensions: return system
	# .md also means Markdown, so do not list arbitrary documentation as ROMs.
	if extension in ["bin", "md"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_length() >= 0x104:
			if extension == "bin" and tag_at(file, 0x100, "SEGADISCSYSTEM"): return "segacd"
			file.seek(0x100)
			if file.get_buffer(4).get_string_from_ascii() == "SEGA":
				# Genesis Plus GX has no 32X hardware; those images would boot to a black screen.
				if tag_at(file, 0x100, "SEGA 32X"): return ""
				return "megadrive"
	return ""

static func tag_at(file: FileAccess, offset: int, tag: String) -> bool:
	if file.get_length() < offset + tag.length(): return false
	file.seek(offset)
	return file.get_buffer(tag.length()).get_string_from_ascii() == tag

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
		var found := image != null and tag_at(image, 0x100, "SEGADISCSYSTEM")
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
