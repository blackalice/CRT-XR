extends "res://scripts/ui/setting_row.gd"
func configure(definition: Dictionary) -> void:
	super.configure(definition)
	custom_minimum_size.y=62
	value_label.custom_minimum_size.x=40
	var detail := Label.new(); detail.text=item.get("detail","")
	detail.add_theme_font_size_override("font_size",18)
	detail.add_theme_color_override("font_color",MenuSkin.MUTED)
	detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.get_parent().add_child(detail)
