extends RefCounted
## Finding and setting up the VITURE Windows SDK, which CRT XR may not bundle.
##
## The user picks the SDK as VITURE supplies it: its ZIP, its folder, or
## glasses.dll inside it. The DLLs beside glasses.dll (libusb and friends) are
## copied into CRT XR's own user-data folder, where the tracking helper loads them
## (it searches the DLL's own folder for its dependencies). Nothing outside that
## folder changes, and nothing is downloaded.

const DLL := "glasses.dll"

## Where a set-up SDK lives: user data, so it survives updates to a new app folder.
static func user_dir() -> String:
	return ProjectSettings.globalize_path("user://viture-sdk")

## glasses.dll to use, or "" if none is set up. An explicit environment variable
## wins; then the user-data copy; then the older `sdk` folder beside the EXE.
static func find_dll(app_dir := "") -> String:
	var candidates: Array[String] = []
	var env := OS.get_environment("CRT_XR_VITURE_SDK")
	if not env.is_empty(): candidates.append(env)
	candidates.append(user_dir().path_join(DLL))
	if OS.has_feature("editor"):
		candidates.append(ProjectSettings.globalize_path("res://sdk/x86_64/glasses.dll"))
	var base := app_dir if not app_dir.is_empty() else OS.get_executable_path().get_base_dir()
	candidates.append(base.path_join("sdk").path_join(DLL))
	candidates.append(base.path_join("sdk/x86_64").path_join(DLL))
	for path in candidates:
		if FileAccess.file_exists(path): return path
	return ""

static func available(app_dir := "") -> bool:
	return not find_dll(app_dir).is_empty()

## Set up the SDK from a ZIP, a folder, or glasses.dll itself.
## Returns {"ok": bool, "message": String, "files": int}.
static func install_from(source: String, destination := "") -> Dictionary:
	var target := destination if not destination.is_empty() else user_dir()
	source = source.strip_edges()
	if source.is_empty(): return failure("Choose the VITURE SDK ZIP, its folder, or glasses.dll.")
	if source.get_extension().to_lower() == "zip": return install_from_zip(source, target)
	var folder := source
	if FileAccess.file_exists(source):
		if source.get_file().to_lower() != DLL: return failure("That isn't the VITURE SDK. Choose its ZIP, its folder, or glasses.dll inside it.")
		folder = source.get_base_dir()
	elif DirAccess.dir_exists_absolute(source):
		var found := find_in_folder(source)
		if found.is_empty(): return failure("No glasses.dll in that folder. Choose the VITURE Windows SDK, or its x86_64 folder.")
		folder = found.get_base_dir()
	else:
		return failure("That file or folder can't be found.")
	var names: Array[String] = []
	for name in DirAccess.get_files_at(folder):
		if name.get_extension().to_lower() == "dll": names.append(name)
	DirAccess.make_dir_recursive_absolute(target)
	for name in names:
		var error := DirAccess.copy_absolute(folder.path_join(name), target.path_join(name))
		if error != OK: return failure("Couldn't copy %s (%s). Check CRT XR can write to its settings folder." % [name, error_string(error)])
	return {"ok": true, "files": names.size(), "message": "VITURE SDK set up: %d files copied." % names.size()}

## glasses.dll under `folder`, preferring an x86_64 folder (the SDK also ships
## other architectures). Searches a few levels down, as an extracted ZIP nests.
static func find_in_folder(folder: String, depth := 0) -> String:
	var here := folder.path_join(DLL)
	if FileAccess.file_exists(here) and (folder.get_file().to_lower() == "x86_64" or depth == 0): return here
	if depth >= 4: return here if FileAccess.file_exists(here) else ""
	var subfolders := Array(DirAccess.get_directories_at(folder))
	# x86_64 first, then the rest; arm64 and x86 builds can't load in a 64-bit app.
	subfolders.sort_custom(func(a, b): return str(a).to_lower() == "x86_64" and str(b).to_lower() != "x86_64")
	for sub in subfolders:
		if str(sub).to_lower() in ["arm64", "aarch64", "x86", "win32"]: continue
		var found := find_in_folder(folder.path_join(sub), depth + 1)
		if not found.is_empty(): return found
	return here if FileAccess.file_exists(here) else ""

static func install_from_zip(zip_path: String, target: String) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK: return failure("That ZIP can't be opened.")
	var files := zip.get_files()
	var dll_entry := ""
	for entry in files:
		var lower := entry.to_lower()
		if lower.ends_with("/" + DLL) or lower == DLL:
			var arch := lower.get_base_dir().get_file()
			if arch in ["arm64", "aarch64", "x86", "win32"]: continue
			if dll_entry.is_empty() or arch == "x86_64": dll_entry = entry
	if dll_entry.is_empty():
		zip.close()
		return failure("No glasses.dll in that ZIP. Is it the VITURE Windows SDK?")
	var prefix := dll_entry.get_base_dir()
	DirAccess.make_dir_recursive_absolute(target)
	var copied := 0
	for entry in files:
		if entry.get_base_dir() != prefix or entry.get_extension().to_lower() != "dll": continue
		var file := FileAccess.open(target.path_join(entry.get_file()), FileAccess.WRITE)
		if file == null:
			zip.close()
			return failure("Couldn't write %s. Check CRT XR can write to its settings folder." % entry.get_file())
		file.store_buffer(zip.read_file(entry))
		file.close()
		copied += 1
	zip.close()
	return {"ok": true, "files": copied, "message": "VITURE SDK set up: %d files copied." % copied}

static func failure(message: String) -> Dictionary:
	return {"ok": false, "files": 0, "message": message}

## True while VITURE's SpaceWalker app runs: it holds the glasses' USB interface.
static func spacewalker_running() -> bool:
	if OS.get_name() != "Windows": return false
	var out: Array = []
	if OS.execute("tasklist", ["/FI", "IMAGENAME eq SpaceWalker.exe", "/NH"], out) != 0: return false
	return not out.is_empty() and str(out[0]).to_lower().contains("spacewalker.exe")

## Opens Windows' own file dialog to choose the SDK, then sets it up.
## `done` receives the install_from result.
static func choose(done: Callable) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		done.call(failure("This system has no file dialog. Copy the SDK's x86_64 files into %s instead." % user_dir()))
		return
	DisplayServer.file_dialog_show("Choose the VITURE SDK ZIP, or glasses.dll inside it", OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), "",
		false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.zip, *.dll ; VITURE SDK"]),
		func(status: bool, paths: PackedStringArray, _filter: int):
			if not status or paths.is_empty(): return
			done.call(install_from(paths[0])))
