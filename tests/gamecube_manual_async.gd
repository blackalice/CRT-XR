extends SceneTree
const Store = preload("res://scripts/emulation/state_store.gd")
var failures := 0
var measuring := false
var previous := 0
var worst := 0
func tick() -> void:
	var now := Time.get_ticks_usec()
	if measuring and previous > 0: worst = maxi(worst, now - previous)
	previous = now
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(30): await process_frame
	var game := OS.get_environment("CRT_XR_GAMECUBE_ROM")
	app.menu.games.launch_game(game, false)
	var deadline := Time.get_ticks_msec() + 20000
	while (not app.emulator.loaded or not app.loading_path.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	if not app.emulator.loaded: check(false, "GameCube boots"); quit(1); return
	if not app.menu.visible: app.toggle_settings()
	for i in range(3): await process_frame
	process_frame.connect(tick)
	measuring = true
	check(await app.emulator.save_state_async(2), "large GameCube manual save runs in the background")
	var path: String = app.emulator.state_path(2)
	var metadata := Store.metadata(path)
	check(not metadata.is_empty() and FileAccess.get_size(path + ".preview") < 1024 * 1024, "large state has a bounded lightweight preview")
	print("PROFILE state_bytes=", FileAccess.get_size(path), " preview_bytes=", FileAccess.get_size(path + ".preview"))
	DirAccess.remove_absolute(path + ".preview")
	var began := Time.get_ticks_usec()
	app.menu.play.open_states(false)
	print("PROFILE legacy_preview_page_us=", Time.get_ticks_usec() - began)
	deadline = Time.get_ticks_msec() + 10000
	while Store.metadata(path).is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(Store.metadata(path).get("saved_at") == metadata.get("saved_at"), "legacy timestamp and thumbnail migrate in the background")
	check(await app.emulator.load_state_async(2), "manual GameCube restore stays on the guarded worker")
	check(await app.emulator.reset_game_async(), "manual GameCube reset stays on the guarded worker")
	measuring = false
	print("PROFILE manual_operations_worst_frame_us=", worst)
	check(worst < 50000, "room remains responsive during manual state operations and migration")
	await app.emulator.stop_for_launch()
	app.queue_free()
	await process_frame
	print("GAMECUBE MANUAL COMPLETE failures=", failures)
	quit(1 if failures else 0)
