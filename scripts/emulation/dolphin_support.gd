extends RefCounted
## Dolphin's redistributable Sys data lives beside the core, separately from
## writable User saves. The host supplies one system/save directory, so stage
## Sys below dolphin-emu there. Never copy to User or import standalone saves.
const REQUIRED := ["codehandler.bin", "GC/dsp_coef.bin", "GC/dsp_rom.bin", "GC/font_western.bin"]

static func source_directory() -> String:
	var override := OS.get_environment("CRT_XR_DOLPHIN_SYS")
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	return override if not override.is_empty() else base.path_join("core-data/dolphin-emu/Sys")

static func available() -> bool:
	for name in REQUIRED:
		if not FileAccess.file_exists(source_directory().path_join(name)): return false
	return true

static func stage(destination: String) -> Error:
	if not available(): return ERR_FILE_NOT_FOUND
	return copy_directory(source_directory(), destination.path_join("dolphin-emu/Sys"))

static func copy_directory(source: String, destination: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(destination)
	if error != OK: return error
	for name in DirAccess.get_files_at(source):
		var original := source.path_join(name)
		var target := destination.path_join(name)
		if FileAccess.file_exists(target) and FileAccess.get_sha256(original) == FileAccess.get_sha256(target): continue
		error = DirAccess.copy_absolute(original, target)
		if error != OK: return error
	for name in DirAccess.get_directories_at(source):
		error = copy_directory(source.path_join(name), destination.path_join(name))
		if error != OK: return error
	return OK
