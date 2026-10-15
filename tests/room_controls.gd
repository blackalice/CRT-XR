extends SceneTree
const UI=preload("res://tests/menu_test_helpers.gd")
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
	var legacy := ConfigFile.new()
	legacy.set_value("crt","screen_spill",0.0)
	legacy.save("user://settings.cfg")
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	check(app.world.spill_strength == 0, "Legacy global Off migrates to room lighting")
	app.close_settings()
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
	UI.set_value(app,"room.cabinet_grain_strength",.8)
	check(is_equal_approx(app.world.cabinet_grain_strength,.8), "Plastic grain strength is adjustable")
	UI.reset(app,"room.cabinet_grain_strength")
	check(is_equal_approx(app.world.cabinet_grain_strength,.55), "Per-option reset restores subtle plastic grain")
	UI.set_value(app,"room.cabinet_ao_strength",.4)
	check(is_equal_approx(app.world.cabinet_ao_strength,.4), "Casing bake strength is adjustable")
	UI.reset(app,"room.cabinet_ao_strength")
	check(is_equal_approx(app.world.cabinet_ao_strength,.70), "Per-option reset restores the baked shading default")
	UI.set_value(app,"room.shadow_strength",.35)
	check(is_equal_approx(app.world.key_light.shadow_opacity,.35), "Shadow darkness control changes real lamp shadows")
	UI.reset(app,"room.shadow_strength")
	check(is_equal_approx(app.world.key_light.shadow_opacity,.60) and not app.world.key_light.shadow_enabled, "Shadow reset softens contrast without re-enabling disabled shadows")
	UI.set_value(app,"room.shadow_strength",.35)
	UI.set_value(app,"room.spill_strength",.28)
	check(is_equal_approx(app.world.screen_light.strength,.28), "Room slider changes the native light strength")
	var previous_ambient: float = app.world.ambient
	UI.reset(app,"room.spill_strength")
	check(is_equal_approx(app.world.spill_strength,.10) and app.world.ambient == previous_ambient, "Per-option default resets screen light without changing room ambience")
	UI.set_value(app,"room.spill_strength",.24)
	check(app.capture_settings().has_section_key("room","spill_strength") and not app.capture_settings().has_section_key("crt","screen_spill"), "Screen light saves globally with room preferences")
	check(is_equal_approx(app.world.spill_strength,.24) and app.world.screen_light.lights.size() == 2, "Screen spill controls two native lights")
	check(app.world.screen_light.find_children("*", "SubViewport").is_empty(), "Screen spill needs no GPU averaging viewport")
	var original_distance: float = app.distance
	var eye_y: float = app.eyes[0].position.y
	UI.set_value(app,"view.height_offset",0.4)
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
	restored.close_settings()
	restored.set_process(false)
	check(restored.distance == 1.2 and not restored.right_stick_distance and restored.world.warmth == 1 and not restored.world.show_rug, "Room and view preferences survive reload")
	check(is_equal_approx(restored.world.shadow_strength,.35), "Shadow darkness survives preferences reload")
	check(is_equal_approx(restored.world.spill_strength,.24), "Screen spill strength survives settings reload")
	check(is_equal_approx(restored.height_offset, 0.4) and is_equal_approx(UI.get_value(restored,"view.height_offset"), 0.4), "Screen height and its slider survive settings reload")
	restored.distance_save_delay = -1
	restored.free()
	if settings_existed:
		var file := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		file.store_buffer(settings_backup)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	quit(1 if failures else 0)
