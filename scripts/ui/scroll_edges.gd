extends Control
## Quiet edge fades appear only when more content exists in that direction.
var scroll: ScrollContainer
var panel: PanelContainer

func _notification(what: int) -> void:
	if what==NOTIFICATION_THEME_CHANGED: queue_redraw()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var bar := scroll.get_v_scroll_bar()
	bar.value_changed.connect(func(_value): queue_redraw())
	bar.changed.connect(queue_redraw)
	scroll.resized.connect(queue_redraw)

func _draw() -> void:
	var bar := scroll.get_v_scroll_bar()
	var width := maxf(0,size.x-(bar.size.x if bar.visible else 0))
	var above := bar.value>bar.min_value
	var below := bar.value+bar.page<bar.max_value-1
	# Fade to the panel's own colour, or to the space backdrop's near-black.
	var style := panel.get_theme_stylebox("panel")
	var base: Color = style.bg_color if style is StyleBoxFlat else Color("000410")
	for pixel in range(18):
		var colour := base
		colour.a=1.0-float(pixel)/18.0
		if above: draw_rect(Rect2(0,pixel,width,1),colour)
		if below: draw_rect(Rect2(0,size.y-pixel-1,width,1),colour)
