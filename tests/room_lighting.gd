extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(128, 128)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1.0
	view.add_child(environment)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.current = true
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(40, 40)
	plane.mesh = mesh
	plane.rotation.x = PI / 2.0
	plane.position.z = -3.0
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/room_floor.gdshader")
	plane.material_override = material
	view.add_child(plane)
	await process_frame
	await RenderingServer.frame_post_draw
	var near_color := view.get_texture().get_image().get_pixel(64, 64)
	plane.position.z = -13.0
	await process_frame
	await RenderingServer.frame_post_draw
	var far_color := view.get_texture().get_image().get_pixel(64, 64)
	var passed := near_color.get_luminance() > 0.01 and far_color.get_luminance() < 0.003
	if passed:
		print("PASS: Lit nearby floor fades to black beyond the distance limit")
	else:
		push_error("Floor fade pixel check failed: near=%s far=%s" % [near_color, far_color])
	# Check the same fade on opaque PBR objects, independently of the CRT asset.
	plane.material_override = StandardMaterial3D.new()
	plane.material_override.albedo_color = Color.WHITE
	plane.material_overlay = ShaderMaterial.new()
	plane.material_overlay.shader = load("res://shaders/distance_black.gdshader")
	plane.position.z = -3.0
	await process_frame
	await RenderingServer.frame_post_draw
	near_color = view.get_texture().get_image().get_pixel(64, 64)
	plane.position.z = -13.0
	await process_frame
	await RenderingServer.frame_post_draw
	far_color = view.get_texture().get_image().get_pixel(64, 64)
	var overlay_passed := near_color.get_luminance() > 0.1 and far_color.get_luminance() < 0.003
	if overlay_passed:
		print("PASS: PBR object overlay preserves nearby lighting and blacks out distant geometry")
	else:
		push_error("Object fade pixel check failed: near=%s far=%s" % [near_color, far_color])
	quit(0 if passed and overlay_passed else 1)
