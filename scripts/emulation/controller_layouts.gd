extends RefCounted
## Controller layouts: which physical control presses which console button.
## A layout is {"buttons": {input: libretro id}, "left_stick": mode, "right_stick": mode}.
## Inputs are the controller's positions (bottom/right/left/top face buttons,
## shoulders, triggers, D-pad, Back/Start, L3) and each stick direction, used
## when that stick works as buttons. Stick modes: "analog" (the console's stick
## on the same side), "buttons" (four directions, bound like buttons) and, for
## the right stick, "left" (drives the console's main stick, for twin-stick play).
## R3 recentres the view and the L1 + R1 + Start chord opens the menu: neither
## can be taken away. Each console has a layout; a game may have its own.

const STORE := "user://controls.cfg"
const BUTTON_INPUTS := {
	"south": JOY_BUTTON_A, "east": JOY_BUTTON_B, "west": JOY_BUTTON_X, "north": JOY_BUTTON_Y,
	"l1": JOY_BUTTON_LEFT_SHOULDER, "r1": JOY_BUTTON_RIGHT_SHOULDER, "l3": JOY_BUTTON_LEFT_STICK,
	"back": JOY_BUTTON_BACK, "start": JOY_BUTTON_START,
	"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
}
const TRIGGER_INPUTS := {"l2": JOY_AXIS_TRIGGER_LEFT, "r2": JOY_AXIS_TRIGGER_RIGHT}
const STICK_DIRECTIONS := ["up", "down", "left", "right"]
## Every input, in the order the menu lists them.
const INPUT_LABELS := {
	"south": "Bottom button", "east": "Right button", "west": "Left button", "north": "Top button",
	"l1": "L1", "r1": "R1", "l2": "L2", "r2": "R2", "l3": "L3 (stick click)", "back": "Back", "start": "Start",
	"up": "D-pad up", "down": "D-pad down", "left": "D-pad left", "right": "D-pad right",
	"ls_up": "Left stick up", "ls_down": "Left stick down", "ls_left": "Left stick left", "ls_right": "Left stick right",
	"rs_up": "Right stick up", "rs_down": "Right stick down", "rs_left": "Right stick left", "rs_right": "Right stick right",
}
# Libretro joypad IDs.
const B := 0; const Y := 1; const SELECT := 2; const START := 3; const UP := 4; const DOWN := 5; const LEFT := 6; const RIGHT := 7
const A := 8; const X := 9; const L := 10; const R := 11; const L2 := 12; const R2 := 13; const L3 := 14; const R3 := 15

## The console's own names for the buttons each core reads, in menu order.
const NAMES := {
	"snes": [[B,"B"],[A,"A"],[Y,"Y"],[X,"X"],[L,"L"],[R,"R"],[SELECT,"Select"],[START,"Start"]],
	"nes": [[B,"B"],[A,"A"],[Y,"Turbo B"],[X,"Turbo A"],[SELECT,"Select"],[START,"Start"]],
	"megadrive": [[Y,"A"],[B,"B"],[A,"C"],[L,"X"],[X,"Y"],[R,"Z"],[SELECT,"Mode"],[START,"Start"]],
	"segacd": [[Y,"A"],[B,"B"],[A,"C"],[L,"X"],[X,"Y"],[R,"Z"],[SELECT,"Mode"],[START,"Start"]],
	"mastersystem": [[B,"Button 1"],[A,"Button 2"],[START,"Pause"]],
	"gamegear": [[B,"Button 1"],[A,"Button 2"],[START,"Start"]],
	"gameboy": [[B,"B"],[A,"A"],[SELECT,"Select"],[START,"Start"]],
	"gba": [[B,"B"],[A,"A"],[L,"L"],[R,"R"],[SELECT,"Select"],[START,"Start"]],
	"pcengine": [[B,"II"],[A,"I"],[Y,"III"],[X,"IV"],[L,"V"],[R,"VI"],[SELECT,"Select"],[START,"Run"]],
	"atari2600": [[B,"Fire"],[SELECT,"Select"],[START,"Reset"]],
	"atarilynx": [[B,"A"],[A,"B"],[L,"Option 1"],[R,"Option 2"],[START,"Pause"]],
	"ngpc": [[B,"A"],[A,"B"],[START,"Option"]],
	"vectrex": [[A,"1"],[B,"2"],[X,"3"],[Y,"4"]],
	"psx": [[B,"Cross"],[A,"Circle"],[Y,"Square"],[X,"Triangle"],[L,"L1"],[R,"R1"],[L2,"L2"],[R2,"R2"],[L3,"L3"],[R3,"R3"],[SELECT,"Select"],[START,"Start"]],
	# With the core's independent C-buttons (alt-map) on: see core_registry.gd.
	"n64": [[B,"A"],[Y,"B"],[L2,"Z"],[R2,"R"],[SELECT,"L"],[X,"C-Up"],[A,"C-Down"],[L,"C-Left"],[R,"C-Right"],[START,"Start"]],
}
const DPAD_NAMES := [[UP,"D-pad up"],[DOWN,"D-pad down"],[LEFT,"D-pad left"],[RIGHT,"D-pad right"]]

