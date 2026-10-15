extends SceneTree
## Run with a GPU renderer. Checks the actual composited image in both eyes.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.close_settings()
	app.use_tracking(false)
	app.set_stereo(true)
	app.edge_fade = 0.075
	app.fade_material.set_shader_parameter("fade_width", 0.075)
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var width := image.get_width()
	var height := image.get_height()
	var failures := 0
	for eye in range(2):
		var start := eye * width / 2
		for point in [Vector2i(start, height / 2), Vector2i(start + width / 2 - 1, height / 2), Vector2i(start + width / 4, 0), Vector2i(start + width / 4, height - 1)]:
			var color := image.get_pixelv(point)
			if maxf(color.r, maxf(color.g, color.b)) > 0.025:
				push_error("Eye boundary is not black at " + str(point))
				failures += 1
		var center := image.get_pixel(start + width / 4, height / 2)
		if maxf(center.r, maxf(center.g, center.b)) < 0.05:
			push_error("Eye center was obscured by the fade")
			failures += 1
	image.save_png(ProjectSettings.globalize_path("res://build/edge-fade-preview.png"))
	print("Per-eye rendered fade checks: ", failures, " failures")
	quit(1 if failures else 0)
