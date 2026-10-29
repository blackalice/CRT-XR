extends SceneTree
## Controller layouts: the standard layout reproduces the old fixed mapping
## exactly, presets do what they say, assigning moves a button, layouts are
## kept per console with per-game overrides, and the menu captures a press.
const Layouts = preload("res://scripts/emulation/controller_layouts.gd")
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Gamepad = preload("res://scripts/emulation/gamepad_input.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")

func button(pad, index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 1; event.button_index = index; event.pressed = pressed
	pad.handle_event(event)

func axis(pad, which: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 1; event.axis = which; event.axis_value = value
	pad.handle_event(event)

## The mapping before layouts existed: mask(stick D-pad unless the console has
## sticks), L2/R2 only for consoles with triggers, sticks only for analog consoles.
func old_input(pad, spec: Dictionary) -> Array:
	var mask: int = pad.mask(not spec.get("analog", false))
	if not spec.get("triggers", false): mask &= ~((1 << 12) | (1 << 13))
	return [mask, pad.analog() if spec.get("analog", false) else PackedInt32Array([0, 0, 0, 0])]

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Layouts.STORE))
	var random := RandomNumberGenerator.new()
	random.seed = 64
	var buttons := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
		JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_LEFT_STICK]
	var axes := [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
	for system in ["snes", "nes", "megadrive", "gameboy", "psx", "n64"]:
		var spec: Dictionary = Registry.SYSTEMS[system]
		var layout := Layouts.standard(system, spec)
		var pad = Gamepad.new()
		var same := true
		for trial in range(400):
			for index in buttons: button(pad, index, random.randf() < 0.3)
			for which in axes: axis(pad, which, random.randf_range(-1.0, 1.0) if random.randf() < 0.5 else 0.0)
			var read: Dictionary = pad.read(layout)
			var old := old_input(pad, spec)
			# Libretro's L3 on PlayStation is new: the old mapping never sent it.
			var mask: int = read.mask & ~(1 << 14)
			if mask != old[0] or read.analog != old[1]: same = false
		check(same, "The standard layout sends exactly the old input: " + system)
		check(Layouts.valid(layout) and Layouts.preset_of(system, spec, layout) == "standard", "The standard layout is valid and recognised: " + system)

	var n64: Dictionary = Registry.SYSTEMS.n64
	var smash := Layouts.preset("n64", n64, "smash")
	var pad = Gamepad.new()
	button(pad, JOY_BUTTON_Y, true)
	check(pad.read(smash).mask == 1 << Layouts.X, "Smash: the top button is C-Up (jump)")
	button(pad, JOY_BUTTON_Y, false)
	axis(pad, JOY_AXIS_RIGHT_Y, -1.0)
	var quiet: Dictionary = pad.read(smash)
	check(quiet.mask == 0 and quiet.analog == PackedInt32Array([0, 0, 0, 0]), "Smash: the right stick does nothing")
	var twin := Layouts.preset("n64", n64, "twin_stick")
	axis(pad, JOY_AXIS_RIGHT_X, 1.0); axis(pad, JOY_AXIS_RIGHT_Y, 0.0)
	axis(pad, JOY_AXIS_LEFT_Y, -1.0)
	var aiming: Dictionary = pad.read(twin)
	check(aiming.analog[0] == 32767 and aiming.analog[2] == 0, "Twin-stick: the right stick drives the N64 stick")
	check(aiming.mask & (1 << Layouts.X) != 0, "Twin-stick: left stick up is C-Up (forward)")
	axis(pad, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	check(pad.read(twin).mask & (1 << Layouts.L2) != 0, "Twin-stick: R2 fires (Z)")

	var layout := Layouts.standard("n64", n64)
	Layouts.assign(layout, "north", Layouts.L2)
	check(layout.buttons.north == Layouts.L2 and not layout.buttons.has("l2") and Layouts.inputs_for(layout, Layouts.X) == "Not set", "Assigning moves Z to the top button and frees what it replaced")
	Layouts.assign(layout, "rs_up", Layouts.X)
	check(layout.right_stick == "buttons" and Layouts.inputs_for(layout, Layouts.X) == "Right stick up", "Assigning a stick direction turns that stick to buttons")
	check(Layouts.preset_of("n64", n64, layout) == "custom", "A changed layout is Custom")

	var hash := "f".repeat(64)
	check(Layouts.resolve("n64", n64, hash) == Layouts.standard("n64", n64), "With nothing saved a console uses its standard layout")
	Layouts.save("console", "n64", smash)
	check(Layouts.resolve("n64", n64, hash) == smash, "A console layout applies to its games")
	Layouts.save("game", hash, twin)
	check(Layouts.resolve("n64", n64, hash) == twin and Layouts.resolve("n64", n64, "e".repeat(64)) == smash, "A game's own layout wins for that game only")
	Layouts.save("game", hash, null)
	check(Layouts.resolve("n64", n64, hash) == smash and not Layouts.has_game_layout(hash), "Removing a game's layout returns it to the console's")
	Layouts.save("console", "n64", {"buttons": {"south": 99}, "left_stick": "analog", "right_stick": "analog"})
	check(Layouts.resolve("n64", n64, hash) == Layouts.standard("n64", n64), "A damaged saved layout is ignored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Layouts.STORE))

	# Press-to-assign in the real menu.
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	await process_frame
	await process_frame
	check(app.emulator.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")), "A SNES game loads")
	if not app.menu.visible: app.toggle_settings()
	var rows: Array = app.menu.controls.rows()
	check(rows.any(func(row): return row.id == "controls.button.%d" % Layouts.X and row.label == "X"), "The page lists the console's own button names")
	app.menu.controls.start_capture(Layouts.X, "X")
	var press := InputEventJoypadButton.new()
	press.device = 1; press.button_index = JOY_BUTTON_RIGHT_STICK; press.pressed = true
	check(app.menu.handle(press) and app.menu.controls.capturing == Layouts.X, "R3 is refused: it recentres the view")
	press.button_index = JOY_BUTTON_LEFT_SHOULDER
	check(app.menu.handle(press) and app.menu.controls.capturing == -1, "The next button press is taken")
	check(app.emulator.controls.buttons.l1 == Layouts.X and Layouts.resolve("snes", Registry.SYSTEMS.snes, "") .buttons.l1 == Layouts.X, "SNES X is now on L1, saved for the console")
	app.menu.controls.start_capture(Layouts.A, "A")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE; escape.pressed = true
	check(app.menu.handle(escape) and app.menu.controls.capturing == -1 and app.emulator.controls.buttons.east == Layouts.A, "Escape cancels and leaves the button as it was")
	app.menu.controls.set_game_layout(true)
	check(Layouts.has_game_layout(app.emulator.rom_hash), "This game can keep its own layout")
	app.menu.controls.apply(Layouts.standard("snes", Registry.SYSTEMS.snes))
	check(app.emulator.controls == Layouts.standard("snes", Registry.SYSTEMS.snes) and Layouts.resolve("snes", Registry.SYSTEMS.snes, "").buttons.l1 == Layouts.X, "Changes then go to the game, not the console")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Layouts.STORE))
	app.queue_free()
	await process_frame
	print("CONTROLLER LAYOUT CHECKS COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
