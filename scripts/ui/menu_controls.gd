extends RefCounted
## The Game controls page: the loaded console's layout and its presets, a layout
## for this game alone, stick modes, and press-to-assign for every console button.
const GameTitle = preload("res://scripts/content/game_title.gd")
const Layouts = preload("res://scripts/emulation/controller_layouts.gd")
const CAPTURE_SECONDS := 5.0
var host: Node
var menu: Control
## The console button waiting for a press, or -1; captures counts them so an old
## timeout cannot cancel a newer capture.
var capturing := -1
var capture_name := ""
var captures := 0

## True while the Games scope strip says This game; false for all the console's games.
func editing_game() -> bool:
	return menu.catalog.game_scope == 0

## The layout the page shows and edits: this game's (its own, or the console's
## it would start from) or the console's own.
func edited_layout() -> Dictionary:
	var emulator: Node = host.emulator
	if editing_game(): return emulator.controls
	return Layouts.resolve(emulator.system_id, emulator.Registry.SYSTEMS[emulator.system_id], "")

func rows() -> Array:
	var emulator: Node = host.emulator
	if not emulator.loaded:
		return [menu.catalog.unavailable(menu.catalog.action("controls.none","Game controls",func(): pass,"",true,""),
			"Start a game first: each console has its own layout, and a game can have its own too.")]
	var system: String = emulator.system_id
	var spec: Dictionary = emulator.Registry.SYSTEMS[system]
	var console: String = spec.get("short", spec.name)
	var layout: Dictionary = edited_layout()
	var own := Layouts.has_game_layout(emulator.rom_hash)
	var presets := Layouts.presets(system, spec)
	var current := Layouts.preset_of(system, spec, layout)
	var choices: Array = presets.map(func(entry): return entry[1])
	var index: int = presets.map(func(entry): return entry[0]).find(current)
	if current == "custom":
		choices.append("Custom")
		index = choices.size() - 1
	var where: String = ("This game's own layout." if own else "Changing anything here gives this game its own layout, starting from the %s one." % console) if editing_game() else ("Every %s game without its own layout uses this." % console + (" This game has its own, so it is not affected." if own else ""))
	var result := [
		{"id":"controls.preset","label":"Layout","kind":"choice","choices":choices,"default":0,"visual":false,"section_detail":where,
			"getter":func(): return index,
			"setter":func(value): if int(value) < presets.size(): apply(presets[int(value)][3].duplicate(true)),
			"help":presets[index][2] if index < presets.size() else "Your own changes. Choose a preset to start again from it."}]
	if spec.get("analog", false):
		result.append({"id":"controls.left_stick","label":"Left stick","kind":"choice","choices":["Analog stick","Buttons"],"default":0,"visual":false,
			"getter":func(): return 0 if layout.left_stick == "analog" else 1,
			"setter":func(value): set_stick("left_stick", "analog" if int(value) == 0 else "buttons"),
			"help":"Analog: the console's stick. Buttons: each direction presses the button you give it below."})
		result.append({"id":"controls.right_stick","label":"Right stick","kind":"choice","choices":["Analog stick","Buttons","Main stick"],"default":0,"visual":false,
			"getter":func(): return ["analog","buttons","left"].find(layout.right_stick),
			"setter":func(value): set_stick("right_stick", ["analog","buttons","left"][int(value)]),
			"help":"Analog: the console's second stick (the C-buttons on the N64). Buttons: each direction presses a button you choose, or nothing. Main stick: it moves the console's main stick, for twin-stick play."})
	for entry in Layouts.names(system):
		var id: int = entry[0]
		var name: String = entry[1]
		var inputs := Layouts.inputs_of(layout, id)
		var row: Dictionary = menu.catalog.action("controls.button.%d" % id, name, func(): start_capture(id, name),
			"%s: %s. Press {A}, then the button you want for it, or push a stick that way. Wait %d seconds to cancel." % [name, Layouts.inputs_for(layout, id), int(CAPTURE_SECONDS)],
			false, "Not set" if inputs.is_empty() else "")
		# Drawn as the controls themselves (face buttons as a diamond of circles).
		row["value_inputs"] = inputs
		result.append(row)
	result.append(menu.catalog.action("controls.reset","Reset to Standard",func(): apply(Layouts.standard(system, spec)),
		"Puts back the console's usual layout for %s." % ("this game" if editing_game() else "all %s games" % console),current == "standard",""))
	# Removing this game's own layout is its own step, and asks first: changing
	# the scope above never deletes anything.
	result.append(menu.catalog.unavailable(menu.catalog.action("controls.remove_game","Remove this game's layout…",remove_game_layout,
		"%s goes back to the %s layout. Other games are not affected." % [GameTitle.of(emulator.rom_path), console],not own,""),"This game already uses the %s layout." % console))
	return result

