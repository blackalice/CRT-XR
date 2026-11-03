extends SceneTree
## Continue a copy of a pre-fix resume point; never write to the source folder.
const Emulation = preload("res://scripts/emulation/emulation_session.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rom := OS.get_environment("CRT_XR_GAMECUBE_ROM")
	var source := OS.get_environment("CRT_XR_EXISTING_SAVE")
	var destination := ProjectSettings.globalize_path(Emulation.auto_path_for(rom))
	if source.is_empty() or destination.is_empty(): print("FAIL missing test paths"); quit(1); return
	var copied := false
	for name in DirAccess.get_files_at(source):
		if not name.ends_with(".auto.rst"): continue
		var details := Emulation.state_details(source.path_join(name))
		if details.get("game", "") != rom.get_file(): continue
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		copied = DirAccess.copy_absolute(source.path_join(name), destination) == OK
		break
	if not copied: print("SKIP no existing resume for ", rom.get_file()); quit(); return
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.menu.games.launch_game(rom, true)
	await create_timer(8.0).timeout
	var ok: bool = app.emulator.loaded and not app.emulator.core_failed and not app.settings_panel.visible and app.emulator.status.begins_with("Continued automatic save")
	print("%s existing resume: %s" % ["PASS" if ok else "FAIL", rom.get_file()])
	app.emulator.stop()
	quit(0 if ok else 1)