static func names(system: String) -> Array:
	return NAMES.get(system, NAMES.snes) + DPAD_NAMES

## Today's layout, unchanged: every face button, shoulder and Back/Start sends its
## usual Libretro button, triggers reach consoles that have them, and the left
## stick is analog on consoles with sticks and a second D-pad on the others.
static func standard(system: String, spec: Dictionary) -> Dictionary:
	if system == "n64": return standard_n64()
	var buttons := {"south": B, "east": A, "west": Y, "north": X, "l1": L, "r1": R, "back": SELECT, "start": START,
		"up": UP, "down": DOWN, "left": LEFT, "right": RIGHT}
	if spec.get("triggers", false): buttons.merge({"l2": L2, "r2": R2})
	if system == "psx": buttons["l3"] = L3
	var analog: bool = spec.get("analog", false)
	if not analog: buttons.merge({"ls_up": UP, "ls_down": DOWN, "ls_left": LEFT, "ls_right": RIGHT})
	return {"buttons": buttons, "left_stick": "analog" if analog else "buttons", "right_stick": "analog" if analog else "buttons"}

## The N64 pad on a modern controller: A and B on the bottom and left buttons,
## C-Down and C-Up on the right and top ones, Z on L2, R on R1 and R2, L on L1
## and Back, and the right stick as all four C-buttons.
static func standard_n64() -> Dictionary:
	return {"buttons": {"south": B, "west": Y, "east": A, "north": X, "l1": SELECT, "back": SELECT, "r1": R2, "r2": R2, "l2": L2,
		"start": START, "up": UP, "down": DOWN, "left": LEFT, "right": RIGHT}, "left_stick": "analog", "right_stick": "analog"}

## Built-in layouts: [id, name, help, layout]. Standard always comes first.
static func presets(system: String, spec: Dictionary) -> Array:
	var result := [["standard", "Standard", "The console's usual layout.", standard(system, spec)]]
	match system:
		"n64":
			# Super Smash Bros.: jump on face buttons instead of a flick of the C-stick.
			var smash := standard(system, spec)
			smash.buttons.merge({"l1": L2, "back": SELECT}, true)
			smash.right_stick = "buttons"
			result.append(["smash", "Smash Bros.", "A and B on the bottom and left buttons, jump (C-Up, C-Down) on the top and right buttons, shield (Z) on L1 and L2, grab (R) on R1 and R2, taunt (L) on Back. The right stick does nothing.", smash])
			# Twin-stick shooters: the right stick aims as the N64 stick, the left stick moves on the C-buttons.
			var twin := standard(system, spec)
			twin.buttons.merge({"r2": L2, "l2": R2, "ls_up": X, "ls_down": A, "ls_left": L, "ls_right": R}, true)
			twin.left_stick = "buttons"
			twin.right_stick = "left"
			result.append(["twin_stick", "Twin-stick shooter", "For GoldenEye 007 and Perfect Dark: the left stick moves and strafes (C-buttons), the right stick aims (the N64 stick), R2 fires (Z) and L2 aims (R).", twin])
		"psx":
			var digital := standard(system, spec)
			digital.buttons.merge({"ls_up": UP, "ls_down": DOWN, "ls_left": LEFT, "ls_right": RIGHT})
			digital.left_stick = "buttons"
			digital.right_stick = "buttons"
			result.append(["dpad_stick", "D-pad on left stick", "For games without analog support: the left stick works the D-pad.", digital])
	return result

