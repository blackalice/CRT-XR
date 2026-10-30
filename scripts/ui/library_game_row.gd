extends "res://scripts/ui/setting_row.gd"
var detail_label: Label
func configure(definition: Dictionary) -> void:
	super.configure(definition)
	# Game titles use the whole text column; the chevron keeps its natural width.
	value_label.custom_minimum_size.x=18
	title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.max_lines_visible=2
	detail_label=Label.new(); detail_label.text=item.get("detail","")
	detail_label.add_theme_font_size_override("font_size",18)
	detail_label.add_theme_color_override("font_color",MenuSkin.MUTED)
	detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	MenuSkin.shadow(detail_label)
	detail_label.visible=not detail_label.text.is_empty()
	words.add_child(detail_label)
	title_label.resized.connect(sync_content_height)
	sync_content_height()

func sync_content_height() -> void:
	# A trimmed, wrapping Label reports almost no minimum height, which hid every
	# title. Reserve one or two measured lines; Y still shows the full title.
	if title_label!=null and title_label.size.x>1:
		# Lines are spaced apart too; without the gap, two lines did not fit and
		# the title was trimmed to one.
		var lines := clampi(title_label.get_line_count(),1,2)
		var height := title_label.get_line_height()*lines+title_label.get_theme_constant("line_spacing")*(lines-1)
		if not is_equal_approx(title_label.custom_minimum_size.y,height): title_label.custom_minimum_size.y=height
	super.sync_content_height()

func refresh() -> void:
	super.refresh()
	tooltip_text=str(item.label)
