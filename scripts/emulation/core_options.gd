extends RefCounted
## Curated options from the pinned core sources. Empty means the core/app default.
const Store = preload("res://scripts/ui/settings_store.gd")
const PATH := "user://core-options.cfg"
const OPTIONS := {
 "dreamcast": [["reicast_internal_resolution", "Internal resolution", ["Default", "960×720"], ["", "960x720"], "Default is 640×480. Higher resolutions cost more performance."], ["reicast_alpha_sorting", "Transparency", ["Default", "Fast", "Accurate"], ["", "per-strip (fast, least accurate)", "per-triangle (normal)"], "Fast sorting can cause visual glitches."], ["reicast_enable_dsp", "Audio DSP", ["Default", "Off", "On"], ["", "disabled", "enabled"], "Accurate audio effects cost more performance."]],
 "snes": [["snes9x_region", "Region", ["Automatic", "NTSC", "PAL"], ["", "ntsc", "pal"], "Incorrect regions can change game speed."], ["snes9x_reduce_sprite_flicker", "Reduce sprite flicker", ["Default", "Off", "On"], ["", "disabled", "enabled"], "Can cause visual glitches in some games."]],
 "nes": [["nestopia_nospritelimit", "Remove sprite limit", ["Default", "Off", "On"], ["", "disabled", "enabled"], "Reduces flicker but can cause visual glitches."]],
 "megadrive": [["genesis_plus_gx_region_detect", "Region", ["Automatic", "USA", "Europe", "Japan"], ["", "ntsc-u", "pal", "ntsc-j"], "Incorrect regions can change game speed."], ["genesis_plus_gx_no_sprite_limit", "Remove sprite limit", ["Default", "Off", "On"], ["", "disabled", "enabled"], "Can cause visual glitches."]],
 "gameboy": [["gambatte_gbc_color_correction", "Colour correction", ["Default", "Game Boy Color", "Always", "Off"], ["", "GBC only", "always", "disabled"], "Approximates the original screen colours."]],
 "gba": [["mgba_color_correction", "Colour correction", ["Default", "Off", "GBA", "Game Boy Color", "Automatic"], ["", "OFF", "GBA", "GBC", "Auto"], "Approximates handheld screen colours."]],
 "ngpc": [["ngp_language", "Language", ["Default", "English", "Japanese"], ["", "english", "japanese"], "Selects the console language."]],
 "psx": [["pcsx_rearmed_dithering", "Dithering", ["Default", "Off", "On", "Force"], ["", "disabled", "enabled", "force"], "Controls the PlayStation colour dithering pattern."]],
 "n64": [["mupen64plus-43screensize", "Internal resolution", ["Default", "640×480", "960×720"], ["", "640x480", "960x720"], "Higher resolutions cost more performance and change the CRT appearance."]]
}
static func group(system: String) -> String:
 return "megadrive" if system in ["mastersystem", "gamegear", "segacd"] else system
static func definitions(system: String) -> Array:
 return OPTIONS.get(group(system), [])
static func section(system: String, game: String = "") -> String:
 return ("game." + game + "." if not game.is_empty() else "console.") + system
static func read_value(system: String, game: String, key: String) -> String:
 var cfg := Store.new().read(PATH)
 var value = cfg.get_value(section(system, game), key, "")
 return value if value is String else ""
static func write_value(system: String, game: String, key: String, value: String) -> Error:
 var cfg := Store.new().read(PATH)
 if value.is_empty():
  if cfg.has_section_key(section(system, game), key): cfg.erase_section_key(section(system, game), key)
 else: cfg.set_value(section(system, game), key, value)
 return Store.write(PATH, cfg)
static func overrides(system: String, game: String) -> Dictionary:
 var cfg := Store.new().read(PATH)
 var result := {}
 for option in definitions(system):
  var key: String = option[0]
  var value = cfg.get_value(section(system, game), key, "") if not game.is_empty() else ""
  if not value is String or value not in option[3] or value.is_empty(): value = cfg.get_value(section(system), key, "")
  if value is String and value in option[3] and not value.is_empty(): result[key] = value
 return result

## Display labels for the defaults of the pinned builds. These do not override the cores.
const DEFAULT_LABELS := {
 "reicast_internal_resolution":"640×480", "reicast_alpha_sorting":"Accurate", "reicast_enable_dsp":"On",
 "snes9x_region":"Automatic", "snes9x_reduce_sprite_flicker":"Off",
 "nestopia_nospritelimit":"Off", "genesis_plus_gx_region_detect":"Automatic",
 "genesis_plus_gx_no_sprite_limit":"Off", "gambatte_gbc_color_correction":"Game Boy Color",
 "mgba_color_correction":"Off", "ngp_language":"English", "pcsx_rearmed_dithering":"On",
 "mupen64plus-43screensize":"Default"
}
static func choice_index(system: String, game: String, definition: Array) -> int:
 return maxi(0, definition[3].find(read_value(system, game, definition[0])))
static func console_label(system: String, definition: Array) -> String:
 var index := choice_index(system, "", definition)
 return str(definition[2][index]) if index > 0 else str(DEFAULT_LABELS.get(definition[0], definition[2][0]))
