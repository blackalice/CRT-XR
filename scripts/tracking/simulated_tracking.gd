extends TrackingProvider

var angles := Vector3.ZERO

func update(delta: float) -> void:
	if enabled:
		var stick := Vector2.ZERO
		var pads := Input.get_connected_joypads()
		if not pads.is_empty():
			stick = Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_Y))
			stick = stick.limit_length() if stick.length() > 0.18 else Vector2.ZERO
		angles.y -= (float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)) + stick.x) * delta
		angles.x -= (float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)) + stick.y) * delta
		angles.z += (float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_E))) * delta
	angles.x = clampf(angles.x, -1.4, 1.4)
	var calibrated := angles * Vector3(-1.0 if invert_pitch else 1.0, -1.0 if invert_yaw else 1.0, -1.0 if invert_roll else 1.0)
	orientation = Basis.from_euler(calibrated).get_rotation_quaternion()
	sample_time_usec = Time.get_ticks_usec()
	status = "SIMULATION / Windows & Linux"

func handle_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		angles.y -= event.relative.x * 0.003
		angles.x -= event.relative.y * 0.003
