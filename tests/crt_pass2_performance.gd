extends SceneTree
var app
var stage: SubViewport
func _initialize(): call_deferred("run")
func sample_phase(label: String, distance_value: float) -> Dictionary:
	app.distance = distance_value
	app._process(0)
	app.world.picture.paused = false
	for i in range(24): await process_frame
	var gpu: Array[float] = []
	var wall: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in range(120):
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append((now-previous)/1000.0)
		previous = now
		var total := 0.0
		for view in [app.views[0],app.views[1],app.signal_view,app.world.picture.decode,app.world.picture.beam]:
			if view.render_target_update_mode != SubViewport.UPDATE_DISABLED:
				total += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
		gpu.append(total)
	gpu.sort()
	wall.sort()
	return {"phase":label,"distance":distance_value,"gpu_ms":gpu[60],"gpu_p95_ms":gpu[114],"wall_ms":wall[60],"wall_p95_ms":wall[114]}
func run():
	var reference_dir := OS.get_environment("CRT_XR_REFERENCE_SHADERS")
	if reference_dir.is_empty():
		push_error("Set CRT_XR_REFERENCE_SHADERS to an offline shader baseline folder containing crt_reference_pass1.gdshader and analog_reference.gdshader.")
		quit(2); return
	var reference := load(reference_dir.path_join("crt_reference_pass1.gdshader")) as Shader
	var reference_decoder := load(reference_dir.path_join("analog_reference.gdshader")) as Shader
	if reference==null or reference_decoder==null:
		push_error("The reference shader baseline is unavailable. Supply both files; no benchmark was run.")
		quit(2); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	stage = SubViewport.new()
	stage.size = Vector2i(3840,1080)
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	app = load("res://scenes/main.tscn").instantiate()
	stage.add_child(app)
	app.close_settings()
	app.use_tracking(false)
	app.set_stereo(true)
	# Load the user's recent ROM from an isolated copy of their preferences.
	if FileAccess.file_exists(app.last_game_path): app.load_game(app.last_game_path)
	for i in range(80): await process_frame
	app.emulator.set_paused(true)
	app.set_process(false)
	app.vertical_fov = 24
	for view in [app.views[0],app.views[1],app.signal_view,app.world.picture.decode,app.world.picture.beam]:
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	print("BENCH_CONFIG ",JSON.stringify({"eye_size":str(app.views[0].size),"mode":app.world.picture.mode,"scanlines":app.scanlines,"glow":app.phosphor_glow,"mask":app.phosphor_mask,"gamma":app.world.picture.values.gamma,"brightness":app.world.picture.values.brightness}))
	var picture = app.world.picture
	var screen:ShaderMaterial=app.world.screen_material
	var current_shader:=screen.shader
	var current_decoder:Shader=picture.decoder.shader
	for distance_value in [2.64,1.2]:
		for index in range(4):
			var optimized:=index%2==1
			screen.shader=current_shader if optimized else reference
			picture.decoder.shader=current_decoder if optimized else reference_decoder
			picture.refresh()
			screen.set_shader_parameter("scanlines",app.scanlines)
			screen.set_shader_parameter("mask_strength",app.phosphor_mask)
			screen.set_shader_parameter("glow_strength",app.phosphor_glow)
			print("CRT_BENCH ",JSON.stringify(await sample_phase("pass2" if optimized else "pass1",distance_value)))
	app.distance_save_delay = -1
	app.free()
	quit()
