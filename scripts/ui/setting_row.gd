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
var range_min_label: Label
var range_max_label: Label
var selected_now := false
var adjust_buttons: Array[Button] = []
var content_margin: MarginContainer
var content: VBoxContainer
var words: VBoxContainer
var value_group: HBoxContainer
var meter: HBoxContainer
var descriptive_value := false

func configure(definition: Dictionary) -> void:
	item=definition
	name="Row_"+str(item.id).sha256_text().left(12)
	custom_minimum_size=Vector2(0,56)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	focus_mode=Control.FOCUS_ALL
	content_margin=MarginContainer.new()
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: content_margin.add_theme_constant_override("margin_"+side,16)
	for side in ["top","bottom"]: content_margin.add_theme_constant_override("margin_"+side,10)
	content_margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(content_margin)
	content=VBoxContainer.new(); content.add_theme_constant_override("separation",8)
	content.mouse_filter=Control.MOUSE_FILTER_IGNORE; content_margin.add_child(content)
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation",16)
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE; content.add_child(line)
	# The outline carries focus; do not reserve a competing arrow column.
	marker=Label.new(); marker.hide(); add_child(marker)
	words=VBoxContainer.new(); words.add_theme_constant_override("separation",3)
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	words.mouse_filter=Control.MOUSE_FILTER_IGNORE; line.add_child(words)
	title_label=Label.new(); title_label.text=item.label
	title_label.add_theme_font_size_override("font_size",24)
	title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible=3
	title_label.mouse_filter=Control.MOUSE_FILTER_IGNORE; words.add_child(title_label)
	value_group=HBoxContainer.new(); value_group.add_theme_constant_override("separation",8)
	value_group.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	value_group.mouse_filter=Control.MOUSE_FILTER_IGNORE; line.add_child(value_group)
	value_label=Label.new(); value_label.add_theme_font_size_override("font_size",22)
	value_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	descriptive_value=item.kind=="action" and str(item.get("value","")).length()>16
	if descriptive_value:
		value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		value_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		value_label.add_theme_color_override("font_color",MenuSkin.MUTED)
		words.add_child(value_label)
	else: value_group.add_child(value_label)
	if item.kind=="number": value_label.custom_minimum_size.x=106
	if item.kind=="choice":
		value_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x=180
	if item.kind in ["number","choice"]:
		for direction in [-1,1]:
			var arrow := Button.new(); arrow.text="‹" if direction<0 else "›"
			arrow.custom_minimum_size=Vector2(30,30)
			arrow.size_flags_vertical=Control.SIZE_SHRINK_CENTER
			arrow.focus_mode=Control.FOCUS_NONE
			for style in ["normal","hover","pressed","disabled"]:
				arrow.add_theme_stylebox_override(style,MenuSkin.box(Color("44403a") if style in ["hover","pressed"] else Color.TRANSPARENT,Color.TRANSPARENT,0,2))
			arrow.pressed.connect(func():
				if not disabled: adjust_requested.emit(item.id,direction))
			value_group.add_child(arrow); adjust_buttons.append(arrow)
	meter=HBoxContainer.new(); meter.add_theme_constant_override("separation",10)
	meter.mouse_filter=Control.MOUSE_FILTER_IGNORE; content.add_child(meter)
	range_min_label=Label.new(); range_max_label=Label.new()
	for label in [range_min_label,range_max_label]:
		label.add_theme_font_size_override("font_size",16)
		label.add_theme_color_override("font_color",MenuSkin.MUTED)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	meter.add_child(range_min_label)
	track=ProgressBar.new(); track.custom_minimum_size.y=4; track.max_value=1
	track.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	track.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	track.show_percentage=false; track.mouse_filter=Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("background",MenuSkin.box(Color("42464c"),Color.TRANSPARENT,0,0))
	track.add_theme_stylebox_override("fill",MenuSkin.box(MenuSkin.AMBER,Color.TRANSPARENT,0,0))
	meter.add_child(track); meter.add_child(range_max_label)
	unavailable_label=Label.new(); unavailable_label.add_theme_font_size_override("font_size",16)
	unavailable_label.add_theme_color_override("font_color",MenuSkin.MUTED)
	unavailable_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	unavailable_label.mouse_filter=Control.MOUSE_FILTER_IGNORE; content.add_child(unavailable_label)
	content_margin.minimum_size_changed.connect(sync_content_height)
	pressed.connect(func(): selected.emit(item.id))
	focus_entered.connect(func(): selected.emit(item.id))
	refresh()

func sync_content_height() -> void:
	if content_margin==null or not content_margin.visible: return
	# Read the containers' natural minimum, never their allocated height.
	# This lets wrapped titles and descriptions grow the row without a size loop.
	custom_minimum_size.y=maxf(56,content_margin.get_combined_minimum_size().y)

func refresh() -> void:
	disabled=item.get("disabled",false)
	value_label.text=formatted_value()
	title_label.text=str(item.label)+(" •" if changed_from_default() else "")
	for button in adjust_buttons:
		button.visible=true; button.disabled=disabled
		button.modulate.a=1.0 if selected_now else 0.0
		button.mouse_filter=Control.MOUSE_FILTER_STOP if selected_now else Control.MOUSE_FILTER_IGNORE
	track.visible=item.kind=="number"
	if meter!=null: meter.visible=track.visible
	if track.visible:
		track.add_theme_stylebox_override("fill",MenuSkin.box(MenuSkin.AMBER if selected_now else Color("92969c"),Color.TRANSPARENT,0,0))
		track.value=inverse_lerp(float(item.min),float(item.max),float(item.getter.call()))
		if range_min_label!=null:
			range_min_label.text=format_limit(float(item.min))
			range_max_label.text=format_limit(float(item.max))
	if unavailable_label!=null:
		unavailable_label.text=str(item.get("disabled_reason","")) if disabled else ""
		unavailable_label.visible=not unavailable_label.text.is_empty()
	tooltip_text=str(item.get("disabled_reason",item.get("help","")))
	title_label.modulate=Color("85878b") if disabled else Color.WHITE
	value_label.modulate=title_label.modulate
	if marker!=null: marker.text=""
	sync_content_height()

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
	selected_now=value
	refresh(); update_selection_style()

func update_selection_style() -> void:
	var selected_style := MenuSkin.box(Color("3b3022"),MenuSkin.AMBER,2)
	add_theme_stylebox_override("normal",selected_style if selected_now else MenuSkin.box(Color("23272d")))
	add_theme_stylebox_override("hover",selected_style if selected_now else MenuSkin.box(Color("2d323a"),Color("65666a"),1))
	add_theme_stylebox_override("focus",StyleBoxEmpty.new())

func changed_from_default() -> bool:
	if not item.has("default") or not item.has("getter"): return false
	var value = item.getter.call()
	if value is float or value is int: return not is_equal_approx(float(value),float(item.default))
	return value != item.default

func format_limit(value: float) -> String:
	match item.get("unit",""):
		"percent": return compact_number(value*100.0)+"%"
		"mm", "ms": return compact_number(value*1000.0)+" "+str(item.unit)
		"degrees": return compact_number(value)+"°"
		"x": return compact_number(value)+"×"
	return compact_number(value)+(" "+str(item.get("unit","")) if not str(item.get("unit","")).is_empty() else "")

func compact_number(value: float) -> String:
	var result := "%.3f" % value
	while result.ends_with("0"): result=result.trim_suffix("0")
	return result.trim_suffix(".")
