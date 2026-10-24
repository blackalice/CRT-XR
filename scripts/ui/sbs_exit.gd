extends Control
## Leaving CRT XR with glasses that switch to SBS by their own button: without
## this, Steam comes back doubled until the glasses are switched. A note in
## each eye asks for the button, and CRT XR closes as soon as the glasses
## leave SBS (their SBS mode drops out of the display probe's advertised
## modes, as it appeared on the way in). B / Escape / A leave at once; after
## a minute it closes anyway. Glasses the XR driver switches itself are put
## back by the launcher instead (steam-session.py AutoSBS), with no note.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
## Time to close: the glasses left SBS, the player chose to leave, or a minute passed.
signal done
const POLL := 0.5
const GIVE_UP := 60.0
## Fresh probe readings without the SBS mode before closing: one could be a
## reconnect mid-switch.
const CLEAR_READINGS := 2
var probe_path := ""
var elapsed := 0.0
var poll := 0.0
var clear := 0

## True when this exit needs the note: an SBS session from the Gaming Mode
## launcher, with the glasses still in SBS and nobody else switching them back.
static func needed(probe: String, auto_status: String, now: float) -> bool:
	if probe.is_empty(): return false
	if not auto_status.is_empty() and status_state(auto_status) == "on": return false
	var data := read(probe)
	return fresh(data, now) and bool(data.get("advertised", false))

static func status_state(path: String) -> String:
	return str(read(path).get("state", ""))

static func read(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return parsed if parsed is Dictionary else {}

static func fresh(data: Dictionary, now: float) -> bool:
	return absf(now - float(data.get("timestamp", 0))) < 3.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	# One note per eye: the window is both eyes side by side.
	var eyes := HBoxContainer.new()
	eyes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eyes.add_theme_constant_override("separation", 0)
	add_child(eyes)
	for i in range(2):
		var eye := CenterContainer.new()
		eye.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eye.add_child(note())
		eyes.add_child(eye)

func note() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202126")
	style.border_color = Color("c7934c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 36; style.content_margin_right = 36
	style.content_margin_top = 28; style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	for line in [["Back to 2D", 36, MenuSkin.BOLD, Color("f3ead8")],
			["Use your glasses' SBS button to switch back to 2D.\nCRT XR closes as soon as they do.", 24, MenuSkin.REGULAR, Color("f3ead8")],
			["B leaves now, still in SBS.", 18, MenuSkin.REGULAR, Color("c2bcaf")]]:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", line[1])
		MenuSkin.weigh(label, line[2])
		label.add_theme_color_override("font_color", line[3])
		column.add_child(label)
	return panel

func _process(delta: float) -> void:
	elapsed += delta
	poll += delta
	if elapsed >= GIVE_UP: leave()
	if poll < POLL: return
	poll = 0.0
	var data := read(probe_path)
	# A stale probe says nothing either way; wait for the button or the minute.
	if not fresh(data, Time.get_unix_time_from_system()): return
	clear = clear + 1 if not bool(data.get("advertised", false)) else 0
	if clear >= CLEAR_READINGS: leave()

func _input(event: InputEvent) -> void:
	var leaving: bool = (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B]) \
		or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ESCAPE, KEY_ENTER])
	if leaving:
		get_viewport().set_input_as_handled()
		leave()

func leave() -> void:
	if not is_processing(): return
	set_process(false)
	done.emit()
