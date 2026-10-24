extends RefCounted
## Room presets: built-in lighting moods and three rooms of your own.
## A room is the "room" settings section: lighting, shadows, floor and props.
## Like picture presets, choosing one first keeps a hand-tuned room ("Custom")
## on disk, so Custom can always bring it back.
const COUNT := 3
## Darkest first. "late" is the default room.
const BUILT_IN := [["dark", "Lights off"], ["late", "Late night"], ["dim", "Dim XR"], ["warm", "Warm bedroom"], ["bright", "Bright inspection"]]
## Every lighting value each mood sets; floor, props, sound and placement stay
## yours. The brighter the room, the less the screen's glow stands out.
const MOODS := {
	"dark": {"spill_strength": 1.0, "ambient": 0.0, "key_energy": 0.0, "fill_energy": 0.0, "warmth": 0.7, "shadow_strength": 0.6, "floor_brightness": 1.15, "fade_begin": 3.5, "fade_end": 7.0},
	"late": {"spill_strength": 0.5, "ambient": 0.05, "key_energy": 0.3, "fill_energy": 0.1, "warmth": 0.7, "shadow_strength": 0.6, "floor_brightness": 1.15, "fade_begin": 3.5, "fade_end": 7.0},
	"dim": {"spill_strength": 0.45, "ambient": 0.15, "key_energy": 2.5, "fill_energy": 0.5, "warmth": 0.8, "shadow_strength": 0.6, "floor_brightness": 0.8, "fade_begin": 3.5, "fade_end": 7.0},
	"warm": {"spill_strength": 0.35, "ambient": 0.45, "key_energy": 4.5, "fill_energy": 1.6, "warmth": 0.7, "shadow_strength": 0.6, "floor_brightness": 1.15, "fade_begin": 4.5, "fade_end": 9.0},
	"bright": {"spill_strength": 0.2, "ambient": 0.85, "key_energy": 5.0, "fill_energy": 2.3, "warmth": 0.4, "shadow_strength": 0.5, "floor_brightness": 1.25, "fade_begin": 6.0, "fade_end": 12.0},
}
const CUSTOM_PATH := "user://presets/room-custom.cfg"
var host: Node

func path(index: int) -> String:
	return "user://presets/room-%d.cfg" % index

static func exists(file: String) -> bool:
	return FileAccess.file_exists(file) or FileAccess.file_exists(file + ".bak")

func saved(index: int) -> bool:
	return exists(path(index))

func name(index: int) -> String:
	var fallback := "My room %d" % (index + 1)
	if not saved(index): return fallback
	return str(host.SettingsStore.new().read(path(index)).get_value("meta", "name", fallback))

func room_only() -> ConfigFile:
	var config := ConfigFile.new()
	host.SettingsStore.copy_sections(host.capture_settings(), config, PackedStringArray(["room"]))
	return config

func signature() -> String:
	return room_only().encode_to_text()

## The preset the room still matches ("warm", "mine.1"…), or "" once changed.
## A built-in mood is recognised by its lighting alone, so the default room reads
## as Late night and switching a prop doesn't make it Custom.
func active() -> String:
	if host.room_preset_id.begins_with("mine.") and not host.room_preset_signature.is_empty() and host.room_preset_signature == signature():
		return host.room_preset_id
	for pair in BUILT_IN:
		if matches(pair[0]): return pair[0]
	return ""

func matches(mood: String) -> bool:
	var values: Dictionary = MOODS[mood]
	for key in values:
		if not is_equal_approx(float(host.world.get(key)), float(values[key])): return false
	return true

func label(id: String) -> String:
	if id.begins_with("mine."): return name(int(id.get_slice(".", 1)))
	for pair in BUILT_IN:
		if pair[0] == id: return pair[1]
	return "Custom"

func mark(id: String) -> void:
	host.room_preset_id = id
	host.room_preset_signature = signature() if not id.is_empty() else ""

func remember_custom() -> void:
	if active().is_empty(): host.SettingsStore.write(CUSTOM_PATH, room_only())

## Puts a saved room's settings in place, checked against the live types.
func apply_file(file: String, id: String) -> void:
	var merged: ConfigFile = host.capture_settings()
	host.SettingsStore.copy_sections(host.SettingsStore.new().read(file), merged, PackedStringArray(["room"]))
	var validator := ConfigFile.new(); validator.parse(merged.encode_to_text())
	host.apply_settings(host.validated_settings(validator, host.capture_settings()))
	mark(id)

## Applies "warm", "bright", "dim", "mine.N" or "" (your custom room).
func apply(id: String) -> void:
	if id == active(): return
	remember_custom()
	if id.is_empty():
		if exists(CUSTOM_PATH): apply_file(CUSTOM_PATH, "")
	elif id.begins_with("mine."):
		var index := int(id.get_slice(".", 1))
		if saved(index): apply_file(path(index), id)
	else:
		host.room_preset(id)
		mark(id)

func save(index: int) -> Error:
	var config := room_only()
	config.set_value("meta", "name", name(index))
	var result: Error = host.SettingsStore.write(path(index), config)
	if result == OK: mark("mine.%d" % index)
	return result

func rename(index: int, value: String) -> Error:
	var title := value.strip_edges().left(32)
	if title.is_empty(): title = "My room %d" % (index + 1)
	var config: ConfigFile = host.SettingsStore.new().read(path(index))
	config.set_value("meta", "name", title)
	return host.SettingsStore.write(path(index), config)

func delete(index: int) -> void:
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(path(index) + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path(index) + suffix))
	if host.room_preset_id == "mine.%d" % index: mark("")

## The quick switch's choices: Custom, the built-in moods, then your rooms.
func choices() -> Array:
	var result: Array = [["", "Custom"]]
	for pair in BUILT_IN: result.append(pair)
	for index in range(COUNT):
		if saved(index): result.append(["mine.%d" % index, name(index)])
	return result
