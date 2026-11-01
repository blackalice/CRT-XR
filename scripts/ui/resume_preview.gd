extends PanelContainer
## Saved-frame preview for the return-to-game page, including older saves without an image.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const Play = preload("res://scripts/ui/menu_play.gd")
const Icon = preload("res://scripts/ui/row_icon.gd")
var thumbnail: TextureRect
var placeholder: VBoxContainer
var caption: Label

func _ready() -> void:
	custom_minimum_size.x = 368
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(MenuSkin.pixel_panel("well"))
	var inset := MarginContainer.new()
	for side in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+side,12)
	add_child(inset)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	inset.add_child(column)
	var image_slot := PanelContainer.new()
	image_slot.custom_minimum_size = Vector2(344,258)
	image_slot.add_theme_stylebox_override("panel",MenuSkin.box(MenuSkin.INK,Color.TRANSPARENT,0,0))
	column.add_child(image_slot)
	thumbnail = TextureRect.new()
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_slot.add_child(thumbnail)
	var center := CenterContainer.new()
	image_slot.add_child(center)
	placeholder = VBoxContainer.new()
	placeholder.add_theme_constant_override("separation",12)
	center.add_child(placeholder)
	var icon := Icon.new("save",MenuSkin.MUTED)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	placeholder.add_child(icon)
	var label := Label.new()
	label.text = "No preview available"
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",MenuSkin.MUTED)
	placeholder.add_child(label)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size",16)
	caption.add_theme_color_override("font_color",MenuSkin.MUTED)
	column.add_child(caption)

func describe(path: String, saved: String) -> void:
	thumbnail.texture = Play.state_picture(path)
	thumbnail.visible = thumbnail.texture != null
	placeholder.visible = thumbnail.texture == null
	caption.text = saved
