extends Node2D
## Text for the idle signal, drawn at the menu's 720-line resolution over its
## nearest-neighbour 256×240 graphics, like the disc loading card.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const SCALE := 3.0
const SHADOW := Color("000418")

func _draw() -> void:
	text("CRT XR", Vector2(20, 30), 42, MenuSkin.TEXT)
	text("TEST SIGNAL", Vector2(20, 30), 33, MenuSkin.AMBER, 216, HORIZONTAL_ALIGNMENT_RIGHT)
	text("256 x 240", Vector2(20, 218), 30, MenuSkin.TEXT)
	text("4:3", Vector2(20, 218), 30, MenuSkin.MUTED, 216, HORIZONTAL_ALIGNMENT_RIGHT)

func text(words: String, position: Vector2, size: int, colour: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := MenuSkin.font(MenuSkin.REGULAR)
	var at := position * SCALE
	var span := width * SCALE if width >= 0.0 else -1.0
	draw_string(font, at + Vector2.ONE * SCALE, words, align, span, size, SHADOW)
	draw_string(font, at, words, align, span, size, colour)
