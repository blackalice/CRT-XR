extends Control
## Transport bar over the view while a video plays: title, position and a
## progress track. It appears on pause, seeks and changes, and stays while paused.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const VideoLibrary = preload("res://scripts/video/video_library.gd")
const HOLD_SECONDS := 3.0
var title := ""
var position_seconds := 0.0
var duration := 0.0
var paused := false
var detail := ""
var remaining := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -178
	offset_bottom = -86
	hide()

## Shows the bar for a few seconds; `note` is a one-off line such as the new shape.
func flash(note := "") -> void:
	detail = note
	remaining = HOLD_SECONDS
	show()
	queue_redraw()

func track(name: String, seconds: float, length: float, is_paused: bool, delta: float, allowed: bool) -> void:
	title = name
	position_seconds = seconds
	duration = length
	paused = is_paused
	if not paused: remaining = maxf(0.0, remaining - delta)
	visible = allowed and (paused or remaining > 0.0)
	if visible: queue_redraw()

func _draw() -> void:
	var width := minf(size.x - 80.0, 780.0)
	var box := Rect2((size.x - width) * 0.5, 0.0, width, size.y)
	draw_style_box(MenuSkin.box(Color(0.08, 0.09, 0.11, 0.86), Color("47535b"), 1, 12), box)
	var font := get_theme_default_font()
	var ink := Color("f2ead9")
	# Play or pause state, drawn rather than typed so every font shows it.
	var icon := box.position + Vector2(30, 28)
	if paused:
		draw_rect(Rect2(icon + Vector2(-7, -9), Vector2(5, 18)), ink)
		draw_rect(Rect2(icon + Vector2(2, -9), Vector2(5, 18)), ink)
	else:
		draw_colored_polygon(PackedVector2Array([icon + Vector2(-6, -9), icon + Vector2(8, 0), icon + Vector2(-6, 9)]), ink)
	var times := VideoLibrary.clock(position_seconds) + " / " + VideoLibrary.clock(duration)
	var time_width := font.get_string_size(times, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, box.position + Vector2(50, 36), title, HORIZONTAL_ALIGNMENT_LEFT, width - time_width - 90.0, 22, ink)
	draw_string(font, Vector2(box.end.x - 20.0 - time_width, box.position.y + 36), times, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	var bar := Rect2(box.position.x + 20, box.position.y + 52, width - 40, 6)
	draw_rect(bar, Color("3a4047"))
	var fraction := clampf(position_seconds / duration, 0.0, 1.0) if duration > 0.0 else 0.0
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), MenuSkin.AMBER)
	draw_circle(Vector2(bar.position.x + bar.size.x * fraction, bar.get_center().y), 7, MenuSkin.AMBER)
	var hint := detail if not detail.is_empty() else "A pause · D-pad ←→ 10 s, hold to scrub · ↑↓ 1 min · Y shape · X audio · B menu"
	draw_string(font, box.position + Vector2(20, 82), hint, HORIZONTAL_ALIGNMENT_LEFT, width - 40, 16, MenuSkin.MUTED)
