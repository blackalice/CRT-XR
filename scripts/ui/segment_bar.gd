extends Control
## A slider's bar in the style of the disc loading card: twenty equal segments
## in a recessed well, lit up to the value of the ProgressBar it sits in. Every
## measure is whole 2×2-pixel cells, so no segment is squeezed or dropped.
const CELL := 2.0
const SEGMENTS := 20
const WELL := Color("000818")
const LO := Color("000418")
const HI := Color("3858a0")
const UNLIT := Color("0c1c48")
const LIT := Color("f8c048")
const BRIGHT := Color("f8d860")
## The focused slider glows; the others stay quiet.
var bright := false:
	set(value):
		if bright == value: return
		bright = value; queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar := get_parent() as Range
	if bar != null: bar.value_changed.connect(func(_value): queue_redraw())

func _draw() -> void:
	var bar := get_parent() as Range
	if bar == null: return
	var cells := floori(size.x / CELL)
	var rows := floori(size.y / CELL)
	# A cell of bevel and a cell of gap at each end, and one between segments.
	var pitch := floori((cells - 3) / float(SEGMENTS))
	if pitch < 2 or rows < 5: return
	var used := pitch * SEGMENTS + 3
	var x := floorf((cells - used) / 2.0) * CELL
	var width := used * CELL
	var height := rows * CELL
	draw_rect(Rect2(x, 0, width, height), WELL)
	draw_rect(Rect2(x, 0, width, CELL), LO); draw_rect(Rect2(x, 0, CELL, height), LO)
	draw_rect(Rect2(x, height - CELL, width, CELL), HI); draw_rect(Rect2(x + width - CELL, 0, CELL, height), HI)
	var span := bar.max_value - bar.min_value
	var lit := roundi(clampf((bar.value - bar.min_value) / span if span > 0.0 else 0.0, 0.0, 1.0) * SEGMENTS)
	var colour := BRIGHT if bright else LIT
	for n in range(SEGMENTS):
		draw_rect(Rect2(x + (2 + n * pitch) * CELL, 2 * CELL, (pitch - 1) * CELL, height - 4 * CELL), colour if n < lit else UNLIT)
