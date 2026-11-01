extends SceneTree
var app
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func settle() -> void:
	for i in range(8): await process_frame
func shoulder(code: int, pressed := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code; event.device = 7; event.pressed = pressed
	app.menu.handle(event)
func trigger(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis; event.axis_value = value; event.device = 7
	app.menu.handle(event)
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await settle()
	app.menu_sounds = true
	var menu = app.menu
	menu.open_settings(); menu.category = 9; menu.subsection = 0; menu.render()
	await settle()
	check(menu.catalog.pages(9)[2].title == "Audio & vibration", "Menu section is named Audio & vibration")
	for code in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var before: int = menu.category
		menu.sound_player.stop()
		shoulder(code)
		check(menu.category != before and menu.sound_player.playing and menu.sound_player.stream == menu.NAV_CLICK, "Shoulder change uses supplied click: " + str(code))
		menu.sound_player.stop(); shoulder(code)
		check(not menu.sound_player.playing, "Holding a shoulder never repeats its click")
		shoulder(code, false)
	menu.category = 9; menu.subsection = 0; menu.render()
	await settle()
	for axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		var before: int = menu.subsection
		menu.sound_player.stop(); trigger(axis, 1.0)
		check(menu.subsection != before and menu.sound_player.playing and menu.sound_player.stream == menu.NAV_CLICK, "Trigger change uses supplied click: " + str(axis))
		menu.sound_player.stop(); trigger(axis, 0.9)
		check(not menu.sound_player.playing, "Held trigger produces one click until released")
		trigger(axis, 0.0)
	app.menu_sounds = false
	menu.sound_player.stop(); shoulder(JOY_BUTTON_LEFT_SHOULDER); shoulder(JOY_BUTTON_LEFT_SHOULDER, false)
	check(not menu.sound_player.playing, "Menu Sounds Off silences navigation clicks")
	app.menu_sounds = true
	menu.preview = true; menu.sound_player.stop()
	shoulder(JOY_BUTTON_LEFT_SHOULDER); shoulder(JOY_BUTTON_LEFT_SHOULDER, false); trigger(JOY_AXIS_TRIGGER_LEFT, 1.0); trigger(JOY_AXIS_TRIGGER_LEFT, 0.0)
	check(not menu.sound_player.playing, "Preview ignores shoulder/trigger actions without clicking")
	menu.preview = false; menu.category = 4; menu.subsection = 0; menu.render()
	# Controls has a single page: no subsection action, so no click.
	if menu.catalog.pages(menu.category).size() == 1:
		menu.sound_player.stop(); trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0); trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0)
		check(not menu.sound_player.playing, "A single-page category does not click for a nonexistent subsection")
	menu.open_pause(); menu.sound_player.stop()
	shoulder(JOY_BUTTON_RIGHT_SHOULDER); shoulder(JOY_BUTTON_RIGHT_SHOULDER, false); trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	check(not menu.sound_player.playing, "Home has no shoulder/trigger action and stays silent")
	app.free()
	print("NAVIGATION SOUND: ", failures, " failures")
	quit(1 if failures else 0)
