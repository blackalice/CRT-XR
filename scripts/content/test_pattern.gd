extends Node2D
## Original animated test signal. Replace this content viewport with core framebuffer uploads.

var elapsed := 0.0
var paused := false

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 256, 240), Color("101c2e"))
	for x in range(0, 257, 16):
		draw_line(Vector2(x, 0), Vector2(x, 240), Color("25384a"))
	for y in range(0, 241, 16):
		draw_line(Vector2(0, y), Vector2(256, y), Color("25384a"))
	var colors := [Color("eeeecc"), Color("ffcf55"), Color("63d8cf"), Color("68b86e"), Color("d181c4"), Color("dc6654"), Color("627dc4")]
	for i in range(7):
		draw_rect(Rect2(16 + i * 32, 40, 32, 70), colors[i])
	# 256x240 is displayed at 4:3, so source pixels are 1.25 times wider.
	# Compensate the calibration circle so it is round on the physical tube.
	draw_set_transform(Vector2(128, 145), 0, Vector2(0.8, 1.0))
	draw_circle(Vector2.ZERO, 43, Color("d6e1cb"), false, 2.0)
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(80, 145), Vector2(176, 145), Color.WHITE)
	draw_line(Vector2(128, 100), Vector2(128, 190), Color.WHITE)
	draw_rect(Rect2(14, 14, 228, 212), Color("a9c8c9"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(50, 32), "CRT XR / TEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e2ede4"))
	draw_string(ThemeDB.fallback_font, Vector2(38, 213), "256 x 240  /  4:3", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e2ede4"))
	var x := 24.0 + fmod(elapsed * 36.0, 200.0)
	draw_rect(Rect2(x, 177, 9, 9), Color("f4c76a"))
