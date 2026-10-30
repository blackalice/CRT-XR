extends SceneTree
## Drafts the menus' 16-bit icons from their vector drawings, as PNGs to keep
## or repaint by hand: each icon is drawn at its menu size, then sampled a
## 2×2-pixel cell at a time onto the menus' grid.
##   Row icons (row_icon.gd): 15×15, white on transparent; the menu tints them.
##   Console art (console_glyph.gd): 30×30, in 15-bit colour with a dark
##   one-cell outline, like a 16-bit sprite.
## The PNGs in assets/icons are the source of truth once made: edit them
## directly. Rerunning this drafts only icons that have no PNG yet, so hand-made
## and repainted ones are kept; delete a PNG to draft it again.
## Run: godot --path . --script scripts/make-pixel-icons.gd (not headless).
const RowIcon = preload("res://scripts/ui/row_icon.gd")
const ConsoleGlyph = preload("res://scripts/ui/console_glyph.gd")
const ROWS := ["folder", "album", "up", "cartridge", "video", "music", "drive", "sd", "home", "network", "disc",
	"refresh", "edit", "clear", "check", "search", "page", "play", "save", "load", "camera", "gear", "sliders",
	"exit", "stop", "lamp", "glasses"]
## Console art and the accent each card draws it with (menu_games.gd).
const CONSOLES := {"snes": "ba9fdb", "nes": "dc9b8e", "megadrive": "8ebfdc", "mastersystem": "9ac4ab",
	"gamegear": "d4bb7d", "gameboy": "b7bfa8", "gba": "b0a6e8", "pcengine": "e0908a", "segacd": "7fb6dd",
	"atari2600": "e0a75f", "atarilynx": "cf8560", "ngpc": "c4a8d8", "vectrex": "8fc4c9", "psx": "a9b6cf",
	"n64": "8fcf9a", "recent": "f8c048", "favourites": "f8c048", "locations": "f8c048", "videos": "f8c048"}
const OUTLINE := Color("000418")

func _initialize() -> void: call_deferred("run")

func render(control: Control, size: int) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(size, size)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	control.size = Vector2(size, size)
	view.add_child(control)
	for i in range(3): await process_frame
	RenderingServer.force_draw(false)
	var image := view.get_texture().get_image()
	view.queue_free()
	return image

## One cell of the grid: its 2×2 pixels averaged; solid if mostly covered.
static func cell(image: Image, x: int, y: int) -> Color:
	var sum := Color(0, 0, 0, 0)
	for j in range(2):
		for i in range(2): sum += image.get_pixel(x * 2 + i, y * 2 + j)
	return sum / 4.0

static func q5(c: Color) -> Color:
	return Color(roundf(c.r * 31.0) / 31.0, roundf(c.g * 31.0) / 31.0, roundf(c.b * 31.0) / 31.0, 1.0)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons/menu"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons/consoles"))
	for kind in ROWS:
		if FileAccess.file_exists("res://assets/icons/menu/%s.png" % kind): continue
		var drawn := await render(RowIcon.new(kind, Color.WHITE), 30)
		var icon := Image.create(15, 15, false, Image.FORMAT_RGBA8)
		for y in range(15):
			for x in range(15):
				# Details are cut out in a dark ink: only the bright parts are the icon.
				var c := cell(drawn, x, y)
				if c.a >= 0.5 and c.get_luminance() / c.a >= 0.5: icon.set_pixel(x, y, Color.WHITE)
		icon.save_png("res://assets/icons/menu/%s.png" % kind)
		print("row icon ", kind)
	for kind in CONSOLES:
		if FileAccess.file_exists("res://assets/icons/consoles/%s.png" % kind): continue
		var glyph := ConsoleGlyph.new()
		glyph.kind = kind
		glyph.accent = Color(CONSOLES[kind])
		var drawn := await render(glyph, 60)
		var sprite := Image.create(30, 30, false, Image.FORMAT_RGBA8)
		for y in range(30):
			for x in range(30):
				var c := cell(drawn, x, y)
				# Colour is premultiplied by coverage at the edges; undo that.
				if c.a >= 0.5: sprite.set_pixel(x, y, q5(Color(c.r / c.a, c.g / c.a, c.b / c.a)))
		var outlined := sprite.duplicate()
		for y in range(30):
			for x in range(30):
				if sprite.get_pixel(x, y).a > 0.0: continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = Vector2i(x, y) + d
					if n.x >= 0 and n.y >= 0 and n.x < 30 and n.y < 30 and sprite.get_pixel(n.x, n.y).a > 0.0:
						outlined.set_pixel(x, y, OUTLINE); break
		outlined.save_png("res://assets/icons/consoles/%s.png" % kind)
		print("console art ", kind)
	quit()