static func preset(system: String, spec: Dictionary, id: String) -> Dictionary:
	for entry in presets(system, spec):
		if entry[0] == id: return entry[3].duplicate(true)
	return standard(system, spec)

## The preset a layout matches, or "custom".
static func preset_of(system: String, spec: Dictionary, layout: Dictionary) -> String:
	for entry in presets(system, spec):
		if same(entry[3], layout): return entry[0]
	return "custom"

static func same(first: Dictionary, second: Dictionary) -> bool:
	return first.left_stick == second.left_stick and first.right_stick == second.right_stick and first.buttons == second.buttons

## The layout in force: the game's own if it has one, else the console's.
static func resolve(system: String, spec: Dictionary, game: String) -> Dictionary:
	var config := ConfigFile.new()
	config.load(STORE)
	for entry in [["game", game], ["console", system]]:
		if entry[1].is_empty() or not config.has_section_key(entry[0], entry[1]): continue
		var saved = config.get_value(entry[0], entry[1])
		if valid(saved): return saved
	return standard(system, spec)

static func has_game_layout(game: String) -> bool:
	var config := ConfigFile.new()
	config.load(STORE)
	return not game.is_empty() and config.has_section_key("game", game)

## Saves a layout for the console (scope "console", key the system) or a game
## (scope "game", key its hash); a null layout removes it.
static func save(scope: String, key: String, layout) -> Error:
	var config := ConfigFile.new()
	config.load(STORE)
	if layout == null:
		if config.has_section_key(scope, key): config.erase_section_key(scope, key)
	else: config.set_value(scope, key, layout)
	return config.save(STORE)

static func valid(layout) -> bool:
	if not layout is Dictionary or not layout.get("buttons") is Dictionary: return false
	if not layout.get("left_stick") in ["analog", "buttons"] or not layout.get("right_stick") in ["analog", "buttons", "left"]: return false
	for input in layout.buttons:
		if not INPUT_LABELS.has(input) or not layout.buttons[input] is int or layout.buttons[input] < 0 or layout.buttons[input] > 15: return false
	return true

## Puts console button id on input alone: the input stops sending anything else
## and no other input sends id. A stick direction switches its stick to buttons.
static func assign(layout: Dictionary, input: String, id: int) -> void:
	for other in layout.buttons.keys():
		if layout.buttons[other] == id: layout.buttons.erase(other)
	layout.buttons[input] = id
	if input.begins_with("ls_"): layout.left_stick = "buttons"
	elif input.begins_with("rs_"): layout.right_stick = "buttons"

## The inputs that press console button id, in menu order.
static func inputs_of(layout: Dictionary, id: int) -> Array[String]:
	var found: Array[String] = []
	for input in INPUT_LABELS:
		if layout.buttons.get(input, -1) != id: continue
		if input.begins_with("ls_") and layout.left_stick != "buttons": continue
		if input.begins_with("rs_") and layout.right_stick != "buttons": continue
		found.append(input)
	return found

## The same as a readable list.
static func inputs_for(layout: Dictionary, id: int) -> String:
	var found := inputs_of(layout, id).map(func(input): return INPUT_LABELS[input])
	return ", ".join(found) if not found.is_empty() else "Not set"
