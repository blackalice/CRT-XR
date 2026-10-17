extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func button(code: int, pressed: bool, device := 7) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func axis(code: int, value: float, device := 7) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = code
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.close_settings()
	app.use_tracking(false)
	await process_frame
	await process_frame
	var session = app.emulator
	var mapping := [[JOY_BUTTON_A, 0], [JOY_BUTTON_B, 8], [JOY_BUTTON_X, 1], [JOY_BUTTON_Y, 9],
		[JOY_BUTTON_LEFT_SHOULDER, 10], [JOY_BUTTON_RIGHT_SHOULDER, 11],
		[JOY_BUTTON_BACK, 2], [JOY_BUTTON_START, 3], [JOY_BUTTON_DPAD_UP, 4],
		[JOY_BUTTON_DPAD_DOWN, 5], [JOY_BUTTON_DPAD_LEFT, 6], [JOY_BUTTON_DPAD_RIGHT, 7]]
	for pair in mapping:
		button(pair[0], true)
		check(session.input_mask() == 1 << pair[1], "Controller button %d reaches SNES bit %d" % [pair[0], pair[1]])
		button(pair[0], false)
	check(not app.settings_panel.visible and not app.stereo, "Single buttons leave settings and display mode alone")
	axis(JOY_AXIS_LEFT_X, 0.2)
	check(session.input_mask() == 0, "Left-stick deadzone rejects drift")
	axis(JOY_AXIS_LEFT_X, -0.8)
	axis(JOY_AXIS_LEFT_Y, -0.8)
	check(session.input_mask() == ((1 << 6) | (1 << 4)), "Left stick supports diagonal SNES movement")
	button(JOY_BUTTON_DPAD_RIGHT, true)
	check(session.input_mask() == 1 << 4, "Conflicting left/right directions cancel")
	button(JOY_BUTTON_DPAD_RIGHT, false)
	axis(JOY_AXIS_LEFT_X, 0.0)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	check(session.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")), "Diagnostic cartridge loads for gamepad integration")
	await create_timer(0.15).timeout
	button(JOY_BUTTON_A, true, 42)
	await create_timer(0.15).timeout
	var frame: PackedByteArray = session.core.frame()
	check(frame[0] > 240 and frame[1] < 8 and frame[2] < 8, "Deck bottom button drives SNES B in the running native core")
	button(JOY_BUTTON_A, false, 42)
	button(JOY_BUTTON_LEFT_STICK, true)
	check(not app.settings_panel.visible, "L3 no longer opens settings")
	button(JOY_BUTTON_LEFT_STICK, false)
	button(JOY_BUTTON_LEFT_SHOULDER, true)
	button(JOY_BUTTON_RIGHT_SHOULDER, true)
	button(JOY_BUTTON_START, true)
	check(app.settings_panel.visible and session.paused, "L + R + Start opens settings and pauses gameplay")
	check(session.input_mask() == 0, "Menu chord is withheld from the game")
	button(JOY_BUTTON_START, true)
	check(app.settings_panel.visible, "Holding the chord does not toggle repeatedly")
	button(JOY_BUTTON_B, true)
	check(not app.settings_panel.visible and not session.paused, "B closes settings and resumes gameplay")
	check(session.input_mask() == 0, "Menu cancel and held shortcut do not leak into gameplay")
	button(JOY_BUTTON_B, false)
	button(JOY_BUTTON_START, false)
	check(session.input_mask() == 0, "Partially released chord remains suppressed")
	button(JOY_BUTTON_LEFT_SHOULDER, false)
	button(JOY_BUTTON_RIGHT_SHOULDER, false)
	button(JOY_BUTTON_START, true)
	check(session.input_mask() == 1 << 3 and not app.settings_panel.visible, "Start works normally after releasing the shortcut")
	button(JOY_BUTTON_START, false)
	button(JOY_BUTTON_X, true, 42)
	check(session.input_mask() == 1 << 1, "Input follows the active controller instead of the first detected pad")
	Input.joy_connection_changed.emit(42, false)
	check(session.input_mask() == 0, "Disconnect clears held gamepad buttons")
	button(JOY_BUTTON_A, true)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(session.input_mask() == 0, "Focus loss clears held gamepad buttons")
	session.stop()
	app.queue_free()
	await process_frame
	print("Gamepad checks complete: ", failures, " failures")
	quit(1 if failures else 0)
