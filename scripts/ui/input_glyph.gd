extends Control
## One physical control, drawn the way console menus show it: the four face
## buttons as a diamond of circles with the one meant filled in, the D-pad as a
## cross with one arm filled, a stick as a ring with an arrow, and shoulders,
## triggers and Back/Start as labelled badges. Inputs are controller_layouts.gd names.
const FACE := {"north": Vector2(0, -1), "south": Vector2(0, 1), "west": Vector2(-1, 0), "east": Vector2(1, 0)}
const DIRECTIONS := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
const BADGES := {"l1": "L1", "r1": "R1", "l2": "L2", "r2": "R2", "l3": "L3", "back": "Back", "start": "Start"}
var input := "south"
var colour := Color("e6e6e6")

func _init(name := "south") -> void:
	input = name
	var badge: String = BADGES.get(input, "")
	custom_minimum_size = Vector2(maxf(40.0, 18.0 + badge.length() * 12.0) if not badge.is_empty() else 40.0, 40.0)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = input

func _draw() -> void:
	var centre := size * 0.5
	var dim := Color(colour, 0.45)
	if FACE.has(input):
		for position in FACE:
			var spot: Vector2 = centre + FACE[position] * 12.0
			if position == input: draw_circle(spot, 6.4, colour, true, -1.0, true)
			else: draw_circle(spot, 5.6, dim, false, 1.6, true)
	elif DIRECTIONS.has(input):
		# The D-pad: a cross outline with the meant arm filled.
		for direction in DIRECTIONS:
			var arm := Rect2(centre + DIRECTIONS[direction] * 10.5 - Vector2(5.5, 5.5), Vector2(11, 11))
			if direction == input: draw_rect(arm, colour)
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
		draw_style_box(style, Rect2(Vector2(1, 6), size - Vector2(2, 12)))
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, Vector2((size.x - width) * 0.5, (size.y - font.get_height(17)) * 0.5 + font.get_ascent(17)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, colour)
