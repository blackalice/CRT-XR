extends Control
## Transport bar over the view while a video plays: title, position and a
## progress track. It appears on pause, seeks and changes, and stays while paused.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const VideoLibrary = preload("res://scripts/video/video_library.gd")
const HOLD_SECONDS := 3.0
const InputGlyph = preload("res://scripts/ui/input_glyph.gd")
const SegmentBar = preload("res://scripts/ui/segment_bar.gd")
const TransportIcon = preload("res://scripts/ui/music_transport_icon.gd")
var title := ""
var position_seconds := 0.0
var duration := 0.0
var paused := false
var detail := ""
var remaining := 0.0
var visualizer := false
var timeline: ProgressBar
var hints: GridContainer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -202
	offset_bottom = -86
	var panel := MenuSkin.pixel_panel("music_well")
	add_child(panel)
	timeline=ProgressBar.new();timeline.show_percentage=false;timeline.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for style in ["background","fill"]:timeline.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	var segments := SegmentBar.new();segments.segments=32;timeline.add_child(segments);add_child(timeline)
	hints = GridContainer.new()
	hints.columns = 6
	hints.name = "ControllerHints"
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.add_theme_constant_override("h_separation", 12)
	hints.add_theme_constant_override("v_separation", 8)
	set_prompts([["A", "Pause"], ["←→", "10 s"], ["↑↓", "1 min"], ["Y", "Shape"], ["X", "Audio"], ["B", "Menu"]])
	add_child(hints)
	resized.connect(func():
		var margin := (size.x - minf(size.x - 80.0, 780.0)) * 0.5
		panel.offset_left = margin; panel.offset_right = -margin
		timeline.position=Vector2(margin+20,49)
		timeline.size=Vector2(size.x-2*margin-40,16)
		hints.position = Vector2(margin + 20, 70)
		hints.size = Vector2(size.x - 2 * margin - 40, 30))
	hide()

## Reuse the same pixel panel, typography, transport symbols and input glyphs.
func set_prompts(prompts: Array) -> void:
	for child in hints.get_children():
		hints.remove_child(child);child.queue_free()
	hints.columns=prompts.size()
	for prompt in prompts:

		var group := HBoxContainer.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_theme_constant_override("separation", 10)
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glyph := InputGlyph.new(prompt[0],30);glyph.colour=MenuSkin.TEXT;glyph.drop_shadow=true
		group.add_child(glyph)
		var label := Label.new()
		label.text = prompt[1]
		label.add_theme_font_override("font", MenuSkin.font(MenuSkin.REGULAR))
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", MenuSkin.TEXT)
		MenuSkin.shadow(label)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(label)
		hints.add_child(group)

func use_visualizer() -> void:
	visualizer=true
	set_prompts([["A","Pause"],["←→","Preset"],["↑↓","Brightness"],["Y","Mode"],["B","Menu"]])

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
	timeline.max_value=maxf(1.0,length);timeline.value=seconds
	timeline.visible=length>0.0
	if not paused: remaining = maxf(0.0, remaining - delta)
	visible = allowed and (paused or remaining > 0.0)
	if visible: queue_redraw()

func _draw() -> void:
	var width := minf(size.x - 80.0, 780.0)
	var box := Rect2((size.x - width) * 0.5, 0.0, width, size.y)

	var font := MenuSkin.font(MenuSkin.SEMIBOLD)
	var ink := MenuSkin.TEXT
	# The same two-pixel transport symbols used on the deck keys.
	TransportIcon.draw_on(self,"pause" if paused else "play",box.position+Vector2(22,18),MenuSkin.AMBER if paused else ink)
	var times := "Live radio" if visualizer and duration<=0.0 else VideoLibrary.clock(position_seconds) + " / " + VideoLibrary.clock(duration)
	var time_width := font.get_string_size(times, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	shadow_text(font, box.position + Vector2(50, 36), title, HORIZONTAL_ALIGNMENT_LEFT, width - time_width - 90.0, 22, ink)
	shadow_text(font, Vector2(box.end.x - 20.0 - time_width, box.position.y + 36), times, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, MenuSkin.VALUE)
	if not detail.is_empty():
		shadow_text(font, box.position + Vector2(24, 92), detail, HORIZONTAL_ALIGNMENT_LEFT, width - 40, 16, MenuSkin.VALUE)

func shadow_text(font: Font, position: Vector2, text: String, alignment: int, width: float, font_size: int, colour: Color) -> void:
	draw_string(font,position+Vector2(2,2),text,alignment,width,font_size,MenuSkin.SHADOW)
	draw_string(font,position,text,alignment,width,font_size,colour)
