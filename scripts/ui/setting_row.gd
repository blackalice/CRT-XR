extends Button
signal selected(id: String)
signal adjust_requested(id: String, direction: int)
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const InputGlyph = preload("res://scripts/ui/input_glyph.gd")
const GlyphText = preload("res://scripts/ui/glyph_text.gd")
const RowIcon = preload("res://scripts/ui/row_icon.gd")
const SegmentBar = preload("res://scripts/ui/segment_bar.gd")
## Values read in the yellow the console menus used for numbers.
const VALUE := Color("f8d040")
## Optional item keys: "row_icon" (see row_icon.gd) leads the row; "emphasis" is
## "primary" for a screen's main action or "danger" for one that forgets
## something; "compact" draws a smaller row for secondary places.
const DANGER := Color("f87860")
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
## Video rows lead with a small picture; it arrives later, so the video icon
## holds its place until set_thumbnail() is called.
var thumbnail: TextureRect
## The row's pixel panel, drawn behind everything; the marquee when selected.
var panel: ColorRect
var segments: Control
## A quick tile being adjusted: its arrows show and its marquee turns amber.
var editing := false

func configure(definition: Dictionary) -> void:
	item=definition
	name="Row_"+str(item.id).sha256_text().left(12)
	custom_minimum_size=Vector2(0,56)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	focus_mode=Control.FOCUS_ALL
	content_margin=MarginContainer.new()
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: content_margin.add_theme_constant_override("margin_"+side,16)
	for side in ["top","bottom"]: content_margin.add_theme_constant_override("margin_"+side,6 if item.get("compact",false) else 10)
	content_margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(content_margin)
	content=VBoxContainer.new(); content.add_theme_constant_override("separation",8)
	content.mouse_filter=Control.MOUSE_FILTER_IGNORE; content_margin.add_child(content)
	if item.get("hero",false): content.alignment=BoxContainer.ALIGNMENT_CENTER
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation",16)
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE; content.add_child(line)
	# The outline carries focus; do not reserve a competing arrow column.
	marker=Label.new(); marker.hide(); add_child(marker)
	var emphasis := str(item.get("emphasis",""))
	var is_exit := str(item.get("id", "")) in ["exit", "home.exit"]
	var tint := MenuSkin.TEXT if is_exit else (MenuSkin.AMBER if emphasis=="primary" else (DANGER if emphasis=="danger" else MenuSkin.MUTED))
	if item.has("thumbnail_path"):
		# Video frames fill a 4:3 slot; box art and saves fit theirs whole.
		var slot_size: Vector2 = item.get("thumbnail_size",Vector2(64,48))
		var slot := Control.new(); slot.custom_minimum_size=slot_size; slot.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		slot.mouse_filter=Control.MOUSE_FILTER_IGNORE; line.add_child(slot)
		var placeholder := RowIcon.new(str(item.get("thumbnail_icon","video")),tint); placeholder.position=(slot_size-Vector2(30,30))*0.5; slot.add_child(placeholder)
		thumbnail=TextureRect.new(); thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED if item.has("thumbnail_size") else TextureRect.STRETCH_SCALE
		thumbnail.size=slot_size; thumbnail.mouse_filter=Control.MOUSE_FILTER_IGNORE; slot.add_child(thumbnail)
		set_thumbnail(item.get("thumbnail"))
	elif item.has("row_icon"): line.add_child(RowIcon.new(str(item.row_icon),tint))
	words=VBoxContainer.new(); words.add_theme_constant_override("separation",3)
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	words.mouse_filter=Control.MOUSE_FILTER_IGNORE; line.add_child(words)
	title_label=Label.new(); title_label.text=item.label
	title_label.add_theme_font_size_override("font_size",24); MenuSkin.weigh(title_label,MenuSkin.SEMIBOLD)
	title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible=3
	title_label.mouse_filter=Control.MOUSE_FILTER_IGNORE; words.add_child(title_label)
	MenuSkin.shadow(title_label)
	if emphasis in ["primary","danger"]: title_label.add_theme_color_override("font_color",tint)
	value_group=HBoxContainer.new(); value_group.add_theme_constant_override("separation",8)
	value_group.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	value_group.mouse_filter=Control.MOUSE_FILTER_IGNORE; line.add_child(value_group)
	value_label=Label.new(); value_label.add_theme_font_size_override("font_size",22)
	value_label.add_theme_color_override("font_color",VALUE)
	MenuSkin.shadow(value_label)
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
	# A stacked tile puts its value under its name: ‹ value › across the tile.
	if item.get("stacked",false):
		line.remove_child(value_group); content.add_child(value_group)
		value_group.alignment=BoxContainer.ALIGNMENT_CENTER
		value_group.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation",2)
	for input in item.get("value_inputs", []): value_group.add_child(InputGlyph.new(input))
	# A small mark in place of a value, such as the heart on a favourite game.
	if item.has("value_icon"): value_group.add_child(RowIcon.new(str(item.value_icon), VALUE))
	if item.kind=="number":
		value_label.custom_minimum_size.x=106
		value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if item.kind=="choice":
		value_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x=180
	# Under a stacked tile's name, the value keeps to one line across the tile.
	if item.get("stacked",false):
		value_label.custom_minimum_size.x=0
		value_label.autowrap_mode=TextServer.AUTOWRAP_OFF
		value_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		value_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if item.kind in ["number","choice"]:
		# ‹ value › reads as a selector and fills the row's edge like toggle values.
		for direction in [-1,1]:
			var arrow := Button.new(); arrow.text="‹" if direction<0 else "›"
			arrow.custom_minimum_size=Vector2(30,30)
			# The dot font's taller lines would push a 22 px arrow past the row's bounds.
			arrow.add_theme_font_size_override("font_size",18)
			arrow.size_flags_vertical=Control.SIZE_SHRINK_CENTER
			arrow.focus_mode=Control.FOCUS_NONE
			for style in ["normal","hover","pressed","disabled"]:
				arrow.add_theme_stylebox_override(style,MenuSkin.box(Color("44403a") if style in ["hover","pressed"] else Color.TRANSPARENT,Color.TRANSPARENT,0,2))
			arrow.pressed.connect(func():
				if not disabled: adjust_requested.emit(item.id,direction))
			value_group.add_child(arrow); adjust_buttons.append(arrow)
			if direction<0: value_group.move_child(arrow,0)
	meter=HBoxContainer.new(); meter.add_theme_constant_override("separation",10)
	meter.mouse_filter=Control.MOUSE_FILTER_IGNORE; content.add_child(meter)
	range_min_label=Label.new(); range_max_label=Label.new()
	for label in [range_min_label,range_max_label]:
		label.add_theme_font_size_override("font_size",16)
		label.add_theme_color_override("font_color",MenuSkin.MUTED)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	meter.add_child(range_min_label)
	track=ProgressBar.new(); track.custom_minimum_size.y=16; track.max_value=1
	track.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	track.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	track.show_percentage=false; track.mouse_filter=Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("background",MenuSkin.box(Color("42464c"),Color.TRANSPARENT,0,0))
	track.add_theme_stylebox_override("fill",MenuSkin.box(MenuSkin.AMBER,Color.TRANSPARENT,0,0))
	# The bar is drawn as segments; the ProgressBar keeps the value and the fill style.
	track.self_modulate.a=0.0
	segments=SegmentBar.new(); track.add_child(segments)
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
	# A hero row (Resume) stands taller than the rows around it.
	custom_minimum_size.y=maxf(44 if item.get("compact",false) else (72 if item.get("hero",false) else 56),content_margin.get_combined_minimum_size().y)

