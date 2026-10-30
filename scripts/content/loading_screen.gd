extends Node2D
## Original "please wait" card for disc games, shown on the TV while a disc
## unpacks and the console boots, in the menus' 16-bit style: a dithered night
## sky with a planet's lit limb, a CD spinning in perspective and a segmented
## amber bar, drawn at the test signal's 256x240. Its words are set sharp over
## it at three times the size by loading_text.gd, as the menus' are.
const SIZE := Vector2i(256, 240)
const ASPECT := 0.8 # 256x240 shows at 4:3: squash x so the disc is round on the tube
const CENTRE := Vector2(128, 108)
const RADIUS := 62.0
const AMBER := Color("f8c048")
const PLANET_CENTRE := Vector2(SIZE.x * 0.92, SIZE.y * 1.38)
const PLANET_RADIUS := SIZE.y * 0.72
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
var title := ""
## 0..1 while unpacking; negative while the console boots (length unknown).
var progress := -1.0
var elapsed := 0.0
var backdrop: ImageTexture

func _ready() -> void:
	backdrop = ImageTexture.create_from_image(sky())

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

static func q5(c: Color) -> Color:
	return Color(roundf(c.r * 31.0) / 31.0, roundf(c.g * 31.0) / 31.0, roundf(c.b * 31.0) / 31.0)

## A step of a ramp, dithered between neighbours by the Bayer matrix.
static func pick(ramp: Array, f: float, x: int, y: int) -> Color:
	f = clampf(f, 0.0, ramp.size() - 1.0)
	var base := floori(f)
	var step := base + (1 if f - base > (BAYER[(y % 4) * 4 + x % 4] + 0.5) / 16.0 else 0)
	return ramp[mini(step, ramp.size() - 1)]

## The still part of the card, made once: the night sky and the planet's limb.
static func sky() -> Image:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
	var night := ["000004", "000410", "000818", "04102c"].map(func(c): return q5(Color(c)))
	var sea := ["000818", "061848", "0c3890", "2068c8", "58a8e8", "c8e0f8"].map(func(c): return q5(Color(c)))
	var rim := q5(Color("4890c0"))
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var at := Vector2(x + 0.5, y + 0.5) / Vector2(SIZE)
			var colour: Color = pick(night, (1.0 - Vector2((at.x - 0.42) * 1.3, at.y - 0.3).length() * 1.5) * 3.0, x, y)
			var p := (Vector2(x, y) - PLANET_CENTRE) / PLANET_RADIUS
			var r2 := p.length_squared()
			if r2 < 1.0:
				var z := sqrt(1.0 - r2)
				var light := maxf(0.0, -0.55 * p.x - 0.75 * p.y + 0.37 * z) * 0.62
				var bands := sin(p.x * 9.0 + p.y * 23.0) * 0.5 + sin(p.x * 17.0 - p.y * 7.0) * 0.5
				var f := light * 4.0 + (maxf(0.0, bands - 0.4) * 2.5 * light if light > 0.04 else 0.0)
				colour = rim if r2 > 0.98 and light > 0.12 else pick(sea, f, x, y)
			image.set_pixel(x, y, colour)
	return image

func _draw() -> void:
	draw_texture(backdrop, Vector2.ZERO)
	# Stars drifting left a whole pixel at a time; none in front of the planet.
	for i in range(24):
		var x := floorf(fposmod(i * 53.0 - elapsed * (4.0 + i % 3 * 4.0), float(SIZE.x)))
		var y := float(6 + (i * 37) % 140)
		if (Vector2(x, y) - PLANET_CENTRE).length() < PLANET_RADIUS * 1.02: continue
		draw_rect(Rect2(x, y, 1, 1), Color("6878b0") if i % 2 else Color("283868"))
	draw_disc()
	draw_bar()
	# The words are drawn sharp over this by loading_text.gd.

## The title without region and version tags, keeping the disc number, so
## "Final Fantasy VII (USA) (Disc 1)" fits as "Final Fantasy VII (Disc 1)".
static func short_title(text: String) -> String:
	var tags := RegEx.create_from_string(r"\s*\((?!(Disc|CD) )[^)]*\)")
	var shorter := tags.sub(text, "", true).strip_edges()
	if shorter.is_empty(): shorter = text
	return shorter if shorter.length() <= 30 else shorter.left(29) + "…"

## The disc as the boot screens drew it: tipped back and spinning in
## perspective, its near edge showing as a thin rim over a soft shadow, and a
## rainbow sheen that turns with it.
const TILT := deg_to_rad(60.0)
## Distance to the eye in disc radii: smaller is stronger perspective.
const EYE := 4.0
const RIM := 3.0

