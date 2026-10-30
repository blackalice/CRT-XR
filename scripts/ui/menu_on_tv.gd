extends Node
## Shows the menu on the TV itself, as consoles did: the tube switches to the
## menu like changing to another input, with a picture made for reading (RGB,
## a sharp beam, light scanlines and mask, little glass or curve), and the TV
## eases in until the tube nearly fills the view. Closing the menu puts the
## programme, your picture settings and the view back; nothing is saved from
## the menu's picture. The preview strip, used to judge the picture against a
## game, keeps the floating menu.
const LEAN_SECONDS := 0.35
## The menu's tube: lighter than any picture preset, so small text stays clear.
const TUBE := {"scanlines": 0.18, "mask": 0.08, "glow": 0.08, "glass": 0.06, "curvature": 0.25}
const BEAM := {"beam_softness": 7.0, "vignette": 0.02}
## The tube's half-height for a TV scale of 1, in metres; the lean brings it to
## about 80% of the view's height, leaving the cabinet's edge in sight.
const TUBE_HALF_HEIGHT := 0.42
const FILL := 0.8
## Frames after the menu reaches the tube before the room's light samples it:
## the menu has drawn its first page by then.
const LIGHT_DELAY := 4
var host: Node
var active := false
## 0 at the TV's own place, 1 leaned in for the menu.
var lean := 0.0
var saved := {}
var light_countdown := -1

func wanted() -> bool:
	return host.menu_on_tv and host.settings_panel.visible and not host.menu.preview and is_instance_valid(host.world)

## Called by main at the start of its frame, before it decides what floats:
## run on its own, this caught up a frame late and the floating menu flashed
## up full size for one frame as the menu opened.
func update(delta: float) -> void:
	var want := wanted()
	if want and not active: enter()
	elif active and not want: leave()
	elif active and host.world.picture.source_texture != menu_texture(): adopt()
	if active and light_countdown >= 0:
		light_countdown -= 1
		if light_countdown < 0: light_from_menu()
	var target := 1.0 if active else 0.0
	lean = target if host.menu_reduced_motion else move_toward(lean, target, delta / LEAN_SECONDS)

func menu_texture() -> Texture2D:
	return host.menu_view.get_texture()

## Where the TV sits: at `base`, or eased in and centred while the menu is on it.
func lean_position(base: Vector3) -> Vector3:
	if lean <= 0.0: return base
	var vertical := tan(deg_to_rad(float(host.vertical_fov)) * 0.5)
	var near := clampf(TUBE_HALF_HEIGHT * float(host.tv_scale) / (vertical * FILL), 0.8, -base.z)
	return base.lerp(Vector3(0.0, 1.25, -near), lean * lean * (3.0 - 2.0 * lean))

func enter() -> void:
	active = true
	var picture: Node = host.world.picture
	saved = {"mode": picture.mode, "values": picture.values.duplicate(), "keep_aspect": picture.keep_aspect,
		"light": host.world.screen_light.source}
	light_countdown = LIGHT_DELAY
	remember_programme()
	picture.mode = 0
	picture.keep_aspect = true
	for key in BEAM: picture.values[key] = BEAM[key]
	for key in ["width", "height"]: picture.values[key] = 1.0
	for key in ["shift_x", "shift_y"]: picture.values[key] = 0.0
	show_menu()
	tube(TUBE.scanlines, TUBE.mask, TUBE.glow, TUBE.glass, minf(float(host.screen_curvature), TUBE.curvature))
	# At startup the menu opens before the TV's warm-up, which waited for the
	# menu to close: on the TV, the menu sat on a dark tube. Switch it on now,
	# so the menu appears with the tube.
	if not host.power_on.started and not is_instance_valid(host.get("sbs_prompt")): host.power_on.begin()

## A game or video started while the menu was up: return to that instead.
func adopt() -> void:
	remember_programme()
	show_menu()

func remember_programme() -> void:
	var picture: Node = host.world.picture
	saved.texture = picture.source_texture
	saved.driven = picture.frame_driven
	saved.rate = picture.source_rate
	saved.aspect = picture.source_aspect

func show_menu() -> void:
	var picture: Node = host.world.picture
	picture.source_rate = 60.0
	picture.source_aspect = 4.0 / 3.0
	picture.set_source(menu_texture())

func leave() -> void:
	active = false
	var picture: Node = host.world.picture
	picture.mode = saved.mode
	picture.values = saved.values
	picture.keep_aspect = saved.keep_aspect
	# Choosing a game loads it (the loading card or its picture takes the tube)
	# and closes the menu in the same frame, before update() can adopt it. Put
	# the old programme back only if nothing has replaced the menu since:
	# restoring it then froze the last game's final frame over the new one.
	if picture.source_texture == menu_texture():
		picture.source_rate = saved.rate
		picture.source_aspect = saved.aspect
		picture.set_source(saved.texture, saved.driven)
		host.world.screen_light.set_image(saved.light)
	else: picture.refresh()
	tube(host.scanlines, host.phosphor_mask, host.phosphor_glow, host.glass_reflections, host.screen_curvature)

## The room is lit by what the tube shows, so it takes its light from the menu.
## One small snapshot is enough: the menu's colours hardly change between pages,
## and reading the menu back every frame would cost the Deck too much.
func light_from_menu() -> void:
	var image := menu_texture().get_image()
	if image == null: return
	image.resize(48, 36, Image.INTERPOLATE_BILINEAR)
	host.world.screen_light.set_image(image)

## Frames from a game or video light the room only while they are on the tube.
func lights_room() -> bool:
	return not active

func tube(scanlines: float, mask: float, glow: float, glass: float, curvature: float) -> void:
	var world: Node = host.world
	world.screen_material.set_shader_parameter("scanlines", scanlines)
	world.screen_material.set_shader_parameter("mask_strength", mask)
	world.screen_material.set_shader_parameter("glow_strength", glow)
	world.glass_material.set_shader_parameter("reflection_strength", glass)
	world.set_curvature(curvature)
