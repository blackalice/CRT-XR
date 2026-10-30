extends Node2D
## The loading card's words, drawn sharp over its 256x240 graphics as the menus
## draw theirs: the card is shown three times over (768x720, the menu's 720
## lines) with hard pixels, and the text is set at that full resolution in the
## dot font, with a shadow one card pixel deep.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const SCALE := 3.0
const TEXT := Color("e8ecf8")
const MUTED := Color("98a8d0")
const SHADOW := Color("000418")
var card: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if card == null: return
	var font := MenuSkin.font(MenuSkin.REGULAR)
	var width := 256.0 * SCALE
	# LOADING keeps its place as its dots grow.
	var word := "LOADING"
	var start := floorf((width - font.get_string_size(word + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x) * 0.5)
	text(font, Vector2(start, 96), word + ".".repeat(1 + int(card.elapsed * 2.5) % 3), 44, TEXT)
	centred(font, 566, card.short_title(card.title), 32, MUTED)
	var progress: float = card.progress
	centred(font, 692, ("%d%%" % roundi(clampf(progress, 0.0, 1.0) * 100.0)) if progress >= 0.0 else "Starting disc", 32, MUTED)

func text(font: Font, at: Vector2, words: String, size: int, colour: Color) -> void:
	draw_string(font, at + Vector2.ONE * SCALE, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SHADOW)
	draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)

func centred(font: Font, baseline: float, words: String, size: int, colour: Color) -> void:
	var span := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(font, Vector2(floorf((256.0 * SCALE - span) * 0.5), baseline), words, size, colour)
