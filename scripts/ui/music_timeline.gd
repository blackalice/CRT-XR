extends "res://scripts/ui/setting_row.gd"
## The timeline on the Now playing deck: the loading card's segmented bar, lit
## to the position, beside the time. Left and right seek; a click or drag jumps.
var slider: HSlider
var bar: Control
var caption: Label
var dragging := false
## The slider only takes clicks and drags; the segment bar draws it.
static var BLANK: Texture2D

func configure(definition: Dictionary) -> void:
	super.configure(definition)
	# The row's own words step aside; its pixel panel stays.
	for child in get_children(): child.visible=child==panel
	custom_minimum_size=Vector2(0,36)
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left=12; layout.offset_right=-12; layout.offset_top=8; layout.offset_bottom=-8
	layout.add_theme_constant_override("separation",12)
	layout.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(layout)
	slider=HSlider.new(); slider.focus_mode=Control.FOCUS_NONE; slider.step=.1
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y=20; slider.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	if BLANK==null: BLANK=ImageTexture.create_from_image(Image.create_empty(1,1,false,Image.FORMAT_RGBA8))
	for style in ["slider","grabber_area","grabber_area_highlight"]: slider.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	for icon in ["grabber","grabber_highlight","grabber_disabled","tick"]: slider.add_theme_icon_override(icon,BLANK)
	bar=SegmentBar.new(); bar.segments=32; slider.add_child(bar)
	layout.add_child(slider)
	caption=Label.new(); caption.add_theme_font_size_override("font_size",18)
	caption.add_theme_color_override("font_color",VALUE); MenuSkin.shadow(caption)
	caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layout.add_child(caption)
	slider.drag_started.connect(func(): dragging=true; selected.emit(item.id))
	slider.drag_ended.connect(func(_changed): dragging=false)
	slider.value_changed.connect(func(value): item.setter.call(value))
	refresh()

func refresh() -> void:
	super.refresh()
	if slider==null: return
	slider.max_value=maxf(1,float(item.duration.call()))
	if not dragging: slider.set_value_no_signal(float(item.getter.call()))
	caption.text=str(item.progress.call())
	bar.bright=selected_now
	bar.queue_redraw()

func formatted_value() -> String:
	return ""
