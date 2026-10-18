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
var probe_path := ""
var probe_armed := false
var probe_ready := false
var probe_elapsed := 0.0
var probe_poll := 0.0
var probe_stable := 0
var probe_expected := Vector2i.ZERO
var probe_phase := ""
var instructions: Label
var begin_button: Button
var prompt_canvas: Control

func _ready() -> void:
	probe_path = OS.get_environment("CRT_XR_DISPLAY_PROBE")
	var expected := OS.get_environment("CRT_XR_SBS_SIZE").split("x")
	if expected.size()==2: probe_expected=Vector2i(int(expected[0]),int(expected[1]))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	# Preserve UI proportions even when Gamescope exposes a wide SBS virtual
	# window while the glasses are still mono. Independent axis scaling made
	# the logo and text short/wide on compositors that already preserve aspect.
	prompt_canvas=Control.new()
	prompt_canvas.size=Vector2(1280,720)
	add_child(prompt_canvas)
	var center := CenterContainer.new()
	content = center
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_canvas.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color=Color("202126")
	style.border_color=Color("c7934c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left=36; style.content_margin_right=36
	style.content_margin_top=32; style.content_margin_bottom=32
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(preload("res://scripts/ui/startup_brand.gd").logo())
	var heading := Label.new()
	heading.text = "SWITCH TO SBS NOW"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color",Color("f3ead8"))
	column.add_child(heading)
	instructions = Label.new()
	instructions.text = "Glasses detected. Use the glasses’ SBS button.\n" + (
		"Press A after switching to continue." if manual_confirmation else
		"The game will start automatically when SBS is detected.")
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 24)
	instructions.add_theme_color_override("font_color",Color("f3ead8"))
	column.add_child(instructions)
	help = Label.new()
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size",18)
	help.add_theme_color_override("font_color",Color("c2bcaf"))
	help.text = "Keep the glasses connected while changing mode. B / Escape returns to Steam."
	column.add_child(help)
	if manual_confirmation:
		var next := Button.new()
		begin_button=next
		next.custom_minimum_size.y=54
		next.add_theme_font_size_override("font_size",24)
		next.text = "I switched to SBS — Continue  [A]"
		next.pressed.connect(func():
			if not probe_path.is_empty(): arm_probe()
			else: continue_session())
		column.add_child(next)
		next.grab_focus()
	var cancel := Button.new()
	cancel.text = "Cancel  [B]"
	cancel.pressed.connect(func(): get_tree().quit())
	column.add_child(cancel)
	if not manual_confirmation: cancel.grab_focus()
	gate = OS.get_environment("CRT_XR_STARTUP_GATE")
	if not probe_path.is_empty():
		heading.text="Ready for your glasses"
		instructions.text="1. Press A to darken the view.\n2. Switch your glasses to SBS.\nYour room will appear automatically when ready."
		help.text="Keep the glasses connected. If the view stays black,\npress X to retry, or return to mono and press B / Escape to leave."
		if manual_confirmation: begin_button.text="Begin  [A]"
	if in_place and not manual_confirmation:
		help.text = "A darkens the screen before switching. B / Escape cancels."
	get_window().size_changed.connect(on_window_size_changed)
	resize_prompt_canvas()

func resize_prompt_canvas() -> void:
	if is_instance_valid(prompt_canvas):
		var layout := prompt_layout(get_viewport_rect().size)
		prompt_canvas.scale=Vector2.ONE*layout.scale
		prompt_canvas.position=layout.position

static func prompt_layout(available: Vector2) -> Dictionary:
	var scale_factor := maxf(0.01,minf(available.x/1280.0,available.y/720.0))
	return {"scale":scale_factor,"position":(available-Vector2(1280,720)*scale_factor)*0.5}

func on_window_size_changed() -> void:
	resize_prompt_canvas()
	if in_place and (probe_path.is_empty() or probe_armed): darken()

func darken() -> void:
	darkened = true
	if is_instance_valid(content): content.hide()

