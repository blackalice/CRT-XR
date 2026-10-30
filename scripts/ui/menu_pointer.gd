extends Control
## The Mega-CD control panel's pointer, beside the selected row: the arrow from
## Kenney's 1-Bit Pack, its tip resting inside the row's lower right corner and
## its body hanging away from the text, bobbing a cell at a time. It joins the
## marquee; Reduce animation holds it still.
const RowIcon = preload("res://scripts/ui/row_icon.gd")
const SPRITE := "res://assets/icons/glyphs/pointer.png"
## The arrow's tip in the sprite, in cells.
const TIP := Vector2(1, 1)
const CELL := 2.0
const SHADOW := Color("000418")
var menu: Control
var scroll: ScrollContainer
var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var picture := RowIcon.cached(SPRITE)
	var row: Control = menu.selected_row() if menu != null else null
	if picture == null or row == null or menu.preview or not row.is_visible_in_tree(): return
	var shown: Rect2 = row.get_global_rect()
	# Only beside a row that is in view: a scrolled-off row keeps no pointer.
	if not scroll.get_global_rect().grow(1.0).encloses(shown): return
	var bob := 0.0 if menu.host.menu_reduced_motion else float(int(time * 2.5) % 2) * CELL
	var tip := shown.end - Vector2(12, 12) + Vector2(bob, bob) - get_global_transform().origin
	var at := ((tip - TIP * CELL) / CELL).round() * CELL
	var drawn := picture.get_size() * CELL
	draw_texture_rect(picture, Rect2(at + Vector2.ONE * CELL, drawn), false, SHADOW)
	draw_texture_rect(picture, Rect2(at, drawn), false, Color.WHITE)
