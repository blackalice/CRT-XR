extends RefCounted
const Locations = preload("res://scripts/content/rom_locations.gd")
var current_dir := ""
var default_dir := ""
var entries: Array[Dictionary] = []
var message := ""

func home_folder() -> String:
	var home := OS.get_environment("HOME") if OS.get_name()=="Linux" else OS.get_environment("USERPROFILE")
	return home if not home.is_empty() else ProjectSettings.globalize_path("res://")

func show_folder(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		message = "Folder unavailable. Reconnect its SD card or choose another folder."
		return false
	current_dir = directory.get_current_dir()
	entries.clear()
	var folders := directory.get_directories(); folders.sort()
	var files := directory.get_files(); files.sort()
	for folder in folders:
		if not folder.begins_with("."):
			entries.append({"path":current_dir.path_join(folder),"folder":true,"label":folder+" /"})
	for file in files:
		if file.get_extension().to_lower() in ["sfc","smc","swc","fig"]:
			entries.append({"path":current_dir.path_join(file),"folder":false,"label":file})
	message = "No SNES games here. Open a folder or go up with L1." if entries.is_empty() else "Choose a folder or SNES game. R1 saves this folder as your default."
	return true

func cards() -> Array:
	return Array(Locations.sd_cards())
