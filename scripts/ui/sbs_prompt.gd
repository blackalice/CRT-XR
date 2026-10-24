extends Control
## "Get your glasses ready": shown while the glasses are still in 2D. In Gaming
## Mode (the display probe, CRT_XR_DISPLAY_PROBE) it is fully automatic: the
## glasses' SBS button, or the XR driver (CRT_XR_AUTO_SBS), switches them, the
## screen goes dark as SBS arrives and the room starts when the display probe,
## screen and window all agree. Desktop launches without the probe keep A to
## darken before switching, and a supervisor's gate file to start.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const HelpArticle = preload("res://scripts/ui/help_article.gd")
signal proceed_requested

const READY_EXIT_CODE := 10
## A logical canvas 720 high and as wide as the window (16:9 to 32:9). Glasses
## still in 2D show a 3840x1080 window letterboxed in a 1920x540 band, so a wide
## layout fills that band instead of a small 16:9 box in the middle of it.
const CANVAS_HEIGHT := 720.0
## Waiting this long, a tip appears: on the screen while it is lit, or in each
## eye once it is dark in SBS.
const TIP_AFTER := 20.0
var manual_confirmation := false
var waiting_time := 0.0
var in_place := false
var darkened := false
var proceeding := false
var content: Control
var gate := ""
var probe_path := ""
## Armed from the start: nothing to press in Gaming Mode.
var probe_armed := false
var probe_ready := false
var probe_elapsed := 0.0
var probe_poll := 0.0
var probe_stable := 0
var probe_expected := Vector2i.ZERO
var probe_phase := ""
## Whether the SBS mode was missing at some reading: its appearance afterwards
## means the glasses just switched. (Advertised from the start, it may be
## glasses already in SBS, or listed while in 2D; neither darkens by itself.)
var seen_without_sbs := false
var dark_since := 0.0
## The launcher's status file while the XR driver switches the glasses to SBS
## itself (steam-session.py AutoSBS); empty for glasses switched by button.
var auto_path := ""
var auto_state := ""
var heading: Label
var instructions: Label  # the step that switches: button or driver
var status: Label
var tip: Control
var tip_label: Label
var stereo_note: Control
var begin_button: Button
var prompt_canvas: Control
var wide := false

func _ready() -> void:
	probe_path = OS.get_environment("CRT_XR_DISPLAY_PROBE")
	auto_path = OS.get_environment("CRT_XR_AUTO_SBS")
	probe_armed = not probe_path.is_empty()
	var expected := OS.get_environment("CRT_XR_SBS_SIZE").split("x")
	if expected.size()==2: probe_expected=Vector2i(int(expected[0]),int(expected[1]))
	gate = OS.get_environment("CRT_XR_STARTUP_GATE")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	prompt_canvas = Control.new()
	add_child(prompt_canvas)
	var center := CenterContainer.new()
	content = center
	prompt_canvas.add_child(center)
	stereo_note = build_stereo_note()
	add_child(stereo_note)
	get_window().size_changed.connect(on_window_size_changed)
	resize_prompt_canvas()

