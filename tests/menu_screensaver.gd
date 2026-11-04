extends SceneTree
## The menu screensaver (scripts/ui/menu_screensaver.gd): it starts after the
## chosen idle time, the logo bounces inside the panel and changes colour at
## each edge, any input wakes the menu without acting on it, and the on/off
## and delay settings are saved.
var app
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func settle() -> void:
	for i in range(8): await process_frame

func press(button: int, down := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button; event.pressed = down
	app._input(event)

func run() -> void:
	# Defaults, not what an earlier run saved: the settings store falls back to
	# the backup when settings.cfg is missing.
	for name in ["user://settings.cfg", "user://settings.cfg.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(name))
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.use_tracking(false)
	var menu = app.menu
	if not app.settings_panel.visible: app.toggle_settings()
	await settle()
	if is_instance_valid(menu.boot): menu.boot.finish()
	await settle()
	check(app.menu_screensaver and is_equal_approx(app.menu_screensaver_delay, 120.0), "The screensaver is on by default and waits two minutes")
	check(not is_instance_valid(menu.screensaver), "No screensaver straight after opening the menu")

	# Idle past the delay.
	app.menu_screensaver_delay = 30.0
	menu.idle_time = 30.0
	await settle()
	var saver = menu.screensaver
	check(is_instance_valid(saver), "The screensaver starts once the menu has been idle for the delay")
	check(is_instance_valid(saver) and saver.layout.modulate.a == 0.0, "The page is hidden while the screensaver runs")
	check(menu.backdrop.visible, "The space backdrop stays behind the logo")

	# Bounce: drive the logo into the right edge and confirm it turns and recolours.
	var limit: Vector2 = saver.room()
	saver.logo.position = Vector2(limit.x - 1.0, limit.y * 0.5)
	saver.velocity = Vector2(saver.SPEED, saver.SPEED)
	check(saver.logo.get_child_count() == 3, "The logo carries its three diamonds")
	var colour: Color = saver.logo.self_modulate
	saver.step(0.1)
	check(saver.velocity.x < 0.0, "The logo turns back at the right edge")
	check(saver.logo.self_modulate != colour, "The logo changes colour when it bounces")
	check(saver.logo.modulate == Color.WHITE, "The diamonds keep their own colours")
	var inside := true
	for i in range(2000):
		saver.step(1.0 / 60.0)
		var at: Vector2 = saver.logo.position
		if at.x < 0.0 or at.y < 0.0 or at.x > limit.x or at.y > limit.y: inside = false
	check(inside, "The logo stays inside the panel")

	# Waking: the press only brings the menu back.
	var selected: String = menu.selected_id
	var mode: String = menu.mode
	press(JOY_BUTTON_A)
	press(JOY_BUTTON_A, false)
	await settle()
	check(not is_instance_valid(menu.screensaver), "A button press ends the screensaver")
	check(menu.heading.get_parent().get_parent().modulate.a > 0.99, "The page is back at once")
	check(menu.mode == mode and menu.selected_id == selected, "The waking press does not act on the menu")
	check(menu.idle_time < 1.0, "Waking restarts the idle timer")

	# Turned off, it never starts.
	app.menu_screensaver = false
	menu.idle_time = 1000.0
	await settle()
	check(not is_instance_valid(menu.screensaver), "Turned off, the screensaver does not start")
	app.menu_screensaver = true
	menu.idle_time = 1000.0
	await settle()
	check(is_instance_valid(menu.screensaver), "Turned back on, it starts again")
	app.close_settings()
	await settle()
	check(not is_instance_valid(menu.screensaver), "Closing the menu ends the screensaver")

	# Saved settings.
	app.menu_screensaver = false
	app.menu_screensaver_delay = 600.0
	app.save_settings()
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	check(config.get_value("accessibility", "menu_screensaver") == false and is_equal_approx(float(config.get_value("accessibility", "menu_screensaver_delay")), 600.0), "On/off and delay are saved")
	app.menu_screensaver = true
	app.menu_screensaver_delay = 30.0
	app.apply_settings(config)
	check(not app.menu_screensaver and is_equal_approx(app.menu_screensaver_delay, 600.0), "On/off and delay are restored")
	config.set_value("accessibility", "menu_screensaver_delay", 7.0)
	app.apply_settings(config)
	check(is_equal_approx(app.menu_screensaver_delay, 120.0), "An unknown delay falls back to two minutes")

	print("MENU SCREENSAVER: ", failures, " failures")
	quit(1 if failures else 0)
