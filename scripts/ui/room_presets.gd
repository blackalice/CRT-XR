extends RefCounted
## Room presets: three built-in lighting moods and three rooms of your own.
## A room is the "room" settings section: lighting, shadows, floor and props.
## Like picture presets, choosing one first keeps a hand-tuned room ("Custom")
## on disk, so Custom can always bring it back.
const COUNT := 3
const BUILT_IN := [["warm", "Warm bedroom"], ["bright", "Bright inspection"], ["dim", "Dim XR"]]
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
func active() -> String:
	return host.room_preset_id if not host.room_preset_signature.is_empty() and host.room_preset_signature == signature() else ""

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
