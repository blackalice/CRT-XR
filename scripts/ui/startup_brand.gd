extends Control
## Lightweight startup UI only; no extra 3D viewport or persistent overlay.
const LOGO=preload("res://artwork/Logo.png")

static func logo() -> TextureRect:
	var atlas:=AtlasTexture.new()
	atlas.atlas=LOGO
	atlas.region=Rect2(LOGO.get_image().get_used_rect())
	var mark:=TextureRect.new()
	mark.texture=atlas
	mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size=Vector2(240,140)
	mark.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return mark

var stereo:=false
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var black:=ColorRect.new();black.color=Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(black)
	var eyes:=HBoxContainer.new();eyes.add_theme_constant_override("separation",0)
	eyes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(eyes)
	for i in range(2 if stereo else 1):
		var center:=CenterContainer.new();center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;eyes.add_child(center)
		var column:=VBoxContainer.new();column.add_theme_constant_override("separation",20);center.add_child(column)
		var mark:=logo();mark.custom_minimum_size=Vector2(360,240);column.add_child(mark)
		var text:=Label.new();text.text="Loading your room…";text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size",24);text.add_theme_color_override("font_color",Color("f3ead8"));column.add_child(text)