## A point on the disc (x right, y away from you, in pixels) on the screen.
func project(point: Vector2) -> Vector2:
	var depth := -point.y * sin(TILT) / RADIUS
	var k := EYE / (EYE + depth)
	return CENTRE + Vector2(point.x * ASPECT, point.y * cos(TILT)) * k

## Points round the disc at `radius`. A whole circle leaves out its closing
## point: a repeated vertex makes the polygon fail to triangulate.
func ring(radius: float, from := 0.0, to := TAU, steps := 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	var whole := is_equal_approx(to - from, TAU)
	for i in range(steps if whole else steps + 1): points.append(project(Vector2.from_angle(lerpf(from, to, float(i) / steps)) * radius))
	return points

func draw_disc() -> void:
	var turn := elapsed * 4.2
	# A soft shadow on the ground under the disc, dithered at its edge.
	var shadow := ring(RADIUS * 1.02)
	for i in range(shadow.size()): shadow[i] += Vector2(4, 16)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	# The near edge: the rim traced again a pixel lower each line, down by the
	# disc's thickness. (A polygon strip folds where the edge turns vertical.)
	var edge := ring(RADIUS, 0.0, PI, 32)
	for depth in range(1, int(RIM) + 1):
		var line := PackedVector2Array(edge)
		for i in range(line.size()): line[i] += Vector2(0, depth)
		draw_polyline(line, q5(Color("50586c") if depth == int(RIM) else Color("8890a4")), 1.0)
	draw_polyline(edge, q5(Color("c8ced8")), 1.0)
	# The face: wedges of silver, two opposite bands of iridescence as light
	# catches the pits, both turning with the disc.
	var wedges := 24
	for i in range(wedges):
		var start := turn + TAU * i / wedges
		var shade := 0.62 + 0.22 * cos(2.0 * (start - turn) + 0.6)
		var colour := Color(shade, shade + 0.02, shade + 0.06)
		var bands := fposmod(float(i), wedges / 2.0)
		if bands < 4.0: colour = colour.lerp(Color.from_hsv(bands / 4.0 * 0.8, 0.55, 1.0), 0.45)
		# Light falls from above: the far half of the disc is a touch brighter.
		var middle := Vector2.from_angle(start + PI / wedges)
		colour = colour.lightened(clampf(-middle.y * 0.12, 0.0, 0.12))
		var points := PackedVector2Array([project(Vector2.from_angle(start) * 17.0)])
		for step in range(4): points.append(project(Vector2.from_angle(start + TAU / wedges * step / 3.0) * RADIUS))
		points.append(project(Vector2.from_angle(start + TAU / wedges) * 17.0))
		draw_colored_polygon(points, q5(colour))
	# The clear inner ring, the label edge and the spindle hole.
	draw_colored_polygon(ring(17.0), Color("aab3c2"))
	draw_colored_polygon(ring(11.0), Color("d4dae4"))
	draw_colored_polygon(ring(5.5), Color("000818"))
	var outline := ring(RADIUS); outline.append(outline[0])
	draw_polyline(outline, Color("f4f7fb"), 1.0)
	# A fixed glint on the far side, so the turning sheen reads as spin.
	draw_polyline(ring(RADIUS - 6.0, -2.2, -1.5, 8), Color(1, 1, 1, 0.75), 2.0)

## The menus' segmented bar: twenty equal segments in a recessed well, filled
## to progress, or a block sweeping to and fro while the console boots.
func draw_bar() -> void:
	var segments := 20
	var pitch := 8
	var width := pitch * segments + 3
	var area := Rect2(floorf((SIZE.x - width) * 0.5), 196, width, 12)
	draw_rect(area, Color("000818"))
	draw_rect(Rect2(area.position, Vector2(area.size.x, 1)), Color("000418"))
	draw_rect(Rect2(area.position, Vector2(1, area.size.y)), Color("000418"))
	draw_rect(Rect2(area.position.x, area.end.y - 1, area.size.x, 1), Color("3858a0"))
	draw_rect(Rect2(area.end.x - 1, area.position.y, 1, area.size.y), Color("3858a0"))
	var lit := []
	if progress >= 0.0:
		for i in range(roundi(clampf(progress, 0.0, 1.0) * segments)): lit.append(i)
	else:
		var head := int(pingpong(elapsed * 14.0, segments - 3))
		lit = [head, head + 1, head + 2]
	for i in range(segments):
		draw_rect(Rect2(area.position.x + 2 + i * pitch, area.position.y + 2, pitch - 1, area.size.y - 4), AMBER if i in lit else Color("0c1c48"))
