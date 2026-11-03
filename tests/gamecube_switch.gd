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
		if record_lead and lead.size() < 10: lead.append(int(ms))

func run() -> void:
	var games: PackedStringArray = OS.get_environment("CRT_XR_GC_GAMES").split(";", false)
	var rounds := maxi(1, int(OS.get_environment("CRT_XR_GC_ROUNDS")) if not OS.get_environment("CRT_XR_GC_ROUNDS").is_empty() else 2)
	if games.is_empty(): print("FAIL: set CRT_XR_GC_GAMES"); quit(1); return
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(30)
	var failures := 0
	for round in range(rounds):
		for game in games:
			var started := Time.get_ticks_msec()
			var mode := OS.get_environment("CRT_XR_GC_DIRECT")
			var opened := true
			var card_frames := 0
			var card_seen_at := -1
			worst_frame = 0.0
			slow_frames = 0
			if mode == "menu":
				# The real launch: menu open, previous game paused behind it, card first.
				lead = []
				record_lead = true
				app.menu.games.launch_game(game, false)
				for i in range(600):
					await frames(1)
					if not app.loading_path.is_empty():
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
			await frames(300)
			var ok: bool = opened and app.emulator.loaded and not app.emulator.core_failed and (mode != "menu" or card_frames > 0)
			print("%s round %d %s: %s %d ms; card up for %d frames (first seen %d ms in); after it, 300 frames worst %.0f ms, %d over 50 ms; menu %s" % ["PASS" if ok else "FAIL", round, game.get_file(), "launch took" if mode == "menu" else "load blocked", blocked, card_frames, card_seen_at, worst_frame, slow_frames, "open" if app.settings_panel.visible else "closed"])
			if not ok: failures += 1
	app.emulator.stop()
	print("GAMECUBE SWITCH COMPLETE: %d failures" % failures)
	quit(1 if failures > 0 else 0)