# Shared: refresh() runs ten times a second per row while the menu is open.
static var FILL_SELECTED := MenuSkin.box(MenuSkin.AMBER,Color.TRANSPARENT,0,0)
static var FILL_IDLE := MenuSkin.box(Color("92969c"),Color.TRANSPARENT,0,0)

func refresh() -> void:
	disabled=item.get("disabled",false)
	value_label.text=formatted_value()
	title_label.text=str(item.label)+(" •" if changed_from_default() else "")
	for button in adjust_buttons:
		button.visible=true; button.disabled=disabled
		# A quick tile shows its arrows only while it is being adjusted.
		var lit := (editing and selected_now) if item.get("quick",false) else selected_now
		button.modulate.a=1.0 if lit else (0.0 if item.get("quick",false) else 0.35)
		button.mouse_filter=Control.MOUSE_FILTER_STOP if selected_now else Control.MOUSE_FILTER_IGNORE
	# A compact control on the pause menu shows its value without the bar.
	track.visible=item.kind=="number" and item.get("meter",true)
	if meter!=null: meter.visible=track.visible
	if track.visible:
		track.add_theme_stylebox_override("fill",FILL_SELECTED if selected_now else FILL_IDLE)
		segments.bright=selected_now
		track.value=inverse_lerp(float(item.min),float(item.max),float(item.getter.call()))
		if range_min_label!=null:
			range_min_label.text=format_limit(float(item.min))
			range_max_label.text=format_limit(float(item.max))
	if unavailable_label!=null:
		unavailable_label.text=str(item.get("disabled_reason","")) if disabled else ""
		# Tiles stay one line; greyed out says enough beside its neighbour.
		unavailable_label.visible=not unavailable_label.text.is_empty() and item.get("layout","")!="tile"
	tooltip_text=GlyphText.plain(str(item.get("disabled_reason",item.get("help",""))))
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
		# Share of the allowed range, so the strongest setting reads 100%.
		"strength": return "%d%%" % roundi(float(value)/float(item.max)*100)
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

func _ready() -> void:
	update_selection_style()

func update_selection_style() -> void:
	if panel==null:
		panel=MenuSkin.pixel_panel("row"); add_child(panel); move_child(panel,0)
		for style in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(style,StyleBoxEmpty.new())
	var kind := ("editing" if editing else "selected") if selected_now else "row"
	if item.get("skin", "") == "music": kind = "music_selected" if selected_now else "music_row"
	if str(item.get("id", "")) in ["exit", "home.exit"]: kind = "exit_selected" if selected_now else "exit_row"
	panel.material=MenuSkin.panel_material(kind)

func changed_from_default() -> bool:
	if not item.has("default") or not item.has("getter"): return false
	var value = item.getter.call()
	if value is float or value is int: return not is_equal_approx(float(value),float(item.default))
	return value != item.default

func format_limit(value: float) -> String:
	match item.get("unit",""):
		"percent": return compact_number(value*100.0)+"%"
		"strength": return compact_number(value/float(item.max)*100.0)+"%"
		"mm", "ms": return compact_number(value*1000.0)+" "+str(item.unit)
		"degrees": return compact_number(value)+"°"
		"x": return compact_number(value)+"×"
	return compact_number(value)+(" "+str(item.get("unit","")) if not str(item.get("unit","")).is_empty() else "")

func compact_number(value: float) -> String:
	var result := "%.3f" % value
	while result.ends_with("0"): result=result.trim_suffix("0")
	return result.trim_suffix(".")

func set_thumbnail(texture: Texture2D) -> void:
	if thumbnail == null: return
	thumbnail.texture = texture
	thumbnail.visible = texture != null
