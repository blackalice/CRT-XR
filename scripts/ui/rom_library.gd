extends RefCounted
const Locations = preload("res://scripts/content/rom_locations.gd")
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Folders = preload("res://scripts/content/console_folders.gd")
const HIDDEN := ["$recycle.bin","system volume information","lost+found"]
var current_dir := ""
var default_dir := ""
var entries: Array[Dictionary] = []
var message := ""

func home_folder() -> String:
	var home := OS.get_environment("HOME") if OS.get_name()=="Linux" else OS.get_environment("USERPROFILE")
	return home if not home.is_empty() else ProjectSettings.globalize_path("res://")

func show_folder(path: String) -> bool:
	if OS.get_name()=="Windows": path=Locations.normalize_windows_path(path)
	var directory := DirAccess.open(path)
	if directory == null:
		message = "Folder unavailable. Check its drive or network connection, or choose another folder."
		return false
	current_dir = directory.get_current_dir()
	entries.clear()
	var folders := directory.get_directories(); folders.sort()
	var files := directory.get_files(); files.sort()
	for folder in folders:
		# Skip dot/cache folders and OS housekeeping that never hold games.
		if folder.begins_with(".") or folder.begins_with("__") or folder.to_lower() in HIDDEN: continue
		var console := Folders.system(folder)
		entries.append({"path":current_dir.path_join(folder),"folder":true,"label":folder,"system":Registry.SYSTEMS[console].name if not console.is_empty() else ""})
	for file in files:
		var system := Registry.identify(current_dir.path_join(file))
		if not system.is_empty():
			entries.append({"path":current_dir.path_join(file),"folder":false,"label":file,"system":Registry.SYSTEMS[system].name})
	message = "No supported games here. Open a folder, or go up with L1." if entries.is_empty() else "Choose a game, or press R1 to use this folder as your library."
	return true

func cards() -> Array:
	return Array(Locations.sd_cards())
