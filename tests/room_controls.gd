extends SceneTree
var failures := 0
func check(ok: bool, label: String):
	if ok: print("PASS: ", label)
	else:
		push_error(label)
		failures += 1
func motion(pad, value: float):
	var event := InputEventJoypadMotion.new()
	event.device = 7
	event.axis = JOY_AXIS_RIGHT_Y
	event.axis_value = value
	pad.handle_event(event)
func _initialize(): call_deferred("run")
func run():
	var settings_existed := FileAccess.file_exists("user://settings.cfg")
	var settings_backup := FileAccess.get_file_as_bytes("user://settings.cfg") if settings_existed else PackedByteArray()
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	await process_frame
	app.set_process(false)
	var pad = app.emulator.gamepad
	pad.clear()
	motion(pad, .2)
	check(pad.view_distance_axis() == 0, "Right stick ignores drift within deadzone")
	motion(pad, -.625)
	check(is_equal_approx(pad.view_distance_axis(), -.5) and pad.mask() == 0, "Proportional distance axis never sends SNES buttons")
	app.distance = 3.4
	app.distance_speed = 1
	app.right_stick_distance = true
	app._process(.2)
	check(is_equal_approx(app.distance, 3.3), "Stick up moves the TV closer at chosen speed")
	pad.set_menu_active(true)
	check(pad.view_distance_axis() == 0, "Menu suppresses distance axis")
	pad.set_menu_active(false)
	check(pad.view_distance_axis() == 0, "Held stick must return to neutral after menu")
	motion(pad, 0)
	motion(pad, 1)
	app._process(.2)
	check(is_equal_approx(app.distance, 3.5), "Stick down moves TV farther after neutral")
	app.right_stick_distance = false
	app._process(.2)
	check(is_equal_approx(app.distance, 3.5), "Distance binding can be disabled for other consoles")
	pad.disconnect_device(7)
	check(pad.view_distance_axis() == 0, "Disconnect stops distance motion")
	app.adjust_distance(100)
	check(app.distance == 5, "Maximum TV distance enforced")
	app.adjust_distance(-100)
	check(app.distance == 1.2, "Minimum TV distance enforced")
	app.room_preset("bright")
	check(is_equal_approx(app.world.key_light.light_energy, 5) and is_equal_approx(app.world.room_environment.ambient_light_energy, .85), "Bright inspection preset changes actual lights")
	app.set_room_value("warmth", 1)
	check(app.world.key_light.light_color.is_equal_approx(Color("ffd29b")), "Warmth changes light colour")
	app.set_room_value("fade_end", 3)
	check(app.world.fade_begin <= 2.5 and app.world.fade_end == 3, "Fade end keeps a valid transition interval")
	app.set_room_value("fade_begin", 8)
	check(app.world.fade_end >= 8.5 and app.world.floor_material.get_shader_parameter("fade_end") == app.world.fade_end, "Fade start updates floor and end consistently")
	app.world.show_rug = false
	app.world.shadows = false
	app.world.apply_room_settings()
	check(not app.world.rug_node.visible and not app.world.key_light.shadow_enabled, "Rug and shadows can be toggled independently")
	app.world.set_spill_strength(.23)
	check(app.world.spill_strength == 0 and app.world.spill_receivers.is_empty(), "Deferred glow cannot be re-enabled by old settings")
	check(not is_instance_valid(app.world.spill_average), "Deferred glow creates no averaging viewport")
	var original_distance: float = app.distance
	var eye_y: float = app.eyes[0].position.y
	app.height_slider.value = 0.4
	app._process(0)
	app.world._process(0)
	check(is_equal_approx(app.world.television.position.y, 1.65), "Height slider raises the virtual screen")
	check(is_equal_approx(app.eyes[0].position.y, eye_y) and app.distance == original_distance, "Height adjustment leaves eye position and distance unchanged")
	check(is_equal_approx(app.world.floor_node.position.y, 1.65 - 1.26 * app.tv_scale), "Floor and furniture remain together when height changes")
	app.distance_save_delay = -1
	app.save_settings()
	app.free()
	var restored = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	restored.set_process(false)
	check(restored.distance == 1.2 and not restored.right_stick_distance and restored.world.warmth == 1 and not restored.world.show_rug, "Room and view preferences survive reload")
	check(restored.world.spill_strength == 0, "Glow stays disabled after settings reload")
	check(is_equal_approx(restored.height_offset, 0.4) and is_equal_approx(restored.height_slider.value, 0.4), "Screen height and its slider survive settings reload")
	restored.distance_save_delay = -1
	restored.free()
	if settings_existed:
		var file := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		file.store_buffer(settings_backup)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	quit(1 if failures else 0)
