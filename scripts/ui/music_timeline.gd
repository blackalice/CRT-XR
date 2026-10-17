extends "res://scripts/ui/setting_row.gd"
var slider: HSlider
var caption: Label
var dragging := false
func configure(definition: Dictionary) -> void:
	super.configure(definition)
	for child in get_children(): child.hide()
	custom_minimum_size=Vector2(0,64)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left=12; layout.offset_right=-12; layout.offset_top=5; layout.offset_bottom=-5
	layout.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(layout)
	caption=Label.new(); caption.add_theme_font_size_override("font_size",18); layout.add_child(caption)
	slider=HSlider.new(); slider.focus_mode=Control.FOCUS_NONE; slider.step=.1
	layout.add_child(slider)
	slider.drag_started.connect(func(): dragging=true; selected.emit(item.id))
	slider.drag_ended.connect(func(_changed): dragging=false)
	slider.value_changed.connect(func(value): item.setter.call(value))
	refresh()
func refresh() -> void:
	super.refresh()
	if slider==null: return
	slider.max_value=maxf(1,float(item.duration.call()))
	if not dragging: slider.set_value_no_signal(float(item.getter.call()))
	caption.text="SEEK  ·  "+str(item.progress.call())+"   ·   ← / → 10 seconds"
func formatted_value() -> String:
	return ""
