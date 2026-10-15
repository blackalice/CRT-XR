extends SceneTree
var app
var stage: SubViewport
func _initialize():call_deferred("run")
func measure(label: String, distance_value: float) -> Dictionary:
	app.distance = distance_value
	for i in range(45): await process_frame
	var slow: int = app.emulator.slow_frames
	var over: int = app.emulator.audio_overflows
	var preview_us: int = app.emulator.preview_time_usec
	var preview_n: int = app.emulator.preview_count
	var samples: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var valid := 0
	var last := Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-last)/1000.0)
		last = now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		var time := 0.0
		for view in [app.views[0],app.views[1],app.signal_view,app.world.picture.decode,app.world.picture.beam]:
			if view.render_target_update_mode!=SubViewport.UPDATE_DISABLED:time+=RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
		gpu.append(time)
		if app.provider.valid:valid+=1
	samples.sort()
	gpu.sort()
	cpu.sort()
	return {"phase":label,"distance":distance_value,"wall_ms":samples[90],"wall_p95_ms":samples[171],"gpu_ms":gpu[90],"cpu_ms":cpu[90],"preview_ms":(app.emulator.preview_time_usec-preview_us)/float(maxi(1,app.emulator.preview_count-preview_n))/1000,"slow":app.emulator.slow_frames-slow,"audio_overflows":app.emulator.audio_overflows-over,"tracking_frames":valid,"tracking_status":app.provider.status}
func run():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	stage=SubViewport.new()
	stage.size=Vector2i(3840,1080)
	stage.own_world_3d=true
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	app=load("res://scenes/main.tscn").instantiate()
	stage.add_child(app)
	app.close_settings()
	app.set_stereo(true)
	app.vertical_fov=24
	if FileAccess.file_exists(app.last_game_path): app.load_game(app.last_game_path)
	for i in range(90): await process_frame
	for view in [app.views[0],app.views[1],app.signal_view,app.world.picture.decode,app.world.picture.beam]:RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	print("LIVE_CONFIG eye=",app.views[0].size," game=",app.emulator.loaded," tracking=",app.provider.status)
	for distance_value in [2.64,1.2]:
		print("LIVE_BENCH ",JSON.stringify(await measure("current",distance_value)))
		app.emulator.run_ahead=0
		print("LIVE_BENCH ",JSON.stringify(await measure("no_preview",distance_value)))
		app.emulator.run_ahead=1
		app.world.screen_material.set_shader_parameter("glow_strength",0)
		print("LIVE_BENCH ",JSON.stringify(await measure("no_glow",distance_value)))
		app.world.screen_material.set_shader_parameter("glow_strength",app.phosphor_glow)
		var mode:int=app.world.picture.mode
		app.world.picture.mode=0
		app.world.picture.refresh()
		print("LIVE_BENCH ",JSON.stringify(await measure("no_composite",distance_value)))
		app.world.picture.mode=mode
		app.world.picture.refresh()
	app.free()
	quit()
