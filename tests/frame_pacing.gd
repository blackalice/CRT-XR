extends SceneTree
## Display-locked pacing: a game within 1% of the room's rate gets exactly one
## frame per refresh despite jittery update timing, other rates follow a fixed
## pattern, and a hitch is caught up. The readout of the game's frame rate is
## steady over its rolling window.
var failures := 0
func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var session = preload("res://scripts/emulation/emulation_session.gd").new()
	root.add_child(session)
	session.set_process(false)
	session.fps = 59.94
	var counts := {}
	for i in range(3600):
		var delta := (1.0 / 60.0) + (0.0006 if i % 2 == 0 else -0.0006) # ±0.6 ms jitter
		var due: int = session.frames_due(delta)
		counts[due] = counts.get(due, 0) + 1
	check(counts.get(1, 0) == 3600, "a 59.94 Hz game on a jittery 60 Hz room gets one frame every refresh: %s" % counts)
	session.fps = 50.0
	session.frame_phase = 0.0
	session.room_period = 1.0 / 60.0
	var pattern := ""
	for i in range(60): pattern += str(session.frames_due(1.0 / 60.0))
	check(pattern.count("0") == 10 and not pattern.contains("00"), "a 50 Hz game on 60 Hz follows a steady 5-of-6 pattern: " + pattern)
	session.fps = 60.0
	session.frame_phase = 0.0
	check(session.frames_due(3.0 / 60.0) == 3, "a hitch of three refreshes is caught up")
	session.room_period = 1.0 / 120.0
	session.fps = 59.94
	session.frame_phase = 0.0
	pattern = ""
	for i in range(240): pattern += str(session.frames_due(1.0 / 120.0))
	check(pattern.count("1") == 120 and not pattern.contains("11") and not pattern.contains("00"), "on a 120 Hz room a 59.94 Hz game alternates evenly")
	session.game_fps_samples.clear()
	session.game_fps_total = 0
	var readings: Array[float] = []
	for i in range(240):
		session.count_game_frames(1, 1.0 / 60.0)
		if i > 60 and i % 15 == 0: readings.append(session.game_fps)
		await create_timer(1.0 / 60.0).timeout
	var spread: float = readings.max() - readings.min() if not readings.is_empty() else 99.0
	check(spread < 3.0, "the frame-rate readout stays steady (spread %.1f fps)" % spread)
	session.queue_free()
	await process_frame
	print("FRAME PACING COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
