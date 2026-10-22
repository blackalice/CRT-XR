extends "res://scripts/ui/setting_row.gd"
var detail_label: Label
func configure(definition: Dictionary) -> void:
	super.configure(definition)
	# Game titles use the whole text column; the chevron keeps its natural width.
	value_label.custom_minimum_size.x=18
	detail_label=Label.new(); detail_label.text=item.get("detail","")
	detail_label.add_theme_font_size_override("font_size",18)
	detail_label.add_theme_color_override("font_color",MenuSkin.MUTED)
	detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	words.add_child(detail_label)
	sync_content_height()