func remove_game_layout() -> void:
	var emulator: Node = host.emulator
	var spec: Dictionary = emulator.Registry.SYSTEMS[emulator.system_id]
	menu.ask("Remove this game's layout?", "%s goes back to the %s layout. Other games are not affected." % [GameTitle.of(emulator.rom_path), spec.get("short", spec.name)], func():
		if Layouts.save("game", emulator.rom_hash, null) != OK:
			menu.show_error("Could not save the controller layout. Check free space.")
			return
		emulator.reload_controls()
		menu.refresh())

## Saves a layout where the page is editing (this game, or the console's games) and uses it.
func apply(layout: Dictionary) -> void:
	var emulator: Node = host.emulator
	var to_game := editing_game()
	if Layouts.save("game" if to_game else "console", emulator.rom_hash if to_game else emulator.system_id, layout) != OK:
		menu.show_error("Could not save the controller layout. Check free space.")
		return
	emulator.reload_controls()
	menu.refresh()

func set_stick(side: String, value: String) -> void:
	var layout: Dictionary = edited_layout().duplicate(true)
	layout[side] = value
	apply(layout)

func start_capture(id: int, name: String) -> void:
	capturing = id
	capture_name = name
	captures += 1
	var ticket := captures
	menu.notify("Press the button for %s, or push a stick…" % name)
	host.get_tree().create_timer(CAPTURE_SECONDS).timeout.connect(func():
		if capturing >= 0 and captures == ticket:
			capturing = -1
			menu.notify("Nothing pressed: %s is unchanged." % name))

## While a button waits for a press, every controller event is the answer:
## the first button, trigger or stick push is assigned. True when it took the event.
func handle(event: InputEvent) -> bool:
	if capturing < 0: return false
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		capturing = -1
		menu.notify("%s is unchanged." % capture_name)
		return true
	var input := ""
	if event is InputEventJoypadButton:
		if not event.pressed: return true
		# R3 recentres the view: it is never a game button.
		if event.button_index == JOY_BUTTON_RIGHT_STICK:
			menu.notify("The right stick click recentres the view; choose another button.")
			return true
		for name in Layouts.BUTTON_INPUTS:
			if Layouts.BUTTON_INPUTS[name] == event.button_index: input = name
	elif event is InputEventJoypadMotion:
		for name in Layouts.TRIGGER_INPUTS:
			if Layouts.TRIGGER_INPUTS[name] == event.axis and event.axis_value > 0.6: input = name
		if absf(event.axis_value) > 0.7:
			match event.axis:
				JOY_AXIS_LEFT_X: input = "ls_left" if event.axis_value < 0 else "ls_right"
				JOY_AXIS_LEFT_Y: input = "ls_up" if event.axis_value < 0 else "ls_down"
				JOY_AXIS_RIGHT_X: input = "rs_left" if event.axis_value < 0 else "rs_right"
				JOY_AXIS_RIGHT_Y: input = "rs_up" if event.axis_value < 0 else "rs_down"
	else: return false
	if input.is_empty(): return true
	var id := capturing
	capturing = -1
	var layout: Dictionary = edited_layout().duplicate(true)
	Layouts.assign(layout, input, id)
	apply(layout)
	# The assigned control stays latched until released, so it cannot also act in the menu.
	menu.clear_input()
	menu.notify("%s: %s" % [capture_name, Layouts.INPUT_LABELS[input]])
	return true
