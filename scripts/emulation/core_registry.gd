extends RefCounted
## Cartridge-only support. Ambiguous .bin files require a Sega ROM header.
const SYSTEMS := {
	"snes": {"name":"SNES", "core":"snes9x", "extensions":["sfc","smc","swc","fig"], "aspect":4.0/3.0},
	"nes": {"name":"NES", "core":"nestopia", "extensions":["nes","unf","unif"], "aspect":4.0/3.0},
	"megadrive": {"name":"Mega Drive", "core":"genesis_plus_gx", "extensions":["md","gen","smd"], "aspect":4.0/3.0},
	"mastersystem": {"name":"Master System", "core":"genesis_plus_gx", "extensions":["sms"], "aspect":4.0/3.0},
	"gamegear": {"name":"Game Gear", "core":"genesis_plus_gx", "extensions":["gg"], "aspect":10.0/9.0}
}

static func identify(path: String) -> String:
	var extension := path.get_extension().to_lower()
	for system in SYSTEMS:
		if extension != "md" and extension in SYSTEMS[system].extensions: return system
	# .md also means Markdown, so do not list arbitrary documentation as ROMs.
	if extension in ["bin", "md"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_length() >= 0x104:
			file.seek(0x100)
			if file.get_buffer(4).get_string_from_ascii() == "SEGA": return "megadrive"
	return ""

static func core_path(system: String) -> String:
	var override := OS.get_environment("RETROCRT_CORE")
	if not override.is_empty(): return override
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	return base.path_join("cores/" + SYSTEMS[system].core + "_libretro." + ("dll" if OS.get_name()=="Windows" else "so"))

static func controls(system: String) -> String:
	match system:
		"nes": return "NES: bottom = B, right = A; left/top = turbo B/A. Back = Select."
		"megadrive": return "Mega Drive: left/bottom/right = A/B/C; L1/top/R1 = X/Y/Z. Back = Mode."
		"mastersystem", "gamegear": return "Sega: bottom = button 1, right = button 2. Start = Pause/Start."
	return "SNES: bottom/right/left/top = B/A/Y/X. L1/R1 = L/R. Back = Select."