## The layout for this window: wide (side by side) from 2:1, stacked below it.
func build_panel() -> void:
	for child in content.get_children(): child.free()
	var panel := PanelContainer.new()
	var style := MenuSkin.box(Color("1d2025"), Color("c7934c"), 2, 0)
	style.set_corner_radius_all(18)
	style.content_margin_left = 64; style.content_margin_right = 64
	style.content_margin_top = 44; style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", style)
	content.add_child(panel)
	var layout: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
	layout.add_theme_constant_override("separation", 64 if wide else 24)
	panel.add_child(layout)
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", 14)
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(title)
	var mark := preload("res://scripts/ui/startup_brand.gd").logo()
	mark.custom_minimum_size = Vector2(380, 210)
	title.add_child(mark)
	heading = HelpArticle.label("", 62, MenuSkin.BOLD, MenuSkin.TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_child(heading)
	status = HelpArticle.label("", 32, MenuSkin.SEMIBOLD, MenuSkin.AMBER)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_child(status)
	if wide:
		var rule := ColorRect.new()
		rule.color = HelpArticle.RULE
		rule.custom_minimum_size.x = 2
		layout.add_child(rule)
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 26)
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	steps.custom_minimum_size.x = 900
	layout.add_child(steps)
	var lines := step_lines()
	for i in range(lines.size()):
		var row := HelpArticle.marked(HelpArticle.badge(str(i + 1), 48), lines[i], 42)
		var badge: Control = row.get_child(0)
		badge.custom_minimum_size = Vector2(56, 56)
		(badge.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(28)
		steps.add_child(row)
		if i == 1: instructions = row.get_child(1)
	tip = PanelContainer.new()
	var tip_style := MenuSkin.box(Color("2a2620"), Color.TRANSPARENT, 0, 16)
	tip_style.border_color = MenuSkin.AMBER
	tip_style.border_width_left = 4
	tip.add_theme_stylebox_override("panel", tip_style)
	tip_label = HelpArticle.label("", 30, MenuSkin.REGULAR, MenuSkin.TEXT)
	tip.add_child(tip_label)
	tip.visible = false
	steps.add_child(tip)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	for part in footer_parts():
		if part[0] != "": footer.add_child(HelpArticle.chip(part[0], 28, false))
		var words := HelpArticle.label(part[1], 28, MenuSkin.REGULAR, MenuSkin.MUTED)
		words.autowrap_mode = TextServer.AUTOWRAP_OFF
		words.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		footer.add_child(words)
	steps.add_child(footer)
	if manual_confirmation and probe_path.is_empty() and not in_place:
		begin_button = Button.new()
		begin_button.custom_minimum_size.y = 54
		begin_button.add_theme_font_size_override("font_size", 26)
		begin_button.text = "I switched to SBS — Continue  [A]"
		begin_button.pressed.connect(continue_session)
		steps.add_child(begin_button)
		begin_button.grab_focus()
	refresh_text()

func step_lines() -> Array:
	if probe_path.is_empty():
		return ["Press A to darken the view.", "Switch your glasses to SBS with their button.", "Your room appears when they're ready."] if in_place \
			else ["Switch your glasses to SBS with their button.", "Press A to continue.", "Your room appears in 3D."]
	return ["Put your glasses on.", "", "Your room appears by itself."]

func footer_parts() -> Array:
	return [["B", "Return to Steam"], ["", "·  Keep the glasses connected"]] if not probe_path.is_empty() \
		else [["B", "Cancel"], ["", "·  Keep the glasses connected"]]

## The words that depend on who switches the glasses, and how long it's taken.
func refresh_text() -> void:
	if not is_instance_valid(heading): return
	heading.text = "Get your glasses ready"
	var automatic := not auto_path.is_empty()
	if not probe_path.is_empty() and is_instance_valid(instructions):
		instructions.text = "Your glasses switch to SBS by themselves." if automatic else "Press your glasses' SBS button."
	status.text = ("Switching your glasses…" if automatic else "Waiting for SBS…") if not probe_path.is_empty() else ""
	status.visible = not status.text.is_empty()
	if auto_state == "failed":
		tip_label.text = "Your glasses didn't switch by themselves. Press their SBS button instead."
	else:
		tip_label.text = "Still waiting? Check the glasses' USB connection, then press their SBS button again."
	tip.visible = auto_state == "failed" or waiting_time >= TIP_AFTER

## Shown once in each eye if the view stays dark in SBS: the usual cause is
## Steam starting the game at the glasses' 2D resolution.
func build_stereo_note() -> Control:
	var eyes := HBoxContainer.new()
	eyes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eyes.add_theme_constant_override("separation", 0)
	for i in range(2):
		var eye := CenterContainer.new()
		eye.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", MenuSkin.box(Color("1d2025"), Color("c7934c"), 2, 28))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		column.add_child(HelpArticle.label("Almost there", 36, MenuSkin.BOLD, MenuSkin.TEXT))
		column.add_child(HelpArticle.label("If this stays dark, set CRT XR's Steam resolution to %d × %d\n(Properties → General → Game resolution), then launch again." % [probe_expected.x, probe_expected.y], 24, MenuSkin.REGULAR, MenuSkin.TEXT))
		column.add_child(HelpArticle.label("B returns to Steam.", 20, MenuSkin.REGULAR, MenuSkin.MUTED))
		for label in column.get_children(): label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(column)
		eye.add_child(panel)
		eyes.add_child(eye)
	eyes.visible = false
	return eyes

func resize_prompt_canvas() -> void:
	if not is_instance_valid(prompt_canvas): return
	var available := get_viewport_rect().size
	var layout := prompt_layout(available)
	var now_wide: bool = layout.size.x >= CANVAS_HEIGHT * 2.0
	if now_wide != wide or content.get_child_count() == 0:
		wide = now_wide
		build_panel()
	prompt_canvas.size = layout.size
	# Anchored, so it follows the canvas even after wrapped text first laid out tall.
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_canvas.scale = Vector2.ONE * layout.scale
	prompt_canvas.position = layout.position
	fit_panel.call_deferred(layout)

## A panel larger than the canvas (the stacked layout) shrinks to fit it, once
## its wrapped text has laid out (before that, its height is not yet known).
func fit_panel(layout: Dictionary) -> void:
	await get_tree().process_frame
	if not is_instance_valid(prompt_canvas) or content.get_child_count() == 0: return
	var need: Vector2 = (content.get_child(0) as Control).size
	var fit := minf(1.0, minf(layout.size.x * 0.94 / maxf(need.x, 1.0), layout.size.y * 0.94 / maxf(need.y, 1.0)))
	prompt_canvas.size = layout.size / fit
	prompt_canvas.scale = Vector2.ONE * layout.scale * fit

## The canvas for a window: 720 high, as wide as the window allows (16:9 to
## 32:9), scaled uniformly and centred.
static func prompt_layout(available: Vector2) -> Dictionary:
	var aspect := clampf(available.x / maxf(available.y, 1.0), 16.0 / 9.0, 32.0 / 9.0)
	var canvas := Vector2(CANVAS_HEIGHT * aspect, CANVAS_HEIGHT)
	var scale_factor := maxf(0.01, minf(available.x / canvas.x, available.y / canvas.y))
	return {"scale": scale_factor, "size": canvas, "position": (available - canvas * scale_factor) * 0.5}

func on_window_size_changed() -> void:
	# On the desktop, KDE resizing the window means the switch has begun. In
	# Gaming Mode the window is already the SBS size in 2D (Steam's per-game
	# resolution), so only the display probe says when SBS arrives.
	if in_place and probe_path.is_empty(): darken()
	resize_prompt_canvas()

func darken() -> void:
	if not darkened: dark_since = waiting_time
	darkened = true
	if is_instance_valid(content): content.hide()

func continue_session() -> void:
	if proceeding: return
	if not probe_path.is_empty() and probe_stable<4: return
	proceeding = true
	stereo_note.hide()
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
	if is_instance_valid(tip) and tip.visible != (waiting_time >= TIP_AFTER): refresh_text()
	# Native Gamescope resolution may update when the glasses reconnect in SBS.
	if manual_confirmation and DisplayServer.screen_get_size(get_window().current_screen) == Vector2i(3840, 1080):
		continue_session()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			get_tree().quit()
		elif event.button_index == JOY_BUTTON_A and probe_path.is_empty():
			get_viewport().set_input_as_handled()
			if manual_confirmation and not in_place: continue_session()
			elif in_place: darken()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()

## While the driver switches the glasses the screen says so; if it cannot, it
## asks for the button instead.
func follow_auto_switch() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(auto_path)) if FileAccess.file_exists(auto_path) else null
	var state: String = str(parsed.get("state", "")) if parsed is Dictionary else ""
	if state == auto_state: return
	auto_state = state
	if state == "failed": auto_path = ""
	refresh_text()

