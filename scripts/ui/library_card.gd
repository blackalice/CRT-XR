extends "res://scripts/ui/setting_row.gd"
const Glyph = preload("res://scripts/ui/console_glyph.gd")
func configure(definition: Dictionary) -> void:
	item=definition
	custom_minimum_size=Vector2(0,84)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	focus_mode=Control.FOCUS_ALL
	var line := HBoxContainer.new(); line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left=12; line.offset_right=-14; line.offset_top=3; line.offset_bottom=-3
	line.add_theme_constant_override("separation",10); line.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(line)
	marker=Label.new(); marker.custom_minimum_size.x=12; marker.add_theme_color_override("font_color",MenuSkin.AMBER); line.add_child(marker)
	var glyph := Glyph.new(); glyph.kind=item.get("glyph","locations"); glyph.accent=item.get("accent",MenuSkin.AMBER)
	glyph.custom_minimum_size=Vector2(64,64); glyph.size_flags_vertical=Control.SIZE_SHRINK_CENTER; glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE; line.add_child(glyph)
	var words := VBoxContainer.new(); words.size_flags_horizontal=Control.SIZE_EXPAND_FILL; words.alignment=BoxContainer.ALIGNMENT_CENTER; words.add_theme_constant_override("separation",2); line.add_child(words)
	title_label=Label.new(); title_label.text=item.label; title_label.add_theme_font_size_override("font_size",24); MenuSkin.weigh(title_label,MenuSkin.SEMIBOLD); title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; words.add_child(title_label)
	value_label=Label.new();value_label.add_theme_font_size_override("font_size",20); words.add_child(value_label)
	value_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	track=ProgressBar.new();track.hide();add_child(track)
	MenuSkin.shadow(title_label); MenuSkin.shadow(value_label)
	pressed.connect(func(): selected.emit(item.id))
	focus_entered.connect(func(): selected.emit(item.id))
	refresh()


func refresh() -> void:
	super.refresh()
	# Cards without a count read their caption instead of a bare chevron.
	if not item.has("value") or str(item.value)=="›":
		var caption := str(item.get("caption","")).to_lower()
		value_label.text=caption.left(1).to_upper()+caption.substr(1)
