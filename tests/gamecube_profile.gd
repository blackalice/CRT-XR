extends SceneTree
## Detailed, buffered trace of hardware-core switching and resume. The file
## is written after play stops so trace I/O cannot create the measured hitches.
var app: Node
var events: Array = []
var phase := "startup"
var last_tick := 0
var last_draw := 0
var failures := 0
var channel_finishes := 0

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

## Plays for a fixed number of room frames. Optionally saves the TV picture
## every CRT_XR_PROFILE_SNAP frames (logged as "snapshot" events so analysis
## can drop those frames) and taps keyboard pad keys listed in
## CRT_XR_PROFILE_PRESS as frame:key pairs (x=A, z=B, enter=Start, D-pad
## left/right/up/down), so a
## profile can get past prompts to real 3D gameplay.
func play(count: int, round: int, game: String) -> void:
	var snap_every := int(OS.get_environment("CRT_XR_PROFILE_SNAP"))
	var snap_dir := OS.get_environment("CRT_XR_PROFILE_SNAP_DIR")
	var presses := {}
	var names := {"x": KEY_X, "z": KEY_Z, "enter": KEY_ENTER, "left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN}
	for value in OS.get_environment("CRT_XR_PROFILE_PRESS").split(",", false):
		var parts := value.split(":")
		presses[int(parts[0])] = names.get(parts[1] if parts.size() > 1 else "enter", KEY_ENTER)
	var held := 0
	var held_key: Key = KEY_ENTER
	for i in range(count):
		if presses.has(i):
			held_key = presses[i]
			key(held_key, true)
			held = 6
			print("PROFILE_PRESS frame=%d key=%d mask=%d menu_active=%s" % [i, held_key, app.emulator.read_input().mask, app.emulator.gamepad.menu_active])
		elif held > 0:
			held -= 1
			if held == 0: key(held_key, false)
		if snap_every > 0 and i > 0 and i % snap_every == 0 and not snap_dir.is_empty() and app.emulator.last_frame != null:
			events.append({"kind": "snapshot", "at_us": Time.get_ticks_usec(), "phase": phase, "frame_index": i})
			app.emulator.last_frame.save_png(snap_dir.path_join("%d-%s-%05d.png" % [round, game.get_basename().validate_filename(), i]))
		await process_frame

## The same coarse brightness grid main.gd uses to decide a picture has started.
func lit_points(image: Image) -> int:
	if image == null or image.is_empty(): return 0
	var lit := 0
	for row in range(12):
		for column in range(16):
			var colour := image.get_pixel((column * 2 + 1) * image.get_width() / 32, (row * 2 + 1) * image.get_height() / 24)
			if maxf(colour.r, maxf(colour.g, colour.b)) > 0.12: lit += 1
	return lit

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	events.append({"kind": "clock", "at_us": Time.get_ticks_usec(),
		"unix_s": Time.get_unix_time_from_system()})
	var games := OS.get_environment("CRT_XR_GC_GAMES").split(";", false)
	if games.is_empty(): print("FAIL missing games"); quit(1); return
	# 0 synchronous, 2 hybrid (asynchronous ubershaders); empty keeps the saved choice.
	var shaders := OS.get_environment("CRT_XR_GC_SHADERS")
	if not shaders.is_empty():
		preload("res://scripts/emulation/core_options.gd").write_value("gamecube", "", "dolphin_shader_compilation_mode", "" if shaders == "default" else shaders)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(30)
	if OS.get_environment("CRT_XR_GC_FULL_SBS") == "1":
		# Two 1920x1080 eye renders (3840x1080 full SBS), even when Gamescope
		# clamps this test window to the Deck panel.
		for i in range(app.views.size()):
			app.panels[i].stretch = false
			app.views[i].size = Vector2i(1920, 1080)
		await frames(5)
	print("PROFILE START stereo=%s eye_size=%s" % [app.stereo, app.views[0].size])
	if OS.get_environment("CRT_XR_PROFILE_ROOM") == "off":
		for view in app.views: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	app.tv_effects.finished.connect(func(effect):
		if effect == "channel": channel_finishes += 1)
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
			phase = "menu:%d:%s" % [round, game.get_file()]
			if not app.settings_panel.visible: app.toggle_settings()
			await frames(3)
			var continuing: bool = FileAccess.file_exists(app.emulator.auto_path_for(game))
			phase = "load:%d:%s:%s" % [round, "resume" if continuing else "fresh", game.get_file()]
			var effects_before := channel_finishes
			# Loading-card timeline: game ready (booted and, when continuing,
			# restored), first picture after that, first bright one, card down.
			var card := {"launch": Time.get_ticks_msec(), "ready": -1, "first": -1, "lit": -1, "down": -1}
			var watch := func(image: Image):
				if card.ready < 0 or app.emulator.rom_path != game: return
				var now := Time.get_ticks_msec()
				if card.first < 0: card.first = now
				if card.lit < 0 and lit_points(image) >= 4: card.lit = now
			app.emulator.frame_presented.connect(watch)
			app.menu.games.launch_game(game, continuing)
			for i in range(2400):
				await process_frame
				if card.ready < 0 and app.emulator.loaded and app.emulator.rom_path == game and not app.loading_game and not app.emulator.transition_busy:
					card.ready = Time.get_ticks_msec()
				if app.emulator.loaded and app.emulator.rom_path == game and app.loading_path.is_empty():
					card.down = Time.get_ticks_msec()
					break
			app.emulator.frame_presented.disconnect(watch)
			var since := func(key): return -1 if card[key] < 0 else card[key] - card.launch
			print("PROFILE_CARD %s ready=%d first=%d lit=%d down=%d ms" % [phase, since.call("ready"), since.call("first"), since.call("lit"), since.call("down")])
			events.append({"kind": "card", "phase": phase, "ready": since.call("ready"), "first": since.call("first"), "lit": since.call("lit"), "down": since.call("down")})
			if not app.emulator.loaded or app.emulator.rom_path != game or not app.loading_path.is_empty():
				failures += 1
				print("FAIL ", phase)
				break
			if channel_finishes - effects_before > 1:
				failures += 1
				print("FAIL duplicate channel animation ", game)
			phase = "play:%d:%s:%s" % [round, "resume" if continuing else "fresh", game.get_file()]
			await play(play_frames, round, game.get_file())
			print("PROFILE phase ", phase, " game_fps=%.1f target=%.2f" % [app.emulator.game_fps, app.emulator.fps])
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
