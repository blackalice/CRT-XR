extends SubViewport
## Burns subtitles into the picture before it reaches the CRT, so they get the
## same scanlines, mask and composite colour as the programme, like subtitles
## on a broadcast or a DVD. Text is laid out in 4:3 display space and squashed
## to the frame's line count (a 640x240 frame has tall pixels); picture
## subtitles arrive already placed in frame pixels. The VCR's green on-screen
## display (PLAY, PAUSE, FF, REW) is drawn here too, for the same reason.
const DISPLAY_HEIGHT_PER_WIDTH := 0.75
const VCR_FONT := preload("res://assets/fonts/VCR_OSD_MONO.ttf")
const VCR_GREEN := Color("38ff52")
var picture := TextureRect.new()
var stage := Control.new()
var text := Label.new()
var images := Control.new()
var osd := Label.new()
var shown := ""

func _init() -> void:
	disable_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(picture)
	add_child(images)
	add_child(stage)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", Color.WHITE)
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.add_theme_constant_override("outline_size", 7)
	text.add_theme_font_size_override("font_size", 30)
	stage.add_child(text)
	osd.add_theme_font_override("font", VCR_FONT)
	osd.add_theme_font_size_override("font_size", 44)
	osd.add_theme_color_override("font_color", VCR_GREEN)
	osd.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	osd.add_theme_constant_override("shadow_offset_x", 3)
	osd.add_theme_constant_override("shadow_offset_y", 3)
	stage.add_child(osd)

func setup(frame: Texture2D, width: int, height: int) -> void:
	size = Vector2i(width, height)
	picture.texture = frame
	picture.size = Vector2(width, height)
	images.size = Vector2(width, height)
	var display := Vector2(width, width * DISPLAY_HEIGHT_PER_WIDTH)
	stage.size = display
	stage.scale = Vector2(1.0, height / display.y)
	# Inside the safe area a CRT shows: clear of the curved edges and the bars.
	text.position = Vector2(display.x * 0.08, display.y * 0.55)
	text.size = Vector2(display.x * 0.84, display.y * 0.37)
	# Top left, inside the curved edge, where a recorder puts its mode.
	osd.position = Vector2(display.x * 0.09, display.y * 0.08)

## Shows the VCR's mode text ("" hides it); true when it changed.
func show_osd(message: String) -> bool:
	if osd.text == message: return false
	osd.text = message
	return true

## Shows these cues ({text} or {image, x, y, width, height}); true when the
## picture changed, so the caller can ask the CRT for a new frame.
func show_cues(cues: Array) -> bool:
	var key := ""
	for cue in cues: key += "%s|%s|%s;" % [cue.get("start", 0.0), cue.get("text", ""), cue.get("x", "")]
	if key == shown: return false
	shown = key
	var lines := PackedStringArray()
	for child in images.get_children(): child.queue_free()
	for cue in cues:
		if cue.has("image"):
			var piece := TextureRect.new()
			piece.texture = ImageTexture.create_from_image(cue.image)
			piece.stretch_mode = TextureRect.STRETCH_SCALE
			piece.position = Vector2(cue.x, cue.y)
			piece.size = Vector2(cue.width, cue.height)
			images.add_child(piece)
		elif not str(cue.get("text", "")).is_empty():
			lines.append(str(cue.text))
	text.text = "\n".join(lines)
	return true