func continue_session() -> void:
	if proceeding: return
	if not probe_path.is_empty() and probe_stable<4: return
	proceeding = true
	if in_place:
		darken()
		proceed_requested.emit()
	else: get_tree().quit(READY_EXIT_CODE)

func _process(delta: float) -> void:
	waiting_time += delta
	if not probe_path.is_empty():
		process_probe(delta)
		return
	if in_place and not gate.is_empty() and FileAccess.file_exists(gate):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(gate))==OK:
			var request = parser.data
			if request is Dictionary and request.get("start",false): continue_session()
	if waiting_time > 20.0:
		help.text = ("If SBS is active but the picture is wrong, set this game's\nSteam resolution to 3840 × 1080, then relaunch.\n" if manual_confirmation else "Still waiting for Full-SBS. Check the USB connection and use the glasses' SBS button.\n") + "B / Escape cancels safely; reconnect and launch again to retry."
	# Native Gamescope resolution may update when the glasses reconnect in SBS.
	if manual_confirmation and DisplayServer.screen_get_size(get_window().current_screen) == Vector2i(3840, 1080):
		continue_session()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			get_tree().quit()
		elif event.button_index == JOY_BUTTON_X and not probe_path.is_empty() and probe_armed:
			probe_elapsed=0.0; probe_stable=0
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			if not probe_path.is_empty():
				arm_probe()
			elif manual_confirmation: continue_session()
			elif in_place and (probe_path.is_empty() or probe_armed): darken()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()

func arm_probe() -> void:
	if not probe_ready or probe_armed: return
	probe_armed=true
	probe_elapsed=0.0
	probe_stable=0
	darken()

func process_probe(delta: float) -> void:
	# Steam's launch A press must be released before it can arm this screen.
	var held := false
	for device in Input.get_connected_joypads():
		held = held or Input.is_joy_button_pressed(device,JOY_BUTTON_A)
	if waiting_time>=0.7 and not held: probe_ready=true
	probe_poll+=delta
	if probe_armed: probe_elapsed+=delta
	if probe_poll<0.5: return
	probe_poll=0.0
	var screen_size := DisplayServer.screen_get_size(get_window().current_screen)
	var window_size := get_window().size
	var data: Dictionary={}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(probe_path)) if FileAccess.file_exists(probe_path) else null
	if parsed is Dictionary: data=parsed
	var fresh := absf(Time.get_unix_time_from_system()-float(data.get("timestamp",0)))<3.0
	var matches := probe_matches(data,probe_expected,screen_size,window_size,Time.get_unix_time_from_system())
	probe_stable=probe_stable+1 if matches and probe_armed else 0
	var phase := "waiting_for_A" if not probe_armed else ("timeout" if probe_elapsed>=90 else ("matching" if matches else "waiting_for_resolution"))
	var diagnostic := {"phase":phase,"screen":[screen_size.x,screen_size.y],"window":[window_size.x,window_size.y],"expected":[probe_expected.x,probe_expected.y],"fresh":fresh,"advertised":data.get("advertised",false),"physical_mode_verified":false,"stable_samples":probe_stable}
	var file := FileAccess.open(probe_path+".app.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(diagnostic))
	if phase!=probe_phase:
		print("CRT XR display handoff: ",JSON.stringify(diagnostic)); probe_phase=phase
	if probe_elapsed>=90: return # Stay black; never reveal a malformed stereo scene.
	if probe_stable>=4: continue_session()

static func probe_matches(data: Dictionary, expected: Vector2i, screen_size: Vector2i, window_size: Vector2i, now: float) -> bool:
	var reported = data.get("expected",[])
	if not reported is Array or reported.size()!=2: return false
	if not (reported[0] is float or reported[0] is int) or not (reported[1] is float or reported[1] is int): return false
	# JSON numbers are floats; Array equality distinguishes them from our ints.
	var same_target := float(reported[0])==float(expected.x) and float(reported[1])==float(expected.y)
	return expected.x>=640 and expected.y>=480 and absf(now-float(data.get("timestamp",0)))<3.0 and same_target and bool(data.get("advertised",false)) and screen_size==expected and window_size==expected
