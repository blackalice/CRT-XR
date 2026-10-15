extends SceneTree
# Measures real scene/stereo lighting cost locally without capturing the model.
var app
func _initialize(): call_deferred("run")
func phase(strength: float) -> Dictionary:
	app.world.set_spill_strength(strength)
	for i in range(45): await process_frame
	var gpu: Array[float] = []
	var wall: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append((now-last)/1000.0)
		last = now
		var total := 0.0
		for view in app.views: total += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
		gpu.append(total)
	wall.sort()
	gpu.sort()
	return {"strength":strength,"gpu_ms":gpu[90],"gpu_p95_ms":gpu[171],"wall_ms":wall[90],"wall_p95_ms":wall[171]}
func run():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var stage := SubViewport.new()
	stage.size = Vector2i(3840,1080)
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	app = load("res://scenes/main.tscn").instantiate()
	stage.add_child(app)
	app.close_settings()
	app.use_tracking(false)
	app.set_stereo(true)
	app.vertical_fov = 24
	app.distance = 1.2
	for i in range(30): await process_frame
	for view in app.views: RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	print("SCREEN_LIGHT_BENCH eye_size=",app.views[0].size," distance=",app.distance)
	for strength in [0.0,.1,0.0,.1]: print("SCREEN_LIGHT_BENCH ",JSON.stringify(await phase(strength)))
	app.distance_save_delay = -1
	app.free()
	stage.free()
	quit()
