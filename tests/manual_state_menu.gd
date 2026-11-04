extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func wait_operation(app) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while app.emulator.transition_busy and Time.get_ticks_msec() < deadline: await create_timer(.005).timeout
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	for i in range(3): await process_frame
	check(app.load_game(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")), "menu probe loads")
	app.menu.play.open_states(true)
	app.menu.play.perform_state_action(true, 1)
	await wait_operation(app)
	check(FileAccess.file_exists(app.emulator.state_path(1)) and not app.emulator.state_metadata(app.emulator.state_path(1)).is_empty(), "slot action writes the save and preview")
	app.menu.play.open_states(false)
	app.menu.play.choose_state(1)
	check(app.menu.mode == "confirm", "slot restore asks for confirmation")
	app.menu.confirmed()
	await wait_operation(app)
	check(not app.menu.visible and app.emulator.loaded, "confirmed asynchronous load returns to the game")
	app.toggle_settings()
	app.menu.play.reset_game()
	app.menu.confirmed()
	await wait_operation(app)
	check(not app.menu.visible and app.emulator.loaded, "confirmed asynchronous reset returns to the game")
	app.queue_free()
	await process_frame
	print("MANUAL STATE MENU COMPLETE failures=", failures)
	quit(1 if failures else 0)
