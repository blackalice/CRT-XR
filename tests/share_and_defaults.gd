extends SceneTree
const UI=preload("res://tests/menu_test_helpers.gd")
var failures := 0
var app
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1
func _initialize(): call_deferred("run")
func settle():
	for i in range(4): await process_frame
func y_button():
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_Y
		event.device = 7
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await settle()
func run():
	OS.set_environment("CRT_XR_SCREENSHOT_DIR",ProjectSettings.globalize_path("user://test-screenshots"))
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.close_settings()
	app.use_tracking(false)
	if not app.emulator.loaded:
		app.emulator.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc"))
	app.set_stereo(true)
	app.toggle_settings()
	UI.set_value(app,"view.distance",2.2)
	UI.set_value(app,"view.height_offset",.6)
	await y_button()
	check(is_equal_approx(app.height_offset,-.15),"Y restores selected height")
	check(is_equal_approx(app.distance,2.2),"Per-option reset leaves neighbouring options unchanged")
	check(app.stereo and app.menu.visible and app.emulator.paused,"Reset preserves SBS and paused game")
	UI.set_value(app,"room.ambient",.9)
	UI.set_value(app,"room.lamp_height",1.4)
	await y_button()
	check(is_equal_approx(app.world.lamp_height,2.6) and is_equal_approx(app.world.ambient,.9),"Y resets just the selected room control")
	UI.set_value(app,"controls.preview",0)
	await y_button()
	check(app.emulator.run_ahead==1,"Y resets a selected choice to its default")
	await settle()
	var eye_size: Vector2i = app.views[0].size
	var path: String = await app.take_screenshot()
	var saved := Image.load_from_file(path)
	var source: Image = app.views[0].get_texture().get_image()
	check(not path.is_empty() and saved.get_size() == eye_size, "Screenshot saves a single-eye PNG in SBS")
	check(saved.get_data() == source.get_data(), "Screenshot contains exactly the clean 3D view, without HUD or menu")
	check(app.stereo and app.settings_panel.visible and app.emulator.paused, "Screenshot leaves display, menu and game pause state intact")
	var another: String = await app.take_screenshot()
	check(another != path and FileAccess.file_exists(path) and FileAccess.file_exists(another), "Repeated screenshots create distinct files")
	var capture_key := InputEventKey.new()
	capture_key.physical_keycode = KEY_F6
	capture_key.pressed = true
	Input.parse_input_event(capture_key)
	await settle()
	check(app.last_screenshot_path != another and FileAccess.file_exists(app.last_screenshot_path), "F6 saves a screenshot while the menu is open")
	app.reset_all_options()
	await settle()
	check(is_equal_approx(app.distance,3.284008) and is_equal_approx(app.height_offset,-.15) and is_equal_approx(app.world.ambient,.05), "Explicit reset-all restores view and room defaults")
	check(app.stereo and app.emulator.loaded and app.emulator.paused and app.settings_panel.visible, "Reset-all preserves the loaded game, menu and physical display mode")
	check(is_equal_approx(UI.get_value(app,"view.distance"),3.284008) and is_equal_approx(UI.get_value(app,"room.ambient"),.05), "Reset-all refreshes all menu controls")
	app.close_settings()
	var y := InputEventJoypadButton.new()
	y.device = 7
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	Input.parse_input_event(y)
	Input.flush_buffered_events()
	check(app.emulator.gamepad.mask() == 1 << 9, "Y retains its SNES X mapping outside the menu")
	app.distance_save_delay = -1
	app.emulator.stop()
	app.free()
	await process_frame
	quit(1 if failures else 0)
