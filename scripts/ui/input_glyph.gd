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
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
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
	# Its grid snap depends on where it sits, so moving redraws it.
	set_notify_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED: queue_redraw()

## Whether a word names a control this draws.
static func knows(word: String) -> bool:
	var name: String = ALIASES.get(word, word)
	return FACE.has(name) or DIRECTIONS.has(name) or DPADS.has(name) or BADGES.has(name) or \
		((name.begins_with("ls_") or name.begins_with("rs_")) and DIRECTIONS.has(name.substr(3)))

## Drawn as pixel sprites on the menus' 2×2-pixel grid, so glyphs match the
## 16-bit panels: every shape is designed on a 15×15-cell square, drawn at a
## whole number of cells and snapped to the same grid as the backdrop.
const CELL := 2.0
const GRID := 15
const WELL := Color("000c30")
const RING := [".###.", "#...#", "#...#", "#...#", ".###."]
const DOT := [".###.", "#####", "#####", "#####", ".###."]
## Where each face button sits in the diamond, in cells.
const FACE_AT := {"north": Vector2i(5, 0), "south": Vector2i(5, 10), "west": Vector2i(0, 5), "east": Vector2i(10, 5)}
const ARROW := ["..#..", ".###.", "#####"]
var origin := Vector2.ZERO
var cell_size := CELL

## Pixels from a local point to the nearest point on the menu's 2-pixel grid.
func on_grid(local: Vector2) -> Vector2:
	var at := get_global_transform().origin + local
	return (at / CELL).round() * CELL - get_global_transform().origin

func block(x: int, y: int, colour: Color) -> void:
	draw_rect(Rect2(origin + Vector2(x, y) * cell_size, Vector2.ONE * cell_size), colour)

func bitmap(rows: Array, at: Vector2i, colour: Color) -> void:
	for j in range(rows.size()):
		for i in range(rows[j].length()):
			if rows[j][i] == "#": block(at.x + i, at.y + j, colour)

## Turns an upward-pointing bitmap to face a direction.
static func turned(rows: Array, way: Vector2) -> Array:
	var h := rows.size(); var w: int = rows[0].length()
	var out := []
	if way.y < 0: return rows
	if way.y > 0:
		for j in range(h - 1, -1, -1): out.append(rows[j])
		return out
	for i in range(w):
		var line := ""
		for j in range(h): line += rows[h - 1 - j][i] if way.x > 0 else rows[j][w - 1 - i]
		out.append(line)
	return out

func in_cross(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < GRID and y < GRID and ((x >= 5 and x <= 9) or (y >= 5 and y <= 9))

func _draw() -> void:
	var dim := Color(colour, 0.45)
	if FACE.has(input) or DIRECTIONS.has(input) or DPADS.has(input) or input.begins_with("ls_") or input.begins_with("rs_"):
		cell_size = CELL * maxi(1, floori(minf(size.x, size.y) / (GRID * CELL)))
		origin = on_grid((size - Vector2.ONE * GRID * cell_size) * 0.5)
	if FACE.has(input):
		# Four circles in a diamond, the meant one filled, as Nintendo's menus draw them.
		for position in FACE_AT:
			bitmap(DOT if position == input else RING, FACE_AT[position], colour if position == input else dim)
	elif DIRECTIONS.has(input) or DPADS.has(input):
		# The D-pad: a cross outline with the meant arms filled.
		var lit: Array = DPADS.get(input, [input])
		for y in range(GRID):
			for x in range(GRID):
				if not in_cross(x, y): continue
				var arm := "up" if y < 5 else ("down" if y > 9 else ("left" if x < 5 else ("right" if x > 9 else "")))
				var edge := not (in_cross(x - 1, y) and in_cross(x + 1, y) and in_cross(x, y - 1) and in_cross(x, y + 1))
				if arm in lit: block(x, y, colour)
				elif edge or arm.is_empty(): block(x, y, dim)
	elif input.begins_with("ls_") or input.begins_with("rs_"):
		# A stick: its ring, an arrow the way it is pushed, and L or R.
		var way: Vector2 = DIRECTIONS[input.substr(3)]
		for y in range(GRID):
			for x in range(GRID):
				var distance := Vector2(x - 7, y - 7).length()
				if distance >= 6.0 and distance < 7.4: block(x, y, dim)
		var arrow := turned(ARROW, way)
		var arrow_width: int = str(arrow[0]).length()
		var at := Vector2i(7, 7) + Vector2i(way * 4.0) - Vector2i(arrow_width / 2, arrow.size() / 2)
		bitmap(arrow, at, colour)
		var letter := "L" if input.begins_with("ls_") else "R"
		var font := MenuSkin.font(MenuSkin.BOLD)
		var size_px := int(cell_size * 5)
		var centre := origin + (Vector2(7.5, 7.5) - way * 2.5) * cell_size
		draw_string(font, centre + Vector2(-font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5, font.get_ascent(size_px) * 0.5 - 1.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, colour)
	else:
		# A badge: a recessed plate with a one-cell outline and its name in the dot font.
		var text: String = BADGES.get(input, input)
		var from := on_grid(Vector2(1, 6) * scale_factor)
		var to := on_grid(size - Vector2(1, 6) * scale_factor)
		draw_rect(Rect2(from, to - from), WELL)
		draw_rect(Rect2(from, Vector2(to.x - from.x, CELL)), colour); draw_rect(Rect2(Vector2(from.x, to.y - CELL), Vector2(to.x - from.x, CELL)), colour)
		draw_rect(Rect2(from, Vector2(CELL, to.y - from.y)), colour); draw_rect(Rect2(Vector2(to.x - CELL, from.y), Vector2(CELL, to.y - from.y)), colour)
		var font := MenuSkin.font(MenuSkin.BOLD)
		var size_px := int(17 * scale_factor)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string(font, Vector2(roundf((size.x - width) * 0.5), roundf((size.y - font.get_height(size_px)) * 0.5 + font.get_ascent(size_px))), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, colour)

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
