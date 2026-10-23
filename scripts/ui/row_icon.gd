extends Control
## Small vector icons that say what a row is (a folder, a game, a place, an
## action) before its text is read. Drawn locally like the console glyphs.
var kind := "folder"
var colour := Color("b2b4b7")

func _init(icon_kind := "folder", tint := Color("b2b4b7")) -> void:
	kind = icon_kind
	colour = tint
	custom_minimum_size = Vector2(30, 30)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func block(rect: Rect2, tint: Color, radius := 2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _draw() -> void:
	var c := colour
	var ink := Color("1d2026")
	match kind:
		"folder", "album":
			block(Rect2(3, 6, 11, 5), c, 2)
			block(Rect2(3, 9, 24, 16), c, 3)
			if kind == "album": draw_circle(Vector2(15, 17), 4.5, ink); draw_circle(Vector2(15, 17), 1.4, c)
		"up":
			draw_line(Vector2(15, 24), Vector2(15, 8), c, 3, true)
			draw_polyline(PackedVector2Array([Vector2(8, 14), Vector2(15, 7), Vector2(22, 14)]), c, 3, true)
		"cartridge":
			block(Rect2(6, 4, 18, 22), c, 3)
			block(Rect2(9, 7, 12, 9), ink, 1)
			for x in [10, 14, 18]: block(Rect2(x, 21, 2, 4), ink, 0)
		"video":
			block(Rect2(3, 7, 24, 16), c, 3)
			draw_colored_polygon(PackedVector2Array([Vector2(12, 11), Vector2(20, 15), Vector2(12, 19)]), ink)
		"music":
			draw_line(Vector2(19, 6), Vector2(19, 20), c, 2.5, true)
			draw_line(Vector2(19, 6), Vector2(25, 9), c, 2.5, true)
			draw_circle(Vector2(15, 21), 4.5, c)
		"drive":
			block(Rect2(3, 9, 24, 13), c, 3)
			draw_circle(Vector2(22, 15.5), 1.8, ink)
			block(Rect2(7, 14.5, 9, 2), ink, 0)
		"sd":
			draw_colored_polygon(PackedVector2Array([Vector2(8, 4), Vector2(19, 4), Vector2(24, 9), Vector2(24, 26), Vector2(8, 26)]), c)
			for x in [11, 14, 17, 20]: block(Rect2(x, 6, 2, 5), ink, 0)
		"home":
			draw_colored_polygon(PackedVector2Array([Vector2(15, 4), Vector2(27, 14), Vector2(24, 14), Vector2(24, 26), Vector2(6, 26), Vector2(6, 14), Vector2(3, 14)]), c)
			block(Rect2(12, 17, 6, 9), ink, 1)
		"network":
			draw_arc(Vector2(15, 15), 10, 0, TAU, 32, c, 2.5, true)
			draw_line(Vector2(5, 15), Vector2(25, 15), c, 2, true)
			draw_arc(Vector2(15, 15), 4.5, -PI / 2, PI / 2, 16, c, 2, true)
			draw_arc(Vector2(15, 15), 4.5, PI / 2, 3 * PI / 2, 16, c, 2, true)
		"refresh":
			draw_arc(Vector2(15, 15), 9, 0.4, TAU - 0.9, 28, c, 3, true)
			draw_colored_polygon(PackedVector2Array([Vector2(24, 4), Vector2(25, 13), Vector2(17, 10)]), c)
		"edit":
			draw_line(Vector2(7, 23), Vector2(22, 8), c, 5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(4, 26), Vector2(5, 20), Vector2(10, 25)]), c)
		"clear":
			draw_line(Vector2(8, 8), Vector2(22, 22), c, 3, true)
			draw_line(Vector2(22, 8), Vector2(8, 22), c, 3, true)
		"check":
			draw_polyline(PackedVector2Array([Vector2(5, 16), Vector2(12, 23), Vector2(25, 8)]), c, 4, true)
		"search":
			draw_arc(Vector2(13, 13), 7.5, 0, TAU, 28, c, 3, true)
			draw_line(Vector2(18.5, 18.5), Vector2(25, 25), c, 3.5, true)
		"page":
			draw_polyline(PackedVector2Array([Vector2(11, 7), Vector2(19, 15), Vector2(11, 23)]), c, 3, true)
		"play":
			draw_colored_polygon(PackedVector2Array([Vector2(9, 6), Vector2(25, 15), Vector2(9, 24)]), c)
		"save", "load":
			# A floppy disk; loading adds an arrow out of it.
			block(Rect2(5, 5, 20, 20), c, 3)
			block(Rect2(10, 5, 10, 7), ink, 1)
			block(Rect2(9, 16, 12, 9), ink, 1)
			if kind == "load":
				draw_line(Vector2(15, 24), Vector2(15, 18), c, 2, true)
				draw_polyline(PackedVector2Array([Vector2(12, 21), Vector2(15, 18), Vector2(18, 21)]), c, 2, true)
		"camera":
			block(Rect2(4, 9, 22, 15), c, 3)
			block(Rect2(10, 6, 9, 5), c, 2)
			draw_circle(Vector2(15, 16.5), 5, ink)
			draw_circle(Vector2(15, 16.5), 2.5, c)
		"gear":
			for i in range(8):
				var angle := TAU * i / 8.0
				draw_line(Vector2(15, 15) + Vector2.from_angle(angle) * 6, Vector2(15, 15) + Vector2.from_angle(angle) * 11, c, 4, true)
			draw_circle(Vector2(15, 15), 7.5, c)
			draw_circle(Vector2(15, 15), 3, ink)
		"sliders":
			for row in range(3):
				var y := 8.0 + row * 7.0
				draw_line(Vector2(5, y), Vector2(25, y), c, 2, true)
				draw_circle(Vector2([11.0, 19.0, 14.0][row], y), 3.2, c)
		"exit":
			draw_arc(Vector2(15, 16), 9, -PI * 0.3, PI * 1.3, 24, c, 3, true)
			draw_line(Vector2(15, 4), Vector2(15, 15), c, 3, true)
		"stop":
			block(Rect2(8, 8, 14, 14), c, 2)
