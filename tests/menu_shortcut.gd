extends SceneTree
## Holding Select opens the menu when turned on; a quick press does not.
const Gamepad = preload("res://scripts/emulation/gamepad_input.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func press(pad, button: int, down: bool):
	var e := InputEventJoypadButton.new(); e.device = 3; e.button_index = button; e.pressed = down
	return pad.handle_event(e)
func run():
	var pad = Gamepad.new()
	press(pad, JOY_BUTTON_BACK, true)
	var t := Time.get_ticks_msec()
	check(not pad.poll_hold_select(t + 2000), "Off by default: holding Select does nothing")
	pad.menu_hold_select = true
	press(pad, JOY_BUTTON_BACK, false); press(pad, JOY_BUTTON_BACK, true)
	t = Time.get_ticks_msec()
	check(not pad.poll_hold_select(t + 200), "A quick press is not the shortcut")
	check(pad.poll_hold_select(t + 700), "Holding Select past 0.6 s opens the menu")
	check(not pad.poll_hold_select(t + 1500), "It fires once per hold")
	press(pad, JOY_BUTTON_BACK, false)
	check(not pad.poll_hold_select(t + 3000), "Released, nothing more happens")
	var chord := false
	for b in pad.MENU_BUTTONS: chord = press(pad, b, true) or chord
	check(chord, "L1 + R1 + Start still opens the menu")
	print("MENU SHORTCUT: %d failures" % failures)
	quit(1 if failures else 0)
