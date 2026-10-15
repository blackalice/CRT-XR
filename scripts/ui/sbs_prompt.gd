extends Control
signal proceed_requested

const READY_EXIT_CODE := 10
var manual_confirmation := false
var waiting_time := 0.0
var help: Label
var in_place := false
var darkened := false
var proceeding := false
var content: Control
var gate := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	content = center
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	var heading := Label.new()
	heading.text = "SWITCH TO SBS NOW"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 42)
	column.add_child(heading)
	var instructions := Label.new()
	instructions.text = "Glasses detected. Use the glasses’ SBS button.\n" + (
		"Press A after switching to continue." if manual_confirmation else
		"The game will start automatically when SBS is detected.")
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 23)
	column.add_child(instructions)
	help = Label.new()
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.text = "Keep the glasses connected while changing mode. B / Escape returns to Steam."
	column.add_child(help)
	if manual_confirmation:
		var next := Button.new()
		next.text = "I switched to SBS — Continue  [A]"
		next.pressed.connect(continue_session)
		column.add_child(next)
		next.grab_focus()
	var cancel := Button.new()
	cancel.text = "Cancel  [B]"
	cancel.pressed.connect(func(): get_tree().quit())
	column.add_child(cancel)
	if not manual_confirmation: cancel.grab_focus()
	gate = OS.get_environment("RETROCRT_STARTUP_GATE")
	if in_place and not manual_confirmation:
		help.text = "A darkens the screen before switching. B / Escape cancels."
	get_window().size_changed.connect(on_window_size_changed)

func on_window_size_changed() -> void:
	if in_place: darken()

func darken() -> void:
	darkened = true
	if is_instance_valid(content): content.hide()

func continue_session() -> void:
	if proceeding: return
	proceeding = true
	if in_place:
		darken()
		proceed_requested.emit()
	else: get_tree().quit(READY_EXIT_CODE)

func _process(delta: float) -> void:
	waiting_time += delta
	if in_place and not gate.is_empty() and FileAccess.file_exists(gate):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(gate))==OK:
			var request = parser.data
			if request is Dictionary and request.get("start",false): continue_session()
	if waiting_time > 20.0:
		help.text = ("If SBS is active but the picture is wrong, set this game's\nSteam resolution to Native (3840 × 1080), then relaunch.\n" if manual_confirmation else "Still waiting for Full-SBS. Check the USB connection and use the glasses' SBS button.\n") + "B / Escape cancels safely; reconnect and launch again to retry."
	# Native Gamescope resolution may update when the glasses reconnect in SBS.
	if manual_confirmation and DisplayServer.screen_get_size(get_window().current_screen) == Vector2i(3840, 1080):
		continue_session()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			get_tree().quit()
		elif event.button_index == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			if manual_confirmation: continue_session()
			elif in_place: darken()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
