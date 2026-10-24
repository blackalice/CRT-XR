extends RefCounted
## Atomic preferences, one previous version, and type-safe recovery.
var recovered := false
var warning := ""

func read(path: String, defaults: ConfigFile = null) -> ConfigFile:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		var backup := ConfigFile.new()
		if backup.load(path + ".bak") == OK:
			config = backup
			recovered = true
			warning = "Recovered saved settings from their backup."
		else:
			config = ConfigFile.new()
			if error != ERR_FILE_NOT_FOUND: warning = "Saved settings could not be read. Using safe defaults."
	# Screen light is a global room preference, not a per-game CRT effect.
	# Preserve the old global Off choice while migrating the retired overlay key.
	if path == "user://settings.cfg" and config.has_section_key("crt","screen_spill") and not config.has_section_key("room","spill_strength"):
		config.set_value("room","spill_strength",config.get_value("crt","screen_spill"))
	# "Reduce input delay" became an Off/1-frame/2-frame choice; keep the
	# previous enabled state instead of falling back to the default.
	if path == "user://settings.cfg" and config.has_section_key("emulation","run_ahead") and config.get_value("emulation","run_ahead") is bool:
		config.set_value("emulation","run_ahead", 1 if config.get_value("emulation","run_ahead") else 0)
	migrate_view_fov(config)
	migrate_screen_glow(config)
	if defaults == null: return config
	var result := ConfigFile.new()
	for section in defaults.get_sections():
		for key in defaults.get_section_keys(section):
			var fallback = defaults.get_value(section,key)
			var value = config.get_value(section,key,fallback)
			var valid := typeof(value) == typeof(fallback)
			if typeof(fallback) in [TYPE_INT,TYPE_FLOAT]:
				valid = typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))
			if not valid: warning = "Some saved settings were invalid. Safe defaults were used."
			result.set_value(section,key,value if valid else fallback)
	return result

static func copy_sections(source: ConfigFile, target: ConfigFile, sections: PackedStringArray) -> void:
	for section in sections:
		if not source.has_section(section): continue
		for key in source.get_section_keys(section): target.set_value(section,key,source.get_value(section,key))

static func write(path: String, config: ConfigFile) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK: return error
	var previous := ConfigFile.new()
	var has_previous := previous.load(path) == OK
	if has_previous and previous.encode_to_text() == config.encode_to_text(): return OK
	error = config.save(path + ".tmp")
	if error != OK: return error
	# Only replace the backup with a valid original. Preserve recovery on corruption.
	if has_previous:
		error = previous.save(path + ".bak")
		if error != OK: return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

## Rooms saved before the screen glow was rescaled (version 2) kept their screen
## light as 0..0.4, and 0.4 lit almost nothing. The old maximum, the default, now
## means the new default (0.5); Off stays off.
const LIGHTING_VERSION := 2
static func migrate_screen_glow(config: ConfigFile) -> void:
	if not config.has_section_key("room", "spill_strength"): return
	if int(config.get_value("room", "lighting_version", 1)) >= LIGHTING_VERSION: return
	var legacy = config.get_value("room", "spill_strength")
	if legacy is float or legacy is int:
		config.set_value("room", "spill_strength", clampf(float(legacy) / 0.4 * 0.5, 0.0, 1.0))
	config.set_value("room", "lighting_version", LIGHTING_VERSION)

static func migrate_view_fov(config: ConfigFile) -> void:
	if not config.has_section_key("view","vertical_fov"): return
	var legacy = config.get_value("view","vertical_fov")
	if not (legacy is float or legacy is int) or not is_finite(float(legacy)): return
	# The former Windows preview stored its 50-degree desktop default in the
	# same slot as XR calibration. Keep custom values, split the two defaults.
	if not config.has_section_key("view","desktop_fov"):
		config.set_value("view","desktop_fov",50.0 if is_equal_approx(float(legacy),24.0) else float(legacy))
	if not config.has_section_key("view","xr_fov"):
		config.set_value("view","xr_fov",24.0 if is_equal_approx(float(legacy),50.0) else float(legacy))
