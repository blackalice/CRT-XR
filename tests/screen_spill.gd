extends SceneTree
var failures := 0
var view: SubViewport
var camera: Camera3D
var patch: MeshInstance3D
var spill: ShaderMaterial
var texture: ImageTexture
var average: SubViewport
func check(ok: bool, message: String):
	if ok: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func _initialize(): call_deferred("run")
func pixel(color: Color) -> Color:
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(color)
	texture.update(image)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image().get_pixel(64,64)
func run():
	view = SubViewport.new()
	view.size = Vector2i(128,128)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = .15
	camera.position = Vector3(.68,0,2)
	view.add_child(camera)
	patch = MeshInstance3D.new()
	patch.mesh = QuadMesh.new()
	patch.mesh.size = Vector2(.18,.18)
	patch.position = Vector3(.68,0,.06)
	var base := StandardMaterial3D.new()
	base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base.albedo_color = Color(.03,.03,.03)
	patch.material_override = base
	spill = ShaderMaterial.new()
	spill.shader = load("res://shaders/screen_spill.gdshader")
	spill.set_shader_parameter("world_to_tv", Transform3D.IDENTITY)
	var fade := ShaderMaterial.new()
	fade.shader = load("res://shaders/distance_black.gdshader")
	fade.render_priority = 1
	spill.next_pass = fade
	patch.material_overlay = spill
	view.add_child(patch)
	var image := Image.create(16,16,false,Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(image)
	average = load("res://scripts/rendering/screen_spill_average.gd").new()
	root.add_child(average)
	average.set_signal(texture)
	spill.set_shader_parameter("average_texture",average.get_texture())
	spill.set_shader_parameter("strength",0.0)
	var off := await pixel(Color.WHITE)
	spill.set_shader_parameter("strength",.1)
	var black := await pixel(Color.BLACK)
	check(off.is_equal_approx(black), "Black screen produces no light spill")
	var blue := await pixel(Color.BLUE)
	check(blue.b > black.b + .02 and absf(blue.r-black.r) < .01, "Blue picture adds blue light to nearby bezel")
	check(blue.b - black.b < .16, "Default light spill stays subtle")
	var red := await pixel(Color.RED)
	check(red.r > black.r + .02 and absf(red.b-black.b) < .01, "Changing picture changes spill colour")
	# Swapping the two halves changes the picture completely, but its mean stays
	# identical. The old projected-picture implementation fails this regression.
	image.fill(Color.RED)
	image.fill_rect(Rect2i(8,0,8,16), Color.BLUE)
	texture.update(image)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var split_a := view.get_texture().get_image().get_pixel(64,64)
	image.fill(Color.BLUE)
	image.fill_rect(Rect2i(8,0,8,16), Color.RED)
	texture.update(image)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var split_b := view.get_texture().get_image().get_pixel(64,64)
	check(split_a.is_equal_approx(split_b) and split_a.r > black.r + .01 and split_a.b > black.b + .01,
		"Moving high-contrast picture detail cannot project onto the cabinet")
	patch.position.x = 1.2
	camera.position.x = 1.2
	var distant := await pixel(Color.WHITE)
	check(distant.is_equal_approx(off), "Spill falls away from screen edges")
	patch.position = Vector3(.68,0,-.3)
	camera.position.x = .68
	var rear := await pixel(Color.WHITE)
	check(rear.is_equal_approx(off), "No light leaks onto rear cabinet surfaces")
	patch.position.z = .06
	camera.position.z = 14
	var far := await pixel(Color.WHITE)
	check(far.get_luminance() < .003, "Distance fade blacks out base and added spill together")
	camera.position.z = 2
	spill.set_shader_parameter("strength", 0.0)
	var disabled := await pixel(Color.BLUE)
	check(disabled.is_equal_approx(off), "Zero strength fully disables the effect")
	quit(1 if failures else 0)

