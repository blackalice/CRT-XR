extends Node3D
## A cheap diffuse area-source approximation, not a projection of the framebuffer.
## Two overlapping lights avoid a single bright hotspot; each takes the colour of
## its own half of the picture, so a red left side tints the left of the room.
## No live shadow maps, textures, extra receiver passes or GPU readback.
## Native PBR handles albedo and normals.
const RECEIVER_LAYER := 2
const Pipeline = preload("res://scripts/rendering/picture_pipeline.gd")
const SAMPLE_PERIOD := 1.0 / 20.0
const RESPONSE_SECONDS := 0.055
## Light at full glow for a picture of average radiance 1, in proportion to the
## picture's light as a real screen's is: a small logo on black lights the room
## faintly, a bright game picture clearly. (A softer curve lifted dark pictures
## until a green logo turned the whole set green.)
const GLOW_ENERGY := 16.0
## The bloom is steeper still: only bright pictures bloom.
const BLOOM_CURVE := 1.4
## Reach in metres (scaled with the set) and a soft falloff, like a large panel.
const GLOW_RANGE := 3.0
const GLOW_FALLOFF := 1.0
## How far each light leans towards its own half rather than the whole picture.
const SIDE_BIAS := 0.7
## How far ahead of the tube the lights sit (see _ready).
const LIGHT_DEPTH := 0.25
## The picture's light bounced back off the room: a faint fill in its colour
## on everything, the TV's own front included, added to the room's ambient.
const BOUNCE := 0.35
var lights: Array[OmniLight3D] = []
## 0 (off) to 1 (a dark room lit by the TV alone).
var strength := 0.5
## The soft bloom around the tube (shaders/screen_halo.gdshader), 0 to 1,
## already scaled down for a lit room; it shares this light's picture samples.
var halo: MeshInstance3D
var bloom := 0.0
## The room's own ambient light, before the bounce is added to it.
var room: Environment
var room_colour := Color.BLACK
var room_energy := 0.0
var power_level := 1.0
var grading: Dictionary = {}
var picture_area := 0.8
var calibration: Image
var source: Image
var target := Vector3.ZERO
var current := Vector3.ZERO
## Per light (left, right): the picture's halves, leaning towards each side.
var side_targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var side_current: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var elapsed := SAMPLE_PERIOD
var sample_count := 0
var sampling_usec := 0
var applied: Array[Vector3] = [-Vector3.ONE, -Vector3.ONE] # radiance last written to each light
var applied_scale := Vector3.ZERO # range scale, power level, strength last written
var applied_bloom := -1.0
var picture_dirty := true
var sampled_grading: Dictionary = {}
var sampled_area := -1.0

func _ready() -> void:
	name = "ScreenLight"
	calibration = Image.create(1,1,false,Image.FORMAT_RGBA8)
	calibration.fill(Color(.40,.44,.47))
	for x in [-0.34, 0.34]:
		var light := OmniLight3D.new()
		# Ahead of the tube, so the bezel and casing are lit evenly. On the
		# tube's face they hot-spotted the bezel's inner lip into a bright ring.
		# Deliberately no specular point highlight, which would expose this as
		# two tiny bulbs.
		light.position = Vector3(x, 0.035, LIGHT_DEPTH)
		light.omni_range = GLOW_RANGE
		light.omni_attenuation = GLOW_FALLOFF
		light.light_specular = 0.0
		light.light_cull_mask = RECEIVER_LAYER
		# Steam Deck long-session mitigation: avoid Compatibility's shadowed
		# light passes. Any nonzero glow could abruptly wash out the picture
		# and clock digits after play; zero glow removed it. Keep diffuse colour,
		# energy, reach and ambient bounce identical for the hardware comparison.
		light.shadow_enabled = false
		light.light_energy = 0.0
		add_child(light)
		lights.append(light)
	set_strength(strength)

func set_image(image: Image) -> void:
	# Retain the latest CPU frame by reference, including while the game is paused.
	source = image
	picture_dirty = true # The emulator reuses and mutates the same Image.
	elapsed = SAMPLE_PERIOD if image == null else elapsed

func set_strength(value: float) -> void:
	strength = clampf(value, 0.0, 1.0)
	if strength <= 0.0:
		for light in lights:
			light.light_energy = 0.0
			light.hide()
	_follow_picture()
	_show_bounce()

## The room's ambient light; the picture's bounce is added on top.
func set_room_ambient(colour: Color, energy: float) -> void:
	room_colour = colour; room_energy = energy
	_show_bounce()

func set_bloom(value: float) -> void:
	bloom = clampf(value, 0.0, 1.0)
	if halo != null and bloom <= 0.0: halo.hide()
	applied_bloom = -1.0
	_follow_picture()

## Samples the picture while the glow or the bloom needs it.
func _follow_picture() -> void:
	var needed := strength > 0.0 or bloom > 0.0
	set_process(needed)
	if not needed:
		current = Vector3.ZERO
		side_current = [Vector3.ZERO, Vector3.ZERO]
	else:
		elapsed = SAMPLE_PERIOD

static func average_radiance(image: Image, settings: Dictionary) -> Vector3:
	var halves := half_radiance(image, settings)
	return (halves[0] + halves[1]) * 0.5

