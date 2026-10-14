extends SceneTree
func _initialize(): call_deferred("run")
func phase(world, strength: float):
	world.set_spill_strength(strength)
	for i in range(45): await process_frame
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-last)/1000.0)
		last = now
	var mean := 0.0
	for sample in samples: mean += sample/180.0
	samples.sort()
	return {"strength":strength, "mean_ms":mean, "p95_ms":samples[171]}
func run():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var view := SubViewport.new()
	view.size = Vector2i(3840,1080)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var app = load("res://scenes/main.tscn").instantiate()
	view.add_child(app)
	app.use_tracking(false)
	if not app.world.SCREEN_SPILL_ENABLED:
		print("Screen light spill is deferred; skipping its performance comparison.")
		app.emulator.stop()
		app.free()
		view.free()
		quit()
		return
	app.set_stereo(true)
	for i in range(30): await process_frame
	print("STEREO_SIZE ",app.views[0].size," / ",app.views[1].size)
	print("SPILL_BASELINE ",JSON.stringify(await phase(app.world,0)))
	print("SPILL_ENABLED ",JSON.stringify(await phase(app.world,.1)))
	print("SPILL_BASELINE_REPEAT ",JSON.stringify(await phase(app.world,0)))
	print("SPILL_ENABLED_REPEAT ",JSON.stringify(await phase(app.world,.1)))
	app.emulator.stop()
	app.queue_free()
	view.queue_free()
	await process_frame
	quit()
