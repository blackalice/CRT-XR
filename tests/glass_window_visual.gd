extends SceneTree

var failures := 0

func _initialize():
	call_deferred("run")

func check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func sample(image: Image, camera: Camera3D, direction: Vector2) -> float:
	var ray := Vector3(direction.x, direction.y, sqrt(1.0 - direction.length_squared()))
	var point := camera.unproject_position(ray * (2.0 / ray.z) * Vector3(1, 1, -1))
	var sum := 0.0
	for y in range(-1, 2):
		for x in range(-1, 2):
			sum += image.get_pixel(int(point.x) + x, int(point.y) + y).r
	return sum / 9.0

func run():
	# Original synthetic geometry only; excludes the licensed TV and its textures.
	RenderingServer.set_default_clear_color(Color.BLACK)
	var view := SubViewport.new()
	view.size = Vector2i(800, 600)
	view.world_3d = World3D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.fov = 75
	view.add_child(camera)
	camera.current = true
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(5, 4)
	quad.mesh = mesh
	quad.position.z = -2
	view.add_child(quad)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/crt_glass.gdshader")
	material.set_shader_parameter("reflection_strength", 0.4)
	quad.material_override = material
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://build/glass-review")
	image.save_png("res://build/glass-review/window.png")
	var centre := Vector2(-0.42, 0.38)
	var cross := sample(image, camera, centre)
	var pane := sample(image, camera, centre + Vector2(0.08, 0.10))
	check(pane > cross + 0.04, "Window cross should be visibly dimmer than a pane")
	for offset in [Vector2(-0.08, -0.10), Vector2(0.08, -0.10), Vector2(-0.08, 0.10)]:
		check(sample(image, camera, centre + offset) > cross + 0.03, "All four panes should reflect light")
	for offset in [Vector2(0.08, 0), Vector2(0, 0.10)]:
		check(sample(image, camera, centre + offset) < pane * 0.6, "Both mullions should interrupt the reflection")
	material.set_shader_parameter("reflection_strength", 0.0)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	check(sample(view.get_texture().get_image(), camera, centre + Vector2(0.08, 0.10)) < 0.001, "Zero strength should remove reflections")
	print("GLASS WINDOW VISUAL: cross=", cross, " pane=", pane, " failures=", failures)
	view.free()
	quit(1 if failures else 0)
