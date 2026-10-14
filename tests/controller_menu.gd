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
	for i in range(3): await process_frame
func button(code: int, down: bool):
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func press(code: int):
	button(code,true)
	await settle()
	button(code,false)
	await settle()
func stick(axis: int, value: float):
	var event := InputEventJoypadMotion.new()
	event.device = 7
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run():
	# Reproduce the failure class: no platform UI joypad bindings at all.
	for action in ["ui_up","ui_down","ui_left","ui_right","ui_accept"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion: InputMap.action_erase_event(action,event)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	app.set_stereo(true)
	app.toggle_settings()
	await settle()
	var before = app.menu_view.gui_get_focus_owner()
	await press(JOY_BUTTON_DPAD_DOWN)
	check(app.menu_view.gui_get_focus_owner() != before, "D-pad navigates settings without platform UI joypad bindings")
	app.settings_tabs.current_tab = 1
	await settle()
	app.distance_slider.grab_focus()
	app.distance_slider.value = 3.0
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(is_equal_approx(app.distance,3.1), "D-pad right adjusts the selected slider directly")
	await press(JOY_BUTTON_DPAD_LEFT)
	check(is_equal_approx(app.distance,3.0), "D-pad left adjusts the selected slider directly")
	button(JOY_BUTTON_DPAD_RIGHT,true)
	app._process(.4)
	app._process(.11)
	button(JOY_BUTTON_DPAD_RIGHT,false)
	check(app.distance > 3.1 and app.menu_direction == Vector2i.ZERO, "Held adjustment repeats and stops on release")
	app.settings_tabs.current_tab = 0
	await settle()
	var toggle = app.settings_panel.find_child("InputPreview",true,false)
	toggle.grab_focus()
	var enabled: bool = toggle.button_pressed
	await press(JOY_BUTTON_A)
	check(toggle.button_pressed != enabled and app.emulator.run_ahead == toggle.button_pressed, "A toggles switches without pointer input or ui_accept mapping")
	app.settings_tabs.current_tab = 3
	await settle()
	app.settings_panel.find_child("Bright",true,false).grab_focus()
	await press(JOY_BUTTON_A)
	check(is_equal_approx(app.world.ambient,.85), "A activates the selected preset button")
	var focus_before = app.menu_view.gui_get_focus_owner()
	stick(JOY_AXIS_LEFT_Y,1)
	await settle()
	check(app.menu_view.gui_get_focus_owner() != focus_before, "Left stick also navigates settings")
	stick(JOY_AXIS_LEFT_Y,0)
	check(app.menu_direction == Vector2i.ZERO, "Centered stick stops menu navigation")
	button(JOY_BUTTON_DPAD_DOWN,true)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(app.menu_direction == Vector2i.ZERO, "Focus loss cancels held menu movement")
	button(JOY_BUTTON_DPAD_DOWN,false)
	app.settings_panel.find_child("Close",true,false).grab_focus()
	# Save must not affect the user's settings when this test is run manually.
	var existed := FileAccess.file_exists("user://settings.cfg")
	var backup := FileAccess.get_file_as_bytes("user://settings.cfg") if existed else PackedByteArray()
	await press(JOY_BUTTON_A)
	check(not app.settings_panel.visible and app.stereo, "A activates Save and close while preserving SBS")
	app.distance_save_delay = -1
	app.free()
	if existed:
		var file := FileAccess.open("user://settings.cfg",FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	quit(1 if failures else 0)
