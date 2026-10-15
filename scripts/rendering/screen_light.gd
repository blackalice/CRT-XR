extends Node3D
## A cheap diffuse area-source approximation, not a projection of the framebuffer.
## Two overlapping lights avoid a single bright hotspot. No shadows, textures,
## extra receiver passes or GPU readback; native PBR handles albedo and normals.
const RECEIVER_LAYER := 2
const Pipeline = preload("res://scripts/rendering/picture_pipeline.gd")
const SAMPLE_PERIOD := 1.0 / 20.0
const RESPONSE_SECONDS := 0.055
var lights: Array[OmniLight3D] = []
var strength := 0.10
var power_level := 1.0
var grading: Dictionary = {}
var picture_area := 0.8
var calibration: Image
var source: Image
var target := Vector3.ZERO
var current := Vector3.ZERO
var elapsed := SAMPLE_PERIOD
var sample_count := 0
var sampling_usec := 0

func _ready() -> void:
	name = "ScreenLight"
	calibration = Image.create(1,1,false,Image.FORMAT_RGBA8)
	calibration.fill(Color(.40,.44,.47))
	for x in [-0.34, 0.34]:
		var light := OmniLight3D.new()
		# Slightly ahead of the faceplate: approximates the curved emitting tube
		# and its diffuse bounce into the inset bezel. Deliberately no specular
		# point highlight, which would expose this as two tiny bulbs.
		light.position = Vector3(x, 0.035, 0.30)
		light.omni_range = 1.65
		light.omni_attenuation = 2.0
		light.light_specular = 0.0
		light.light_cull_mask = RECEIVER_LAYER
		light.shadow_enabled = false
		light.light_energy = 0.0
		add_child(light)
		lights.append(light)
	set_strength(strength)

func set_image(image: Image) -> void:
	# Retain the latest CPU frame by reference, including while the game is paused.
	source = image
	elapsed = SAMPLE_PERIOD if image == null else elapsed

func set_strength(value: float) -> void:
	strength = clampf(value, 0.0, 0.4)
	set_process(strength > 0.0)
	if strength <= 0.0:
		current = Vector3.ZERO
		for light in lights:
			light.light_energy = 0.0
			light.hide()
	else:
		elapsed = SAMPLE_PERIOD

static func average_radiance(image: Image, settings: Dictionary) -> Vector3:
	# Stratified 16 x 12 samples: constant cost even for future larger consoles.
	# Grade each sample BEFORE averaging, in linear emitted-light space.
	var matrix := Pipeline.colour_basis_for(settings)
	var balance := Vector3(1.0 + settings.temperature * .08, 1.0, 1.0 - settings.temperature * .10)
	var total := Vector3.ZERO
	for y in range(12):
		for x in range(16):
			# Fixed jitter avoids locking every sample to the same SNES tile column.
			# Repeat within quadrants so equal-area colour swaps remain invariant.
			var jx := .15 + .7 * fmod((x%8)*.618034+(y%6)*.414214,1.0)
			var jy := .15 + .7 * fmod((y%6)*.754878+(x%8)*.569840,1.0)
			var pixel := image.get_pixel(mini(int((x+jx)*image.get_width()/16.0),image.get_width()-1),
				mini(int((y+jy)*image.get_height()/12.0),image.get_height()-1))
			var c := matrix * Vector3(pixel.r,pixel.g,pixel.b)
			c = ((c-Vector3.ONE*.5)*float(settings.contrast)+Vector3.ONE*.5).clamp(Vector3.ZERO,Vector3.ONE)*balance
			c = Vector3(pow(maxf(c.x,0),settings.gamma),pow(maxf(c.y,0),settings.gamma),pow(maxf(c.z,0),settings.gamma))*float(settings.brightness)
			total += c.clamp(Vector3.ZERO,Vector3.ONE)
	return total / 192.0

func _process(delta: float) -> void:
	if strength <= 0.0: return
	elapsed += delta
	if elapsed >= SAMPLE_PERIOD and not grading.is_empty():
		elapsed = fmod(elapsed,SAMPLE_PERIOD)
		var started := Time.get_ticks_usec()
		# The original test signal has a stable low average luminance. Avoid a
		# viewport readback just to animate its small moving calibration marker.
		target = average_radiance(source if source != null else calibration,grading)
		target *= clampf(picture_area,0.0,1.0)
		sampling_usec += Time.get_ticks_usec()-started
		sample_count += 1
	# Smooth in linear space, independently of frame rate, without delaying input.
	current = current.lerp(target,1.0-exp(-minf(delta,.25)/RESPONSE_SECONDS))
	var peak := maxf(current.x,maxf(current.y,current.z))
	var colour := Color(current.x,current.y,current.z) / maxf(peak,.00001)
	var object_scale := global_transform.basis.get_scale().abs()
	var range_scale := maxf(object_scale.x,maxf(object_scale.y,object_scale.z))
	for light in lights:
		light.visible = peak > .0001
		light.light_color = colour.linear_to_srgb()
		light.light_energy = peak * strength * 8.0 * power_level
		light.omni_range = 1.65 * range_scale
