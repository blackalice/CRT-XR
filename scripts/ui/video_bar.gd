extends Control
## Transport bar over the view while a video plays: title, position and a
## progress track. It appears on pause, seeks and changes, and stays while paused.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const VideoLibrary = preload("res://scripts/video/video_library.gd")
const HOLD_SECONDS := 3.0
const InputGlyph = preload("res://scripts/ui/input_glyph.gd")
const TransportIcon = preload("res://scripts/ui/music_transport_icon.gd")
var title := ""
var position_seconds := 0.0
var duration := 0.0
var paused := false
var detail := ""
var remaining := 0.0
var hints: GridContainer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -202
	offset_bottom = -86
	var panel := MenuSkin.pixel_panel("music_well")
	add_child(panel)
	hints = GridContainer.new()
	hints.columns = 6
	hints.name = "ControllerHints"
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.add_theme_constant_override("h_separation", 12)
	hints.add_theme_constant_override("v_separation", 8)
	for prompt in [["A", "Pause"], ["←→", "10 s"], ["↑↓", "1 min"], ["Y", "Shape"], ["X", "Audio"], ["B", "Menu"]]:
		var group := HBoxContainer.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_theme_constant_override("separation", 10)
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_child(InputGlyph.new(prompt[0], 30))
		var label := Label.new()
		label.text = prompt[1]
		label.add_theme_font_override("font", MenuSkin.font(MenuSkin.REGULAR))
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", MenuSkin.TEXT)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(label)
		hints.add_child(group)
	add_child(hints)
	resized.connect(func():
		var margin := (size.x - minf(size.x - 80.0, 780.0)) * 0.5
		panel.offset_left = margin; panel.offset_right = -margin
		hints.position = Vector2(margin + 20, 70)
		hints.size = Vector2(size.x - 2 * margin - 40, 30))
	hide()

## Shows the bar for a few seconds; `note` is a one-off line such as the new shape.
func flash(note := "") -> void:
	detail = note
	hints.visible = detail.is_empty()
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

	var font := MenuSkin.font(MenuSkin.REGULAR)
	var ink := MenuSkin.TEXT
	# The same two-pixel transport symbols used on the deck keys.
	var symbol: Array = TransportIcon.SYMBOLS["pause" if paused else "play"]
	var icon := box.position + Vector2(22, 18)
	for y in range(symbol.size()):
		for x in range(symbol[y].length()):
			if symbol[y][x] == "#": draw_rect(Rect2(icon + Vector2(x, y) * 2, Vector2(2, 2)), ink)
	var times := VideoLibrary.clock(position_seconds) + " / " + VideoLibrary.clock(duration)
	var time_width := font.get_string_size(times, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, box.position + Vector2(50, 36), title, HORIZONTAL_ALIGNMENT_LEFT, width - time_width - 90.0, 22, ink)
	draw_string(font, Vector2(box.end.x - 20.0 - time_width, box.position.y + 36), times, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	# A recessed segmented track matches the menu deck's timeline.
	var bar := Rect2(box.position.x + 20, box.position.y + 49, width - 40, 12)
	draw_rect(bar, Color("000818"))
	var fraction := clampf(position_seconds / duration, 0.0, 1.0) if duration > 0.0 else 0.0
	var pitch := floorf((bar.size.x / 2.0 - 3.0) / 32.0) * 2.0
	var lit := roundi(fraction * 32.0)
	for n in range(32):
		draw_rect(Rect2(bar.position + Vector2(4 + n * pitch, 4), Vector2(pitch - 2, 4)), MenuSkin.AMBER if n < lit else Color("0c1c48"))
	if not detail.is_empty():
		draw_string(font, box.position + Vector2(24, 92), detail, HORIZONTAL_ALIGNMENT_LEFT, width - 40, 16, MenuSkin.TEXT)
