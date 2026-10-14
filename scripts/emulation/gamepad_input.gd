extends RefCounted
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
var active_device := -1
var devices: Dictionary = {}
var menu_active := false

func handle_event(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return false
	var id := event.device
	if not devices.has(id):
		devices[id] = {"buttons": {}, "blocked": {}, "axes": Vector2.ZERO, "view_axis": 0.0, "view_blocked": false, "chord": false}
	var state: Dictionary = devices[id]
	if event is InputEventJoypadButton:
		state.buttons[event.button_index] = event.pressed
		if event.pressed: active_device = id
		else: state.blocked.erase(event.button_index)
	else:
		if event.axis == JOY_AXIS_LEFT_X: state.axes.x = event.axis_value
		elif event.axis == JOY_AXIS_LEFT_Y: state.axes.y = event.axis_value
		elif event.axis == JOY_AXIS_RIGHT_Y:
			state.view_axis = event.axis_value
			if absf(event.axis_value) <= STICK_DEADZONE: state.view_blocked = false
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
	if menu_active or not devices.has(active_device): return 0.0
	var state: Dictionary = devices[active_device]
	if state.view_blocked: return 0.0
	var value: float = state.view_axis
	return signf(value) * maxf(0.0, (absf(value) - STICK_DEADZONE) / (1.0 - STICK_DEADZONE))

func mask() -> int:
	if menu_active or not devices.has(active_device): return 0
	var state: Dictionary = devices[active_device]
	var result := 0
	for button in BUTTONS:
		if state.buttons.get(button, false) and not state.blocked.has(button):
			if state.chord and button in MENU_BUTTONS: continue
			result |= 1 << BUTTONS[button]
	if state.axes.x < -STICK_DEADZONE: result |= 1 << 6
	if state.axes.x > STICK_DEADZONE: result |= 1 << 7
	if state.axes.y < -STICK_DEADZONE: result |= 1 << 4
	if state.axes.y > STICK_DEADZONE: result |= 1 << 5
	if result & (1 << 4) and result & (1 << 5): result &= ~((1 << 4) | (1 << 5))
	if result & (1 << 6) and result & (1 << 7): result &= ~((1 << 6) | (1 << 7))
	return result

func disconnect_device(id: int) -> void:
	devices.erase(id)
	if active_device == id: active_device = -1

func clear() -> void:
	devices.clear()
	active_device = -1
