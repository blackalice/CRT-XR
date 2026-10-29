extends RefCounted
## The one place that asks which platform CRT XR runs on. Other scripts ask what
## the platform can do, so a new platform is a change here rather than at every
## call site. scripts/check-repository.py keeps OS.get_name() and
## OS.get_executable_path() out of the other scripts.
##
## Android keeps no files beside an executable: prepared assets live in the pack
## under res://android_assets/, cores are APK native libraries opened by name,
## and the user-visible folders are in shared storage.

const ANDROID_ASSETS := "res://android_assets"
const ANDROID_SHARED := "/storage/emulated/0"

## Tests pretend to be another platform ("windows", "linux", "android") by setting
## this. Only editor builds honour it, so an exported app always reports itself.
static var simulated := ""

static func id() -> String:
	if not simulated.is_empty() and OS.has_feature("editor"): return simulated
	return OS.get_name().to_lower()

static func is_windows() -> bool: return id() == "windows"
static func is_linux() -> bool: return id() == "linux"
static func is_android() -> bool: return id() == "android"

## Simulation only changes the answers about paths and capabilities; the editor
## still reads its own checkout.
static func in_editor() -> bool: return OS.has_feature("editor") and simulated.is_empty()

## The folder holding the app's own files: the checkout in the editor, the
## executable's folder in a desktop export, and the private user-data folder on
## Android, which has no executable folder.
static func app_dir() -> String:
	if in_editor(): return ProjectSettings.globalize_path("res://")
	if is_android(): return OS.get_user_data_dir()
	return OS.get_executable_path().get_base_dir()

## A prepared model or bake. The editor reads it from build/<editor_relative>;
## desktop exports keep it in assets/<release_relative> beside the executable;
## Android packs it under res://android_assets/<release_relative>.
static func asset(editor_relative: String, release_relative: String) -> String:
	if in_editor(): return ProjectSettings.globalize_path("res://build").path_join(editor_relative)
	if is_android(): return ANDROID_ASSETS.path_join(release_relative)
	return app_dir().path_join("assets").path_join(release_relative)

## A libretro core. Android packages cores as APK native libraries, which the
## dynamic linker finds by name; elsewhere they sit in cores/ beside the app.
static func core_library(core: String) -> String:
	if is_android(): return "lib" + core + "_libretro.so"
	return app_dir().path_join("cores/" + core + "_libretro." + ("dll" if is_windows() else "so"))

## Whether a core file is present. A bare Android library name cannot be checked
## with FileAccess; loading it reports a missing library instead.
static func core_present(path: String) -> bool:
	if is_android() and not "/" in path: return true
	return FileAccess.file_exists(path)

## Where the user's own files start: their home folder, or shared storage.
static func home_folder() -> String:
	if is_android(): return OS.get_environment("EXTERNAL_STORAGE") if not OS.get_environment("EXTERNAL_STORAGE").is_empty() else ANDROID_SHARED
	var home := OS.get_environment("USERPROFILE") if is_windows() else OS.get_environment("HOME")
	return home if not home.is_empty() else ProjectSettings.globalize_path("res://")

## A user-visible folder for files people add themselves, such as BIOS files,
## that survives app updates. Desktop keeps these beside the app instead.
static func shared_folder() -> String:
	return home_folder().path_join("Documents/CRT XR") if is_android() else ""

## Android 11 and later show apps only photos, music and videos in shared
## storage unless they have "All files access", so game folders list as empty.
const STORAGE_PERMISSION := "android.permission.MANAGE_EXTERNAL_STORAGE"

static func needs_storage_access() -> bool:
	return is_android() and not OS.has_feature("editor") and not OS.get_granted_permissions().has(STORAGE_PERMISSION)

## Opens Android's "All files access" page for CRT XR.
static func request_storage_access() -> void:
	if needs_storage_access(): OS.request_permission(STORAGE_PERMISSION)

## Paths that differ only in case name the same file.
static func case_insensitive_paths() -> bool: return is_windows()

## Lettered drives and Windows network paths.
static func has_drive_list() -> bool: return is_windows()

## FFmpeg is fetched on request (Windows); elsewhere it comes from the system.
static func downloads_ffmpeg() -> bool: return is_windows()

## Separate helper processes (the tracking bridges). Android cannot start them.
static func can_spawn_processes() -> bool: return not is_android()

## The built-in glasses tracking route: "viture_windows" through the VITURE SDK
## helper, "xr_linux" through XR Gaming's driver, or "" when there is none yet.
static func glasses_tracking() -> String:
	if is_windows(): return "viture_windows"
	if is_linux(): return "xr_linux"
	return ""

## Name shown for that route in the tracking settings.
static func glasses_tracking_label() -> String:
	match glasses_tracking():
		"viture_windows": return "VITURE glasses"
		"xr_linux": return "XR Gaming"
	return "Glasses (not yet available)"

## For bug reports and the About page.
static func display_name() -> String:
	return OS.get_name()