## The left and right halves' average emitted light, from the same samples.
static func half_radiance(image: Image, settings: Dictionary) -> Array[Vector3]:
	# Stratified 16 x 12 samples: constant cost even for future larger consoles.
	# Grade each sample BEFORE averaging, in linear emitted-light space.
	var matrix := Pipeline.colour_basis_for(settings)
	var balance := Vector3(1.0 + settings.temperature * .08, 1.0, 1.0 - settings.temperature * .10)
	# Hoisted out of the 192-sample loop: dictionary lookups dominate GDScript cost.
	var contrast := float(settings.contrast)
	var gamma := float(settings.gamma)
	var brightness := float(settings.brightness)
	var width := image.get_width()
	var height := image.get_height()
	var totals: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	for y in range(12):
		for x in range(16):
			# Fixed jitter avoids locking every sample to the same SNES tile column.
			# Repeat within quadrants so equal-area colour swaps remain invariant.
			var jx := .15 + .7 * fmod((x%8)*.618034+(y%6)*.414214,1.0)
			var jy := .15 + .7 * fmod((y%6)*.754878+(x%8)*.569840,1.0)
			var pixel := image.get_pixel(mini(int((x+jx)*width/16.0),width-1),mini(int((y+jy)*height/12.0),height-1))
			var c := matrix * Vector3(pixel.r,pixel.g,pixel.b)
			c = ((c-Vector3.ONE*.5)*contrast+Vector3.ONE*.5).clamp(Vector3.ZERO,Vector3.ONE)*balance
			c = Vector3(pow(maxf(c.x,0),gamma),pow(maxf(c.y,0),gamma),pow(maxf(c.z,0),gamma))*brightness
			totals[0 if x < 8 else 1] += c.clamp(Vector3.ZERO,Vector3.ONE)
	return [totals[0] / 96.0, totals[1] / 96.0]

func _process(delta: float) -> void:
	if strength <= 0.0 and bloom <= 0.0: return
	elapsed += delta
	if elapsed >= SAMPLE_PERIOD and not grading.is_empty() and (picture_dirty or grading != sampled_grading or picture_area != sampled_area):
		elapsed = fmod(elapsed,SAMPLE_PERIOD)
		picture_dirty = false
		sampled_grading = grading.duplicate()
		sampled_area = picture_area
		var started := Time.get_ticks_usec()
		# The original test signal has a stable low average luminance. Avoid a
		# viewport readback just to animate its small moving calibration marker.
		var halves := half_radiance(source if source != null else calibration,grading)
		var area := clampf(picture_area,0.0,1.0)
		target = (halves[0] + halves[1]) * 0.5 * area
		for side in range(2): side_targets[side] = target.lerp(halves[side] * area, SIDE_BIAS)
		sampling_usec += Time.get_ticks_usec()-started
		sample_count += 1
	# Smooth in linear space, independently of frame rate, without delaying input.
	var follow := 1.0-exp(-minf(delta,.25)/RESPONSE_SECONDS)
	current = current.lerp(target,follow)
	for side in range(2): side_current[side] = side_current[side].lerp(side_targets[side],follow)
	var object_scale := global_transform.basis.get_scale().abs()
	var range_scale := maxf(object_scale.x,maxf(object_scale.y,object_scale.z))
	# The smoothing converges asymptotically; skip imperceptible light updates.
	var scales := Vector3(range_scale, power_level, strength)
	if (side_current[0] - applied[0]).length() + (side_current[1] - applied[1]).length() < 0.0005 and scales == applied_scale and bloom == applied_bloom: return
	applied = side_current.duplicate(); applied_scale = scales; applied_bloom = bloom
	_show_halo()
	_show_bounce()
	if strength <= 0.0: return
	for side in range(2):
		var light := lights[side]
		var radiance: Vector3 = side_current[side]
		var peak := maxf(radiance.x,maxf(radiance.y,radiance.z))
		light.visible = peak > .0001
		light.light_color = (Color(radiance.x,radiance.y,radiance.z) / maxf(peak,.00001)).linear_to_srgb()
		light.light_energy = glow_energy(peak) * strength * power_level
		# Range changes dirty the light's bounds/shadow state. Picture colour
		# changes do not change its reach; only write when the TV scale changes.
		var reach := GLOW_RANGE * range_scale
		if not is_equal_approx(light.omni_range, reach): light.omni_range = reach

## Light from a picture of this peak radiance at full glow.
static func glow_energy(peak: float) -> float:
	return GLOW_ENERGY * maxf(peak, 0.0)

## The bloom takes each half's colour. Its steeper curve keeps it for bright
## pictures: a dark scene barely blooms, a white or sky-blue one clearly does.
func _show_halo() -> void:
	if halo == null: return
	var level := bloom * power_level
	halo.visible = level > 0.001
	if not halo.visible: return
	var material := halo.material_override as ShaderMaterial
	material.set_shader_parameter("strength", level)
	for side in range(2):
		var radiance: Vector3 = side_current[side]
		var peak := maxf(radiance.x, maxf(radiance.y, radiance.z))
		var shaped := radiance / maxf(peak, 0.00001) * pow(peak, BLOOM_CURVE)
		material.set_shader_parameter("left_colour" if side == 0 else "right_colour", shaped)

func _show_bounce() -> void:
	if room == null: return
	var bounce := (side_current[0] + side_current[1]) * 0.5 * BOUNCE * strength * power_level
	var total := Vector3(room_colour.r, room_colour.g, room_colour.b) * room_energy + bounce
	var peak := maxf(total.x, maxf(total.y, total.z))
	room.ambient_light_energy = peak
	if peak > 0.0: room.ambient_light_color = Color(total.x / peak, total.y / peak, total.z / peak)