func process_probe(delta: float) -> void:
	# Steam's launch A press is irrelevant now; kept for diagnostics only.
	var held := false
	for device in Input.get_connected_joypads():
		held = held or Input.is_joy_button_pressed(device,JOY_BUTTON_A)
	if waiting_time>=0.7 and not held: probe_ready=true
	probe_poll+=delta
	probe_elapsed+=delta
	if probe_poll<0.5: return
	probe_poll=0.0
	if not auto_path.is_empty(): follow_auto_switch()
	var screen_size := DisplayServer.screen_get_size(get_window().current_screen)
	var window_size := get_window().size
	var data: Dictionary={}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(probe_path)) if FileAccess.file_exists(probe_path) else null
	if parsed is Dictionary: data=parsed
	var fresh := absf(Time.get_unix_time_from_system()-float(data.get("timestamp",0)))<3.0
	var advertised: bool = fresh and bool(data.get("advertised",false))
	if fresh and not advertised: seen_without_sbs = true
	# The SBS mode appearing after it was missing: the glasses just switched.
	if advertised and seen_without_sbs: darken()
	var matches := probe_matches(data,probe_expected,screen_size,window_size,Time.get_unix_time_from_system())
	probe_stable=probe_stable+1 if matches else 0
	if matches: darken()
	if not darkened and is_instance_valid(tip) and tip.visible != (waiting_time >= TIP_AFTER): refresh_text()
	stereo_note.visible = darkened and not proceeding and waiting_time - dark_since >= TIP_AFTER
	var phase := "waiting_for_sbs" if not darkened else ("matching" if matches else "waiting_for_resolution")
	var diagnostic := {"phase":phase,"screen":[screen_size.x,screen_size.y],"window":[window_size.x,window_size.y],"expected":[probe_expected.x,probe_expected.y],"fresh":fresh,"advertised":data.get("advertised",false),"physical_mode_verified":false,"stable_samples":probe_stable,"automatic_sbs":auto_state}
	var file := FileAccess.open(probe_path+".app.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(diagnostic))
	if phase!=probe_phase:
		print("CRT XR display handoff: ",JSON.stringify(diagnostic)); probe_phase=phase
	if probe_stable>=4: continue_session()

static func probe_matches(data: Dictionary, expected: Vector2i, screen_size: Vector2i, window_size: Vector2i, now: float) -> bool:
	var reported = data.get("expected",[])
	if not reported is Array or reported.size()!=2: return false
	if not (reported[0] is float or reported[0] is int) or not (reported[1] is float or reported[1] is int): return false
	# JSON numbers are floats; Array equality distinguishes them from our ints.
	var same_target := float(reported[0])==float(expected.x) and float(reported[1])==float(expected.y)
	return expected.x>=640 and expected.y>=480 and absf(now-float(data.get("timestamp",0)))<3.0 and same_target and bool(data.get("advertised",false)) and screen_size==expected and window_size==expected
