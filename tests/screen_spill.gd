extends SceneTree
# All geometry/content in this fixture is original; never loads the licensed CRT.
const Light = preload("res://scripts/rendering/screen_light.gd")
var failures := 0
var light: Node3D
var view: SubViewport
var camera: Camera3D
var patch: MeshInstance3D
var material: StandardMaterial3D
var settings := {"hue":0.0,"saturation":1.0,"gamma":2.25,"brightness":1.0,"contrast":1.0,"temperature":0.0}
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1
func image(colour: Color) -> Image:
	var result := Image.create(256,240,false,Image.FORMAT_RGBA8)
	result.fill(colour)
	return result
func settle(colour: Color) -> Color:
	light.set_image(image(colour))
	for i in range(30): light._process(1.0/30.0)
	for i in range(3): await process_frame
	RenderingServer.force_draw(false)
	return view.get_texture().get_image().get_pixel(128,128)
func make_box(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.layers = Light.RECEIVER_LAYER
	var surface := StandardMaterial3D.new()
	surface.albedo_color = colour
	surface.roughness = .85
	node.material_override = surface
	view.add_child(node)
	return node
func run():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	view = SubViewport.new()
	view.size = Vector2i(256,256)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0
	view.add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = .3
	camera.position = Vector3(.72,0,2)
	view.add_child(camera)
	patch = MeshInstance3D.new()
	patch.mesh = QuadMesh.new()
	patch.position = Vector3(.72,0,.06)
	patch.layers = Light.RECEIVER_LAYER
	material = StandardMaterial3D.new()
	material.albedo_color = Color(.3,.3,.3)
	material.roughness = .85
	patch.material_override = material
	view.add_child(patch)
	light = Light.new()
	view.add_child(light)
	light.set_process(false)
	light.grading = settings
	light.picture_area = 1
	var black := await settle(Color.BLACK)
	check(maxf(black.r,maxf(black.g,black.b)) < .01,"Black frame emits no screen light")
	var blue := await settle(Color.BLUE)
	check(blue.b > .03 and blue.r < .01 and blue.g < .01,"Native light casts picture colour onto a lit material")
	material.albedo_color = Color(.03,.03,.03)
	var dark := await settle(Color.BLUE)
	check(dark.b < blue.b * .6,"Dark plastic reflects less light instead of receiving an additive image")
	material.albedo_color = Color(.3,.3,.3)
	var half := image(Color.RED)
	half.fill_rect(Rect2i(128,0,128,240),Color.BLUE)
	var average_a := Light.average_radiance(half,settings)
	half.fill(Color.BLUE)
	half.fill_rect(Rect2i(128,0,128,240),Color.RED)
	check(average_a.is_equal_approx(Light.average_radiance(half,settings)),"Swapping picture halves cannot project or duplicate image detail")
	check(average_a.is_equal_approx(Vector3(.5,0,.5)),"Emitted colour averages linear light without normalising dark frames to white")
	half.fill(Color.RED); half.fill_rect(Rect2i(128,0,128,240),Color.BLUE)
	var sides: Array[Vector3] = Light.half_radiance(half,settings)
	check(sides[0].x > .99 and sides[0].z < .01 and sides[1].z > .99 and sides[1].x < .01,"Each light sees its own half: red left, blue right")
	check(Light.glow_energy(0.0) == 0.0 and Light.glow_energy(0.5) < Light.glow_energy(0.1) * 5.0 * 0.7,"Dark stays dark, and a white screen doesn't flare (soft curve)")
	var dim := Light.average_radiance(image(Color(.5,.5,.5)),settings)
	check(dim.x < .23 and dim.x > .20,"Display gamma is applied before light averaging")
	settings.brightness = .5
	check(Light.average_radiance(image(Color.WHITE),settings).is_equal_approx(Vector3.ONE*.5),"Picture brightness also controls emitted light")
	settings.brightness = 1
	patch.layers = 1
	var excluded := await settle(Color.WHITE)
	check(excluded.r < .01,"Receiver mask excludes picture, glass and unrelated geometry")
	patch.layers = Light.RECEIVER_LAYER
	patch.position.x = 4.5
	camera.position.x = 4.5
	var distant := await settle(Color.WHITE)
	check(distant.r < .01,"Light stays local to the TV")
	patch.position = Vector3(.72,0,.06)
	camera.position.x = .72
	light.set_strength(0)
	var count: int = light.sample_count
	light._process(.2)
	var off := await settle(Color.WHITE)
	check(off.r < .01 and light.sample_count == count and not light.lights[0].visible,"Off hides lights immediately and stops sampling")
	light.set_strength(.1)
	light.set_process(false)
	check(light.lights.size() == 2 and not light.lights[0].shadow_enabled and light.lights[0].light_specular == 0,"Bounded two-light approximation avoids shadow maps and point reflections")
	light.set_image(image(Color.WHITE))
	light.current = Vector3.ZERO
	for i in range(30): light._process(1.0/60.0)
	var at_60: Vector3 = light.current
	light.current = Vector3.ZERO
	for i in range(15): light._process(1.0/30.0)
	check(at_60.is_equal_approx(light.current),"Light response is independent of rendering frame rate")
	settings.brightness = .5
	for i in range(30): light._process(1.0/30.0)
	check(absf(light.current.x-.5)<.001,"Paused image responds to grading without uploading another frame")
	settings.brightness = 1
	light.scale = Vector3.ONE*1.5
	light._process(0)
	check(is_equal_approx(light.lights[0].omni_range,Light.GLOW_RANGE*1.5),"Light reach follows the virtual TV scale")
	light.scale = Vector3.ONE
	# Performance of sampling only: no rendering/readback included.
	var source := image(Color(.4,.6,.8))
	var started := Time.get_ticks_usec()
	for i in range(100): Light.average_radiance(source,settings)
	print("SCREEN_LIGHT_CPU sample_ms=",(Time.get_ticks_usec()-started)/100000.0," samples=192 rate_hz=20")
	# Synthetic preview for visual review, using original primitive geometry only.
	patch.hide()
	view.size = Vector2i(640,480)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48
	camera.position = Vector3(1.5,.65,2.9)
	camera.look_at(Vector3(0,-.15,0))
	make_box(Vector3(.18,1.32,.25),Vector3(-.82,0,-.08),Color(.14,.15,.16))
	make_box(Vector3(.18,1.32,.25),Vector3(.68,0,-.08),Color(.14,.15,.16))
	make_box(Vector3(1.32,.15,.25),Vector3(-.07,.58,-.08),Color(.14,.15,.16))
	make_box(Vector3(1.32,.19,.25),Vector3(-.07,-.58,-.08),Color(.14,.15,.16))
	make_box(Vector3(2,.09,.95),Vector3(0,-.76,.15),Color(.42,.27,.15))
	make_box(Vector3(.1,.4,.1),Vector3(-.8,-1,.4),Color(.3,.19,.1))
	make_box(Vector3(.1,.4,.1),Vector3(.8,-1,.4),Color(.3,.19,.1))
	var screen := make_box(Vector3(1.32,.99,.025),Vector3(-.07,.035,.06),Color(.16,.3,.6))
	var screen_mat := screen.material_override as StandardMaterial3D
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.layers = 1
	environment.environment.ambient_light_color = Color(.5,.6,.7)
	environment.environment.ambient_light_energy = .12
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/screen-light"))
	for power in [0.0,.1,.4]:
		light.set_strength(power)
		light.set_process(false)
		await settle(Color(.35,.6,1))
		view.get_texture().get_image().save_png("res://build/screen-light/synthetic-%s.png" % power)
	view.free()
	quit(1 if failures else 0)
