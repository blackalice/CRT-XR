extends SceneTree
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
	OS.set_environment("RETROCRT_SCREENSHOT_DIR",ProjectSettings.globalize_path("user://test-screenshots"))
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	if not app.emulator.loaded:
		app.emulator.load_rom(ProjectSettings.globalize_path("res://build/retrocrt-probe.sfc"))
	app.set_stereo(true)
	app.toggle_settings()
	app.settings_tabs.current_tab = 1
	await settle()
	app.distance_slider.value = 2.2
	app.height_slider.value = .6
	app.height_slider.grab_focus()
	await y_button()
	check(app.height_offset == 0 and is_equal_approx(app.height_slider.value,0), "Y restores the selected height option and its slider")
	check(is_equal_approx(app.distance,2.2), "Per-option reset leaves neighbouring options unchanged")
	check(app.stereo and app.settings_panel.visible and app.emulator.paused, "Reset preserves SBS, open menu and paused game")
	app.height_slider.value = .4
	app.height_slider.grab_focus()
	app.settings_panel.find_child("ResetOption",true,false).grab_focus()
	await y_button()
	check(app.height_offset == 0, "Footer reset button uses the last selected option")
	app.distance_slider.value = 2.5
	app.settings_panel.find_child("Stereo",true,false).grab_focus()
	await y_button()
	check(is_equal_approx(app.distance,2.5) and app.stereo, "Y on an action button cannot reset another option or switch display mode")
	app.settings_tabs.current_tab = 3
	await settle()
	app.room_sliders.ambient.value = .9
	app.room_sliders.lamp_height.value = 1.4
	app.room_sliders.lamp_height.grab_focus()
	await y_button()
	check(is_equal_approx(app.world.lamp_height,2.6) and is_equal_approx(app.world.ambient,.9), "Y resets just the selected room control and updates the actual light")
	app.settings_tabs.current_tab = 0
	await settle()
	var preview = app.settings_panel.find_child("InputPreview",true,false)
	preview.button_pressed = false
	preview.grab_focus()
	await y_button()
	check(app.emulator.run_ahead and preview.button_pressed, "Y resets a selected switch")
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
	check(is_equal_approx(app.distance,3.4) and app.height_offset == 0 and is_equal_approx(app.world.ambient,.45), "Explicit reset-all restores view and room defaults")
	check(app.stereo and app.emulator.loaded and app.emulator.paused and app.settings_panel.visible, "Reset-all preserves the loaded game, menu and physical display mode")
	check(is_equal_approx(app.distance_slider.value,3.4) and is_equal_approx(app.room_sliders.ambient.value,.45), "Reset-all refreshes all menu controls")
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
