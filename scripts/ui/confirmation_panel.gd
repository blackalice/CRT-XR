extends PanelContainer
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
var title_label: Label
var detail_label: Label
var thumbnail: TextureRect

func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size",28)
	MenuSkin.weigh(title_label,MenuSkin.BOLD)
	column.add_child(title_label)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail_label)
	thumbnail=TextureRect.new(); thumbnail.custom_minimum_size=Vector2(192,144); thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; column.add_child(thumbnail); thumbnail.hide()

func describe(title: String, detail: String, state_path := "") -> void:
	title_label.text = title
	# A confirmation's question is the menu heading; the card holds the detail.
	title_label.visible = not title.is_empty()
	detail_label.text = detail

	thumbnail.hide()
	if not state_path.is_empty():
		var details := preload("res://scripts/emulation/emulation_session.gd").state_details(state_path)
		if details.get("thumbnail") is PackedByteArray:
			var image := Image.new()
			if image.load_png_from_buffer(details.thumbnail)==OK:
				thumbnail.texture=ImageTexture.create_from_image(image); thumbnail.show()
