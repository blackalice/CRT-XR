@tool
extends EditorExportPlugin
## Android exports carry the libretro cores as APK native libraries in
## lib/arm64-v8a/, where the dynamic linker finds them by name
## (scripts/platform/platform.gd). They come from cores/android-arm64/, built by
## scripts/build-release-cores.py android with their source records.

const CORES := "res://cores/android-arm64"

func _get_name() -> String:
	return "CRT XR Android cores"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid

func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if not features.has("android"): return
	var folder := ProjectSettings.globalize_path(CORES)
	var found := 0
	for file in DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray():
		if file.begins_with("lib") and file.ends_with("_libretro.so"):
			add_shared_object(folder.path_join(file), PackedStringArray(["arm64"]), "")
			found += 1
	if found == 0: push_warning("No Android cores in cores/android-arm64; the APK cannot play games. Run scripts/build-release-cores.py android.")
	else: print("CRT XR: packaging %d Android cores" % found)
