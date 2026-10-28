extends SceneTree
## Platform answers for each platform, simulated in the editor, so Android paths
## and capabilities are checked without a device.
const Platform = preload("res://scripts/platform/platform.gd")
const Registry = preload("res://scripts/emulation/core_registry.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# The editor reads its own checkout, whatever platform it runs on.
	Platform.simulated = ""
	check(Platform.in_editor(), "The editor is recognised")
	check(Platform.asset("room-bake", "room-bake") == ProjectSettings.globalize_path("res://build").path_join("room-bake"), "The editor reads prepared assets from build/")
	check(Platform.app_dir() == ProjectSettings.globalize_path("res://"), "The editor's app folder is the checkout")
	check(Platform.id() == OS.get_name().to_lower(), "Without simulation the real platform is reported")

	Platform.simulated = "windows"
	check(not Platform.in_editor(), "Simulation answers as an exported app")
	check(Platform.core_library("snes9x").ends_with("cores/snes9x_libretro.dll"), "Windows cores are DLLs beside the app")
	check(Platform.asset("crt-model/ao", "ao").ends_with("assets/ao"), "Windows assets sit in assets/ beside the app")
	check(Platform.has_drive_list() and Platform.case_insensitive_paths() and Platform.downloads_ffmpeg(), "Windows lists drives, ignores path case and downloads FFmpeg")
	check(Platform.glasses_tracking() == "viture_windows" and Platform.glasses_tracking_label() == "VITURE glasses", "Windows tracks through the VITURE helper")
	check(Platform.shared_folder().is_empty(), "Windows keeps user-added files beside the app")

	Platform.simulated = "linux"
	check(Platform.core_library("nestopia").ends_with("cores/nestopia_libretro.so"), "Linux cores are shared objects beside the app")
	check(not Platform.has_drive_list() and not Platform.case_insensitive_paths() and not Platform.downloads_ffmpeg(), "Linux has no drive list, keeps path case and uses system FFmpeg")
	check(Platform.glasses_tracking() == "xr_linux" and Platform.glasses_tracking_label() == "XR Gaming", "Linux tracks through XR Gaming")
	check(Platform.can_spawn_processes(), "Desktop platforms can start helper processes")

	Platform.simulated = "android"
	check(Platform.is_android() and not Platform.is_linux(), "Android is its own platform, not Linux")
	check(Platform.core_library("snes9x") == "libsnes9x_libretro.so", "Android opens cores as APK native libraries by name")
	check(Platform.core_present("libsnes9x_libretro.so"), "A bare Android library name is left to the dynamic linker")
	check(not Platform.core_present("/nowhere/cores/missing_libretro.so"), "A missing core file is still reported on Android")
	check(Platform.asset("crt-model/optimised/cabinet.scn", "optimised/cabinet.scn") == "res://android_assets/optimised/cabinet.scn", "Android reads prepared assets from the pack")
	check(Platform.app_dir() == OS.get_user_data_dir(), "Android's app folder is its private data folder")
	check(not Platform.can_spawn_processes(), "Android cannot start helper processes")
	check(Platform.glasses_tracking().is_empty(), "Android has no built-in glasses tracking yet")
	check(not Platform.has_drive_list() and not Platform.downloads_ffmpeg(), "Android has no drive list or FFmpeg download")
	check(Platform.home_folder().begins_with("/storage/") or not OS.get_environment("EXTERNAL_STORAGE").is_empty(), "Android starts browsing in shared storage")
	check(Platform.shared_folder() == Platform.home_folder().path_join("Documents/CRT XR"), "Android keeps user-added files in Documents/CRT XR")
	check(Registry.core_path("snes") == "libsnes9x_libretro.so", "The core registry asks the platform for core locations")
	check(Registry.bios_sources().has(Platform.shared_folder().path_join("bios")), "Android searches Documents/CRT XR/bios for BIOS files")
	check(Registry.preferred_bios_folder() == Platform.shared_folder().path_join("bios"), "Android suggests a BIOS folder the user can reach")

	Platform.simulated = ""
	print("PLATFORM PATHS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)
