extends Control
## One controller control, drawn the same way everywhere in the menus (footer
## hints, header buttons, help pages, the Game controls page): the four face
## buttons as a diamond of circles with the one meant filled in, as Nintendo's
## menus do (by position, so it reads right on Deck, Xbox and Switch pads alike);
## the D-pad as a cross with the arms meant filled; a stick direction as a ring
## with an arrow marked L or R; shoulders, triggers, stick clicks and Back/Start
## as labelled badges. Names are controller_layouts.gd inputs or the words the
## menus use (A/B/X/Y in Deck/Xbox positions, L1, R3, Start, D-pad, ↑↓, ←→);
## the Back button is drawn from its input name, "back".
const FACE := {"north": Vector2(0, -1), "south": Vector2(0, 1), "west": Vector2(-1, 0), "east": Vector2(1, 0)}
const DIRECTIONS := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
## D-pad drawings for whole axes: which arms are filled.
const DPADS := {"dpad": ["up", "down", "left", "right"], "dpad_vertical": ["up", "down"], "dpad_horizontal": ["left", "right"]}
const BADGES := {"l1": "L1", "r1": "R1", "l2": "L2", "r2": "R2", "l3": "L3", "r3": "R3", "back": "Back", "start": "Start"}
const ALIASES := {"A": "south", "B": "east", "X": "west", "Y": "north", "L1": "l1", "R1": "r1", "L2": "l2", "R2": "r2",
	"L3": "l3", "R3": "r3", "Start": "start", "D-pad": "dpad", "↑↓": "dpad_vertical", "←→": "dpad_horizontal"}
# "Back" and "Select" stay words: the menus use them for actions ("B Back").
## Drawn at this height and scaled to the one asked for.
const DESIGN := 40.0
var input := "south"
var colour := Color("e6e6e6")
var scale_factor := 1.0

func _init(name := "south", height := DESIGN) -> void:
	input = ALIASES.get(name, name)
	scale_factor = height / DESIGN
	var badge: String = BADGES.get(input, "")
	var width := maxf(DESIGN, 18.0 + badge.length() * 12.0) if not badge.is_empty() else DESIGN
	custom_minimum_size = Vector2(width, DESIGN) * scale_factor
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Whether a word names a control this draws.
static func knows(word: String) -> bool:
	var name: String = ALIASES.get(word, word)
	return FACE.has(name) or DIRECTIONS.has(name) or DPADS.has(name) or BADGES.has(name) or \
		((name.begins_with("ls_") or name.begins_with("rs_")) and DIRECTIONS.has(name.substr(3)))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	var extent := size / scale_factor
	var centre := extent * 0.5
	var dim := Color(colour, 0.45)
	if FACE.has(input):
		for position in FACE:
			var spot: Vector2 = centre + FACE[position] * 12.0
			if position == input: draw_circle(spot, 6.4, colour, true, -1.0, true)
			else: draw_circle(spot, 5.6, dim, false, 1.6, true)
	elif DIRECTIONS.has(input) or DPADS.has(input):
		# The D-pad: a cross outline with the meant arms filled.
		var lit: Array = DPADS.get(input, [input])
		for direction in DIRECTIONS:
			var arm := Rect2(centre + DIRECTIONS[direction] * 10.5 - Vector2(5.5, 5.5), Vector2(11, 11))
			if direction in lit: draw_rect(arm, colour)
			else: draw_rect(arm, dim, false, 1.5)
		draw_rect(Rect2(centre - Vector2(5, 5), Vector2(10, 10)), dim)
	elif input.begins_with("ls_") or input.begins_with("rs_"):
		# A stick: its ring, an arrow the way it is pushed, and L or R.
		var way: Vector2 = DIRECTIONS[input.substr(3)]
		draw_arc(centre, 17.0, 0.0, TAU, 40, dim, 1.6, true)
		var tip: Vector2 = centre + way * 13.0
		var side := Vector2(-way.y, way.x)
		draw_colored_polygon(PackedVector2Array([tip, tip - way * 8.0 + side * 6.0, tip - way * 8.0 - side * 6.0]), colour)
		var letter := "L" if input.begins_with("ls_") else "R"
		var font := ThemeDB.fallback_font
		var offset := -way * 5.0
		draw_string(font, centre + offset + Vector2(-font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x * 0.5, font.get_ascent(15) * 0.5 - 1.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, colour)
	else:
		var text: String = BADGES.get(input, input)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("252b33"); style.border_color = colour
		style.set_border_width_all(1); style.set_corner_radius_all(6 if input in ["l1", "r1", "l2", "r2"] else 9)
		draw_style_box(style, Rect2(Vector2(1, 6), extent - Vector2(2, 12)))
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, Vector2((extent.x - width) * 0.5, (extent.y - font.get_height(17)) * 0.5 + font.get_ascent(17)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, colour)

## A run of controls as written in the menus' text ("L1 + R1 + Start",
## "L1 / R1", "D-pad"): known controls drawn, joining words as quiet text.
static func row(text: String, height: float, font_size: int, joining: Color) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for word in text.split(" ", false):
		if knows(word): line.add_child(load("res://scripts/ui/input_glyph.gd").new(word, height))
		else:
			var label := Label.new()
			label.text = word
			label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", joining)
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			line.add_child(label)
	return line
