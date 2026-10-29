extends RefCounted
const Layouts = preload("res://scripts/emulation/controller_layouts.gd")
## Normalized Xbox/Deck positions -> SNES B,Y,Select,Start,Up,Down,Left,Right,A,X,L,R.
const BUTTONS := {
	JOY_BUTTON_A: 0, JOY_BUTTON_X: 1, JOY_BUTTON_BACK: 2, JOY_BUTTON_START: 3,
	JOY_BUTTON_DPAD_UP: 4, JOY_BUTTON_DPAD_DOWN: 5,
	JOY_BUTTON_DPAD_LEFT: 6, JOY_BUTTON_DPAD_RIGHT: 7,
	JOY_BUTTON_B: 8, JOY_BUTTON_Y: 9,
	JOY_BUTTON_LEFT_SHOULDER: 10, JOY_BUTTON_RIGHT_SHOULDER: 11,
}
const MENU_BUTTONS := [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_START]
const STICK_DEADZONE := 0.25
## Analog sticks pass through for consoles that have them, with a small radial
## deadzone so a resting stick reads as centred.
const ANALOG_DEADZONE := 0.12
const TRIGGER_THRESHOLD := 0.5
## L2/R2 in the Libretro joypad mask, from the analog triggers.
const TRIGGER_BITS := {JOY_AXIS_TRIGGER_LEFT: 12, JOY_AXIS_TRIGGER_RIGHT: 13}
var active_device := -1
## The playing console uses the right stick, so it does not move the TV.
var right_stick_game := false
var devices: Dictionary = {}
var menu_active := false

