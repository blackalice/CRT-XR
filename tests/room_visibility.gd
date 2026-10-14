extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	app.provider.enabled = false
	app.provider.angles = Vector3.ZERO
	app.displayed = Quaternion.IDENTITY
	app.center = Quaternion.IDENTITY
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = app.views[0].get_texture().get_image()
	var visible := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).get_luminance() > 0.02:
				visible += 1
	print("Room visibility: viewport=", image.get_size(), " visible samples=", visible,
		" camera=", app.eyes[0].global_position, " television=", app.world.television.global_position)
	if visible < 100:
		push_error("3D scene is black or missing")
	quit(0 if visible >= 100 else 1)
