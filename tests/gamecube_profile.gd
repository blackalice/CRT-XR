extends SceneTree
## Detailed, buffered trace of hardware-core switching and resume. The file
## is written after play stops so trace I/O cannot create the measured hitches.
var app: Node
var events: Array = []
var phase := "startup"
var last_tick := 0
var last_draw := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func tick() -> void:
	var now := Time.get_ticks_usec()
	if last_tick > 0:
		events.append({"kind": "tick", "at_us": now, "gap_us": now - last_tick,
			"frame": Engine.get_process_frames(), "phase": phase})
	last_tick = now

func drawn() -> void:
	var now := Time.get_ticks_usec()
	if last_draw > 0:
		events.append({"kind": "draw", "at_us": now, "gap_us": now - last_draw,
			"frame": Engine.get_process_frames(), "phase": phase})
	last_draw = now

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	events.append({"kind": "clock", "at_us": Time.get_ticks_usec(),
		"unix_s": Time.get_unix_time_from_system()})
	var games := OS.get_environment("CRT_XR_GC_GAMES").split(";", false)
	if games.is_empty(): print("FAIL missing games"); quit(1); return
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(30)
	if OS.get_environment("CRT_XR_PROFILE_ROOM") == "off":
		for view in app.views: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	app.emulator.profile_frames = true
	app.emulator.frame_profiled.connect(func(metrics: Dictionary):
		metrics["kind"] = "emulation"
		metrics["frame"] = Engine.get_process_frames()
		metrics["phase"] = phase
		metrics["game"] = app.emulator.rom_path.get_file()
		events.append(metrics))
	process_frame.connect(tick)
	RenderingServer.frame_post_draw.connect(drawn)
	var rounds := int(OS.get_environment("CRT_XR_GC_ROUNDS")) if OS.has_environment("CRT_XR_GC_ROUNDS") else 4
	var play_frames := int(OS.get_environment("CRT_XR_PROFILE_FRAMES")) if OS.has_environment("CRT_XR_PROFILE_FRAMES") else 300
	for round in range(rounds):
		for game in games:
			if not app.settings_panel.visible: app.toggle_settings()
			var continuing: bool = FileAccess.file_exists(app.emulator.auto_path_for(game))
			phase = "load:%d:%s:%s" % [round, "resume" if continuing else "fresh", game.get_file()]
			app.menu.games.launch_game(game, continuing)
			for i in range(900):
				await process_frame
				if app.emulator.loaded and app.emulator.rom_path == game and app.loading_path.is_empty(): break
			if not app.emulator.loaded or app.emulator.rom_path != game or not app.loading_path.is_empty():
				failures += 1
				print("FAIL ", phase)
				break
			phase = "play:%d:%s:%s" % [round, "resume" if continuing else "fresh", game.get_file()]
			await frames(play_frames)
			print("PROFILE phase ", phase)
	phase = "stop"
	app.emulator.profile_frames = false
	app.emulator.stop()
	process_frame.disconnect(tick)
	RenderingServer.frame_post_draw.disconnect(drawn)
	var file := FileAccess.open(OS.get_environment("CRT_XR_FRAME_TRACE"), FileAccess.WRITE)
	if file == null: print("FAIL trace file"); quit(1); return
	for event in events: file.store_line(JSON.stringify(event))
	file.close()
	print("%s PROFILE COMPLETE events=%d" % ["PASS" if failures == 0 else "FAIL", events.size()])
	quit(0 if failures == 0 else 1)
