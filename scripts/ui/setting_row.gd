extends Button
signal selected(id: String)
signal adjust_requested(id: String, direction: int)
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
var item: Dictionary
var title_label: Label
var unavailable_label: Label
var value_label: Label
var marker: Label
var track: ProgressBar
var selected_now := false
var adjust_buttons: Array[Button] = []

func configure(definition: Dictionary) -> void:
	item = definition
	name = "Row_" + str(item.id).sha256_text().left(12)
	custom_minimum_size = Vector2(0,46)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 12; line.offset_right = -12
	line.add_theme_constant_override("separation",10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	marker = Label.new(); marker.text = " "; marker.custom_minimum_size.x = 14
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_color_override("font_color",MenuSkin.AMBER)
	line.add_child(marker)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	title_label = Label.new()
	title_label.text = item.label
	title_label.add_theme_font_size_override("font_size",24)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(title_label)
	unavailable_label=Label.new(); unavailable_label.add_theme_font_size_override("font_size",16)
	unavailable_label.add_theme_color_override("font_color",MenuSkin.MUTED)
	unavailable_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(unavailable_label)
	track = ProgressBar.new()
	track.custom_minimum_size.y = 3
	track.max_value = 1
	track.show_percentage = false
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("background",MenuSkin.box(Color("34383e"),Color.TRANSPARENT,0,0))
	track.add_theme_stylebox_override("fill",MenuSkin.box(MenuSkin.AMBER,Color.TRANSPARENT,0,0))
	words.add_child(track)
	value_label = Label.new()
	value_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.custom_minimum_size.x = 118
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size",22)
	line.add_child(value_label)
	if item.kind in ["number","choice"]:
		for direction in [-1,1]:
			var arrow := Button.new()
			arrow.text = "‹" if direction < 0 else "›"
			arrow.custom_minimum_size.x = 28
			arrow.focus_mode = Control.FOCUS_NONE
			for style_name in ["normal","hover","pressed"]:
				arrow.add_theme_stylebox_override(style_name,MenuSkin.box(Color("2d323a") if style_name=="hover" else Color("23272d"),Color.TRANSPARENT,0,4))
			arrow.pressed.connect(func():
				if not disabled: adjust_requested.emit(item.id,direction))
			line.add_child(arrow); adjust_buttons.append(arrow)
	pressed.connect(func(): selected.emit(item.id))
	focus_entered.connect(func(): selected.emit(item.id))
	refresh()

func refresh() -> void:
	disabled = item.get("disabled",false)
	value_label.text = formatted_value()
	for button in adjust_buttons:
		button.visible=selected_now; button.disabled=disabled
	track.visible = item.kind == "number"
	if track.visible:
		track.value = inverse_lerp(float(item.min),float(item.max),float(item.getter.call()))
	if unavailable_label!=null:
		unavailable_label.text=str(item.get("disabled_reason",""))
		unavailable_label.visible=disabled and not unavailable_label.text.is_empty()
		custom_minimum_size.y=64 if unavailable_label.visible else (62 if item.get("layout","")=="game" else 46)
	tooltip_text=str(item.get("disabled_reason",item.get("help","")))
	title_label.modulate = Color("85878b") if disabled else MenuSkin.TEXT
	value_label.modulate = title_label.modulate

func formatted_value() -> String:
	if item.kind == "action": return item.get("value","›")
	var value = item.getter.call()
	if item.kind == "toggle": return "On" if value else "Off"
	if item.kind == "choice": return str(item.choices[int(value)])
	match item.get("unit",""):
		"percent": return "%d%%" % roundi(float(value)*100)
		"m": return "%.2f m" % value
		"m/s": return "%.1f m/s" % value
		"mm": return "%d mm" % roundi(float(value)*1000)
		"ms": return "%d ms" % roundi(float(value)*1000)
		"degrees": return "%.1f°" % value
		"x": return "%.2f×" % value
	return ("%.2f" if float(item.step)<1 else "%d") % value

func set_selected(value: bool) -> void:
	selected_now = value
	refresh(); update_selection_style()

func update_selection_style() -> void:
	marker.text = "▸" if selected_now else " "
	var selected_style := MenuSkin.box(Color("3b3022"),MenuSkin.AMBER,2)
	add_theme_stylebox_override("normal",selected_style if selected_now else MenuSkin.box(Color("23272d")))
	add_theme_stylebox_override("hover",selected_style if selected_now else MenuSkin.box(Color("2d323a"),Color("65666a"),1))
	add_theme_stylebox_override("focus",selected_style if selected_now else MenuSkin.box(Color("23272d")))
