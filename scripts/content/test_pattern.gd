extends Node2D
## Idle test signal, drawn at 256×240 and displayed at 4:3. The bars, grid,
## circle and moving marker remain useful for checking the picture geometry.
const LoadingScreen = preload("res://scripts/content/loading_screen.gd")
const SIZE := Vector2i(256, 240)
const INK := Color("000418")
const TEXT := Color("e8ecf8")
const MUTED := Color("98a8d0")
const AMBER := Color("f8c048")
const GRID := Color("284378")
const BARS := [Color("eeeecc"), Color("ffcf55"), Color("63d8cf"), Color("68b86e"), Color("d181c4"), Color("dc6654"), Color("627dc4")]
var elapsed := 0.0
var paused := false
var backdrop: ImageTexture

func _ready() -> void:
	backdrop = ImageTexture.create_from_image(LoadingScreen.sky())

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	if backdrop != null: draw_texture(backdrop, Vector2.ZERO)
	# Sparse stars and a fine grid, behind the calibration marks.
	for i in range(28):
		var x := floorf(fposmod(i * 53.0 - elapsed * (2.0 + i % 3 * 2.0), float(SIZE.x)))
		var y := float(7 + (i * 37) % 216)
		if (Vector2(x, y) - LoadingScreen.PLANET_CENTRE).length() < LoadingScreen.PLANET_RADIUS * 1.02: continue
		draw_rect(Rect2(x, y, 1, 1), MUTED if i % 3 == 0 else Color("385080"))
	for x in range(16, 241, 16): draw_line(Vector2(x, 13), Vector2(x, 226), Color(GRID, 0.35))
	for y in range(32, 225, 16): draw_line(Vector2(14, y), Vector2(242, y), Color(GRID, 0.35))
	# A one-pixel bevel, the same blue frame as the menus.
	draw_rect(Rect2(8, 8, 240, 224), Color("000818"), false, 2.0)
	draw_rect(Rect2(9, 9, 238, 222), Color("5878b0"), false, 1.0)
	draw_rect(Rect2(14, 14, 228, 23), Color("102860"))
	draw_line(Vector2(14, 14), Vector2(242, 14), Color("5878b0"))
	# Seven distinct colour swatches, kept large enough to judge the signal.
	draw_rect(Rect2(15, 43, 226, 63), INK)
	for i in range(BARS.size()):
		draw_rect(Rect2(16 + i * 32, 44, 32, 60), BARS[i])
	# Source pixels stretch horizontally on the tube. Squash x to make this
	# calibration circle round at 4:3, as in the original test signal.
	draw_set_transform(Vector2(128, 151), 0, Vector2(0.8, 1.0))
	draw_circle(Vector2.ZERO, 42, Color("b8c8dc"), false, 1.0)
	draw_circle(Vector2.ZERO, 29, Color("5878b0"), false, 1.0)
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(90, 151), Vector2(166, 151), Color("d8e4f0"))
	draw_line(Vector2(128, 106), Vector2(128, 196), Color("d8e4f0"))
	# One moving amber block shows at a glance that the signal is running.
	var marker_x := 22.0 + floorf(fposmod(elapsed * 30.0, 205.0))
	draw_rect(Rect2(marker_x, 189, 7, 7), INK)
	draw_rect(Rect2(marker_x, 188, 6, 6), AMBER)
	draw_rect(Rect2(14, 205, 228, 19), Color("081440"))
