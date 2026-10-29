extends Node2D
## Original "please wait" card for disc games, shown on the TV while a disc
## unpacks and the console boots: a spinning CD, LOADING and a progress bar,
## drawn at the test signal's 256x240 so the tube gives it scanlines.

const ASPECT := 0.8 # 256x240 shows at 4:3: squash x so the disc is round on the tube
const CENTRE := Vector2(128, 96)
var title := ""
## 0..1 while unpacking; negative while the console boots (length unknown).
var progress := -1.0
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 256, 240), Color("0b0f1a"))
	# A faint starfield of dots drifting left, like an old console's boot screen.
	for i in range(24):
		var x := fposmod(i * 53.0 - elapsed * (8.0 + i % 3 * 6.0), 256.0)
		draw_rect(Rect2(floorf(x), 8 + (i * 37) % 160, 1, 1), Color("3a4766") if i % 2 else Color("26304a"))
	draw_disc()
	var font := ThemeDB.fallback_font
	var dots := ".".repeat(1 + int(elapsed * 2.5) % 3)
	draw_string(font, Vector2(84, 168), "LOADING" + dots, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e9eef6"))
	var name := short_title(title)
	draw_string(font, Vector2(0, 186), name, HORIZONTAL_ALIGNMENT_CENTER, 256, 11, Color("8e9bb5"))
	draw_bar()

## The title without region and version tags, keeping the disc number, so
## "Final Fantasy VII (USA) (Disc 1)" fits as "Final Fantasy VII (Disc 1)".
static func short_title(text: String) -> String:
	var tags := RegEx.create_from_string(r"\s*\((?!(Disc|CD) )[^)]*\)")
	var shorter := tags.sub(text, "", true).strip_edges()
	if shorter.is_empty(): shorter = text
	return shorter if shorter.length() <= 30 else shorter.left(29) + "…"

## The disc seen face-on: a silver platter whose rainbow sheen turns with it.
func draw_disc() -> void:
	draw_set_transform(CENTRE, 0.0, Vector2(ASPECT, 1.0))
	var radius := 52.0
	var turn := elapsed * 4.2
	draw_circle(Vector2.ZERO, radius + 1.5, Color("1c2233"))
	var wedges := 24
	for i in range(wedges):
		var start := turn + TAU * i / wedges
		var shade := 0.62 + 0.22 * cos(2.0 * (start - turn) + 0.6)
		var colour := Color(shade, shade + 0.02, shade + 0.06)
		# Two opposite bands of iridescence, as light catches the pits.
		var band := fposmod(float(i), wedges / 2.0)
		if band < 4.0: colour = colour.lerp(Color.from_hsv(band / 4.0 * 0.8, 0.55, 1.0), 0.45)
		var points := PackedVector2Array([Vector2.from_angle(start) * 17.0])
		for step in range(4): points.append(Vector2.from_angle(start + TAU / wedges * step / 3.0) * radius)
		points.append(Vector2.from_angle(start + TAU / wedges) * 17.0)
		draw_colored_polygon(points, colour)
	# The clear inner ring, the label edge and the spindle hole.
	draw_circle(Vector2.ZERO, 17.0, Color("aab3c2"))
	draw_circle(Vector2.ZERO, 11.0, Color("d4dae4"))
	draw_circle(Vector2.ZERO, 5.5, Color("0b0f1a"))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color("f4f7fb"), 1.0)
	# A fixed glint, so the turning sheen reads as spin.
	draw_arc(Vector2.ZERO, radius - 6.0, -2.2, -1.6, 8, Color(1, 1, 1, 0.7), 2.0)
	draw_set_transform(Vector2.ZERO)

## Chunky segmented bar: filled to progress, or a block sweeping to and fro.
func draw_bar() -> void:
	var area := Rect2(48, 198, 160, 12)
	draw_rect(area, Color("8e9bb5"), false, 1.0)
	var segments := 20
	var width := (area.size.x - 4.0) / segments
	var lit := []
	if progress >= 0.0:
		for i in range(roundi(clampf(progress, 0.0, 1.0) * segments)): lit.append(i)
	else:
		var head := int(pingpong(elapsed * 14.0, segments - 3))
		lit = [head, head + 1, head + 2]
	for i in lit:
		draw_rect(Rect2(area.position.x + 2.0 + i * width, area.position.y + 2.0, width - 1.0, area.size.y - 4.0), Color("f2c14e"))
	if progress >= 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(0, 226), "%d%%" % roundi(progress * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 256, 11, Color("8e9bb5"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(0, 226), "STARTING DISC", HORIZONTAL_ALIGNMENT_CENTER, 256, 11, Color("8e9bb5"))
