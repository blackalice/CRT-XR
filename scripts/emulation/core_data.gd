extends RefCounted
## Redistributable data a core reads from its system directory (PPSSPP's assets),
## kept beside the application in core-data/ and staged into the one system/save
## directory the host gives cores. A registry entry names it with
## "core_data": {"source", "target", "required"}. Dolphin keeps its own helper.
const DolphinSupport = preload("res://scripts/emulation/dolphin_support.gd")

static func source_directory(spec: Dictionary) -> String:
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	return base.path_join("core-data").path_join(spec.core_data.source)

static func available(spec: Dictionary) -> bool:
	if not spec.has("core_data"): return true
	for name in spec.core_data.get("required", []):
		if not FileAccess.file_exists(source_directory(spec).path_join(name)): return false
	return true

static func stage(spec: Dictionary, destination: String) -> Error:
	if not spec.has("core_data"): return OK
	if not available(spec): return ERR_FILE_NOT_FOUND
	return DolphinSupport.copy_directory(source_directory(spec), destination.path_join(spec.core_data.target))
