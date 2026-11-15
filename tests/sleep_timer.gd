extends SceneTree
## The sleep timer switches the TV off; any input wakes it. The idle menu can
## switch the TV off instead of showing the logo.
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func settle(frames := 4) -> void:
	for i in range(frames): await process_frame
func run():
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle(10)
	app.apply_settings(ConfigFile.new()); app.use_tracking(false)
	app.set_sleep_timer(15)
	check(app.sleep_minutes == 15 and is_equal_approx(app.sleep_left, 900.0), "Fifteen minutes is set")
	app.sleep_left = 0.01
	await settle()
	check(app.tv_asleep and app.sleep_minutes == 0, "When it runs out, the TV sleeps and the timer is off")
	check(not app.settings_panel.visible, "The menu closes as the TV switches off")
	var press := InputEventJoypadButton.new(); press.button_index = JOY_BUTTON_A; press.pressed = true
	app._input(press)
	check(not app.tv_asleep and app.settings_panel.visible, "Any button wakes the TV into the menu")
	check(is_equal_approx(float(app.world.screen_material.get_shader_parameter("power_off")), 0.0), "The tube is on again")
	app.set_sleep_timer(0)
	check(app.sleep_left == 0.0, "Off clears the timer")
	var rows: Array = app.menu.catalog.pages(2)[2].rows
	check(rows.any(func(row): return row.id == "music.sleep"), "Sound → Music offers the sleep timer")
	# Idle menu: Switch the TV off.
	app.menu_screensaver = true; app.menu_screensaver_style = 1; app.menu_screensaver_delay = 0.05
	app.menu.idle_time = 1.0
	await settle()
	check(app.tv_asleep and app.settings_panel.visible and app.settings_panel.modulate.a == 0.0, "An idle menu can switch the TV off, hiding the menu")
	app._input(press)
	check(not app.tv_asleep and app.settings_panel.modulate.a == 1.0, "and wakes with the menu back")
	app.free(); await settle()
	print("SLEEP TIMER: %d failures" % failures)
	quit(1 if failures else 0)
