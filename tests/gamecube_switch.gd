extends SceneTree
## Real-core stress test for switching GameCube games inside one process, the way
## the menu does. CRT_XR_GC_GAMES lists game files separated by ";" and
## CRT_XR_GC_ROUNDS how many times to go round them (default 2). It reports how long
## each load blocks the main thread and how long the frames after it take, so a freeze
## or stutter shows as numbers. Needs a display (Dolphin draws with OpenGL).
var worst_frame := 0.0
var slow_frames := 0
var lead: Array = [] # durations (ms) of the first frames after a launch
var record_lead := false
var observed_core: RefCounted
var hitches: Array = []

func _initialize() -> void: call_deferred("run")

func frames(count: int) -> void:
	var last := Time.get_ticks_usec()
	for i in range(count):
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		worst_frame = maxf(worst_frame, ms)
		if ms > 50.0: slow_frames += 1
		if ms > 50.0 and observed_core != null:
			var info: Dictionary = observed_core.info()
			hitches.append({"wall_ms": int(ms), "core_us": info.step_usec, "readback_us": info.readback_usec})
		if record_lead and lead.size() < 10: lead.append(int(ms))

func run() -> void:
	var shaders := OS.get_environment("CRT_XR_GC_SHADERS")
	if not shaders.is_empty():
		preload("res://scripts/emulation/core_options.gd").write_value("gamecube", "", "dolphin_shader_compilation_mode", shaders)
	var games: PackedStringArray = OS.get_environment("CRT_XR_GC_GAMES").split(";", false)
	var rounds := maxi(1, int(OS.get_environment("CRT_XR_GC_ROUNDS")) if not OS.get_environment("CRT_XR_GC_ROUNDS").is_empty() else 2)
	if games.is_empty(): print("FAIL: set CRT_XR_GC_GAMES"); quit(1); return
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(30)
	if OS.get_environment("CRT_XR_GC_FULL_SBS") == "1":
		# Match two 1920x1080 eye renders even when Gamescope clamps this SSH
		# test window to the Deck panel's size. No physical display mode changes.
		for i in range(app.views.size()):
			app.panels[i].stretch = false
			app.views[i].size = Vector2i(1920, 1080)
		await frames(5)
	print("GAMECUBE SWITCH START: pid=%d stereo=%s eye_size=%s" % [OS.get_process_id(), app.stereo, app.views[0].size])
	var failures := 0
	for round in range(rounds):
		for game in games:
			observed_core = null
			var started := Time.get_ticks_msec()
			var mode := OS.get_environment("CRT_XR_GC_DIRECT")
			var opened := true
			var card_frames := 0
			var card_seen_at := -1
			var card_title_ok := true
			var expects_card: bool = app.shows_loading_card(game)
			worst_frame = 0.0
			slow_frames = 0
			if mode == "menu":
				# The real launch: menu open, previous game paused behind it, card first.
				if not app.settings_panel.visible: app.toggle_settings()
				lead = []
				record_lead = true
				var continuing := OS.get_environment("CRT_XR_GC_CONTINUE") == "1" and FileAccess.file_exists(app.emulator.auto_path_for(game))
				app.menu.games.launch_game(game, continuing)
				for i in range(600):
					await frames(1)
					if not expects_card and app.emulator.loaded and app.emulator.rom_path == game: break
					if not app.loading_path.is_empty():
						card_title_ok = card_title_ok and app.loading_path == game and app.loading_screen.title == game.get_file().get_basename()
						card_frames += 1
						if card_seen_at < 0: card_seen_at = Time.get_ticks_msec() - started
					elif card_frames > 0: break
			else:
				opened = app.emulator.load_rom(game) if mode == "1" else app.load_game(game)
			record_lead = false
			var blocked := Time.get_ticks_msec() - started
			if mode == "menu": print("LEAD frames after launch (ms): ", lead)
			worst_frame = 0.0
			slow_frames = 0
			hitches = []
			observed_core = app.emulator.core
			await frames(300)
			observed_core = null
			if not hitches.is_empty(): print("HITCHES ", game.get_file(), " ", JSON.stringify(hitches))
			var ok: bool = opened and app.emulator.loaded and app.emulator.rom_path == game and not app.emulator.core_failed and (mode != "menu" or ((not expects_card or card_frames > 0) and card_title_ok and app.loading_path.is_empty() and app.emulator.texture != null and not app.settings_panel.visible))
			print("%s round %d %s: %s %d ms; card up for %d frames (first seen %d ms in); after it, 300 frames worst %.0f ms, %d over 50 ms; menu %s" % ["PASS" if ok else "FAIL", round, game.get_file(), "launch took" if mode == "menu" else "load blocked", blocked, card_frames, card_seen_at, worst_frame, slow_frames, "open" if app.settings_panel.visible else "closed"])
			if not ok: failures += 1
	app.emulator.stop()
	print("GAMECUBE SWITCH COMPLETE: %d failures" % failures)
	quit(1 if failures > 0 else 0)
