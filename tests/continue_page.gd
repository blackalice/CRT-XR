extends SceneTree
## Welcome back: the picked save large, a strip of the resume point and four
## slots, L1 / R1 to pick, and Continue from the picked save.
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func settle(frames := 6) -> void:
	for i in range(frames): await process_frame
func run():
	var app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await settle(10)
	app.apply_settings(ConfigFile.new()); app.use_tracking(false)
	var m = app.menu
	if not app.settings_panel.visible: app.toggle_settings()
	var roms := ProjectSettings.globalize_path("user://cp-roms")
	DirAccess.make_dir_recursive_absolute(roms.path_join("snes"))
	var rom := roms.path_join("snes/Test Game (USA).sfc")
	var f := FileAccess.open(rom, FileAccess.WRITE); f.store_string("x"); f.close()
	var auto: String = app.emulator.auto_path_for(rom)
	check(app.emulator.state_path_for(rom, 1) == auto.trim_suffix(".auto.rst") + ".slot1.rst", "Slot files sit beside the resume point")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(auto).get_base_dir())
	for file in [auto, app.emulator.state_path_for(rom, 1)]:
		f = FileAccess.open(file, FileAccess.WRITE); f.store_string("state"); f.close()
	m.games.select_file(rom); await settle()
	check(m.mode == "launch" and m.selected_id == "launch.continue", "A game with saves opens Welcome back on Continue")
	var ids: Array = m.items.map(func(item): return item.id)
	check(ids.has("launch.save.0") and ids.has("launch.save.2") and ids.has("launch.save.4"), "The strip lists the resume point and four slots")
	check(m.items.filter(func(item): return str(item.id).begins_with("launch.save.") and not item.get("disabled", false)).size() == 2, "Only saves that exist can be chosen")
	m.games.pick_save(1); await settle()
	check(m.games.launch_pick == 1 and m.items.any(func(item): return item.id == "launch.continue" and item.label == "Continue from Slot 2"), "R1 picks the next save and Continue says which")
	m.games.pick_save(1); await settle()
	check(m.games.launch_pick == -1 and m.items.any(func(item): return item.id == "launch.continue" and item.label == "Continue"), "Picking wraps back to the resume point")
	check(m.hints.text.contains("Pick save"), "The footer says how to pick a save")
	app.free(); await settle()
	print("CONTINUE PAGE: %d failures" % failures)
	quit(1 if failures else 0)
