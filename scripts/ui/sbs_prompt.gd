extends Control

const READY_EXIT_CODE := 10
var manual_confirmation := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("090c12")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
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
	if manual_confirmation:
		var next := Button.new()
		next.text = "I switched to SBS — Continue  [A]"
		next.pressed.connect(func(): get_tree().quit(READY_EXIT_CODE))
		column.add_child(next)
		next.grab_focus()
	var cancel := Button.new()
	cancel.text = "Cancel  [B]"
	cancel.pressed.connect(func(): get_tree().quit())
	column.add_child(cancel)
	if not manual_confirmation: cancel.grab_focus()

func _process(_delta: float) -> void:
	# Native Gamescope resolution may update when the glasses reconnect in SBS.
	if manual_confirmation and DisplayServer.screen_get_size(get_window().current_screen) == Vector2i(3840, 1080):
		get_tree().quit(READY_EXIT_CODE)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			get_tree().quit()
		elif event.button_index == JOY_BUTTON_A and manual_confirmation:
			get_viewport().set_input_as_handled()
			get_tree().quit(READY_EXIT_CODE)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
