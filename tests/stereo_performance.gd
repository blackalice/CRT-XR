extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func phase(session: Node, enabled: bool) -> Dictionary:
	session.run_ahead = enabled
	for i in range(30): await process_frame
	var slow: int = session.slow_frames
	var overflow: int = session.audio_overflows
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in range(240):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
	var total := 0.0
	for sample in samples: total += sample
	samples.sort()
	return {"preview": enabled, "fps": 240000.0 / total, "p95_ms": samples[228],
		"slow_events": session.slow_frames - slow, "audio_overflows": session.audio_overflows - overflow}

func run() -> void:
	# Render the actual full-resolution stereo scene offscreen; leave the user's
	# output mode and KScreen layout untouched. No screenshots are produced.
	var view := SubViewport.new()
	view.size = Vector2i(3840, 1080)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var app = load("res://scenes/main.tscn").instantiate()
	view.add_child(app)
	app.use_tracking(false)
	app.set_stereo(true)
	for i in range(90): await process_frame
	print("Stereo performance dimensions: ", app.views[0].size, " / ", app.views[1].size)
	var baseline := await phase(app.emulator, false)
	var preview := await phase(app.emulator, true)
	print("STEREO_BASELINE ", JSON.stringify(baseline))
	print("STEREO_PREVIEW ", JSON.stringify(preview))
	var passed: bool = app.emulator.loaded and app.emulator.preview_count > 0 and preview.fps >= baseline.fps * 0.9
	app.emulator.stop()
	app.queue_free()
	view.queue_free()
	await process_frame
	quit(0 if passed else 1)