func handle_event(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return false
	var id := event.device
	if not devices.has(id):
		devices[id] = {"buttons": {}, "blocked": {}, "axes": Vector2.ZERO, "right": Vector2.ZERO, "triggers": {}, "view_axis": 0.0, "view_blocked": false, "chord": false}
	var state: Dictionary = devices[id]
	if event is InputEventJoypadButton:
		state.buttons[event.button_index] = event.pressed
		if event.pressed: active_device = id
		else: state.blocked.erase(event.button_index)
	else:
		if event.axis == JOY_AXIS_LEFT_X: state.axes.x = event.axis_value
		elif event.axis == JOY_AXIS_LEFT_Y: state.axes.y = event.axis_value
		elif event.axis == JOY_AXIS_RIGHT_X: state.right.x = event.axis_value
		elif event.axis == JOY_AXIS_RIGHT_Y:
			state.right.y = event.axis_value
			state.view_axis = event.axis_value
			if absf(event.axis_value) <= STICK_DEADZONE: state.view_blocked = false
		elif TRIGGER_BITS.has(event.axis): state.triggers[event.axis] = event.axis_value
		else: return false
		if absf(event.axis_value) > STICK_DEADZONE: active_device = id
	var held := 0
	for button in MENU_BUTTONS:
		if state.buttons.get(button, false): held += 1
	if state.chord:
		if held == 0: state.chord = false
		return false
	if held == MENU_BUTTONS.size():
		state.chord = true
		return true
	return false

func set_menu_active(value: bool) -> void:
	menu_active = value
	# Menu actions must be released before they can become game actions again.
	for state in devices.values():
		state.view_blocked = absf(float(state.view_axis)) > STICK_DEADZONE
		for button in state.buttons:
			if state.buttons[button]: state.blocked[button] = true

func view_distance_axis() -> float:
	if menu_active or right_stick_game or not devices.has(active_device): return 0.0
	var state: Dictionary = devices[active_device]
	if state.view_blocked: return 0.0
	var value: float = state.view_axis
	return signf(value) * maxf(0.0, (absf(value) - STICK_DEADZONE) / (1.0 - STICK_DEADZONE))

## stick_dpad: the left stick also works the D-pad (consoles without sticks).
func mask(stick_dpad := true) -> int:
	if menu_active or not devices.has(active_device): return 0
	var state: Dictionary = devices[active_device]
	var result := 0
	for button in BUTTONS:
		if state.buttons.get(button, false) and not state.blocked.has(button):
			if state.chord and button in MENU_BUTTONS: continue
			result |= 1 << BUTTONS[button]
	for axis in TRIGGER_BITS:
		if float(state.triggers.get(axis, 0.0)) > TRIGGER_THRESHOLD: result |= 1 << TRIGGER_BITS[axis]
	if stick_dpad:
		if state.axes.x < -STICK_DEADZONE: result |= 1 << 6
		if state.axes.x > STICK_DEADZONE: result |= 1 << 7
		if state.axes.y < -STICK_DEADZONE: result |= 1 << 4
		if state.axes.y > STICK_DEADZONE: result |= 1 << 5
	if result & (1 << 4) and result & (1 << 5): result &= ~((1 << 4) | (1 << 5))
	if result & (1 << 6) and result & (1 << 7): result &= ~((1 << 6) | (1 << 7))
	return result

## The console's input under a controller layout (see controller_layouts.gd):
## {"mask": Libretro button bits, "analog": left X/Y, right X/Y}.
func read(layout: Dictionary) -> Dictionary:
	var result := {"mask": 0, "analog": PackedInt32Array([0, 0, 0, 0])}
	if menu_active or not devices.has(active_device): return result
	var state: Dictionary = devices[active_device]
	var bindings: Dictionary = layout.buttons
	var mask := 0
	for input in Layouts.BUTTON_INPUTS:
		var button: int = Layouts.BUTTON_INPUTS[input]
		if not bindings.has(input) or not state.buttons.get(button, false) or state.blocked.has(button): continue
		if state.chord and button in MENU_BUTTONS: continue
		mask |= 1 << bindings[input]
	for input in Layouts.TRIGGER_INPUTS:
		if bindings.has(input) and float(state.triggers.get(Layouts.TRIGGER_INPUTS[input], 0.0)) > TRIGGER_THRESHOLD: mask |= 1 << bindings[input]
	var sticks := analog()
	var analog_out := PackedInt32Array([0, 0, 0, 0])
	for side in [["ls_", layout.left_stick, state.axes, 0], ["rs_", layout.right_stick, state.right, 2]]:
		match side[1]:
			"analog": analog_out[side[3]] = sticks[side[3]]; analog_out[side[3] + 1] = sticks[side[3] + 1]
			"left": analog_out[0] = sticks[side[3]]; analog_out[1] = sticks[side[3] + 1]
			"buttons":
				var stick: Vector2 = side[2]
				var pushed := {"up": stick.y < -STICK_DEADZONE, "down": stick.y > STICK_DEADZONE, "left": stick.x < -STICK_DEADZONE, "right": stick.x > STICK_DEADZONE}
				for direction in Layouts.STICK_DIRECTIONS:
					var input: String = side[0] + direction
					if pushed[direction] and bindings.has(input): mask |= 1 << bindings[input]
	# Opposite D-pad directions cancel, as on a real pad.
	if mask & (1 << 4) and mask & (1 << 5): mask &= ~((1 << 4) | (1 << 5))
	if mask & (1 << 6) and mask & (1 << 7): mask &= ~((1 << 6) | (1 << 7))
	result.mask = mask
	result.analog = analog_out
	return result

## Left X, left Y, right X, right Y in Libretro's -32768..32767 range (down is positive).
func analog() -> PackedInt32Array:
	var result := PackedInt32Array([0, 0, 0, 0])
	if menu_active or not devices.has(active_device): return result
	var state: Dictionary = devices[active_device]
	var sticks: Array[Vector2] = [state.axes, state.right]
	for index in range(2):
		var stick: Vector2 = sticks[index]
		var length := minf(stick.length(), 1.0)
		if length <= ANALOG_DEADZONE: continue
		stick = stick.normalized() * (length - ANALOG_DEADZONE) / (1.0 - ANALOG_DEADZONE)
		result[index * 2] = clampi(roundi(stick.x * 32767.0), -32768, 32767)
		result[index * 2 + 1] = clampi(roundi(stick.y * 32767.0), -32768, 32767)
	return result

func disconnect_device(id: int) -> void:
	devices.erase(id)
	if active_device == id: active_device = -1

func clear() -> void:
	devices.clear()
	active_device = -1
