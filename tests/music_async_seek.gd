extends SceneTree
var failures := 0
var last_tick := 0
var worst_gap := 0
var measuring := false
var phase := "scrub"
var worst_phase := ""
func tick() -> void:
	var now := Time.get_ticks_usec()
	if measuring and last_tick > 0 and now - last_tick > worst_gap:
		worst_gap = now - last_tick
		worst_phase = phase
	last_tick = now
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app: Node
	var music: Node
	if OS.get_environment("CRT_XR_SEEK_ROOM") == "1":
		app = load("res://scenes/main.tscn").instantiate()
		root.add_child(app)
		music = app.music
		for i in range(30): await process_frame
	else:
		music = preload("res://scripts/audio/music_player.gd").new()
		root.add_child(music)
	var path := OS.get_environment("CRT_XR_LONG_MP3")
	if path.is_empty(): path = ProjectSettings.globalize_path("res://build/music-long-seek.mp3")
	check(music.play_file(path) and music.duration() > 3500, "one-hour MP3 opens")
	# Loading the file and first drawing the music UI are separate operations.
	for i in range(30): await process_frame
	process_frame.connect(tick)
	measuring = true
	var longest := 0
	for target in [3500.0, 120.0, 3200.0, 700.0, 2800.0, 1800.0]:
		var began := Time.get_ticks_usec()
		music.seek(target)
		longest = maxi(longest, Time.get_ticks_usec() - began)
		await process_frame
	check(longest < 30000, "long-song seek requests do not scan on the scene thread (%d us)" % longest)
	var deadline := Time.get_ticks_msec() + 15000
	var ticks := 0
	while music.local_submitted == 0 and Time.get_ticks_msec() < deadline:
		await create_timer(.005).timeout
		ticks += 1
	check(music.local_submitted > 0 and music.position_seconds() >= 1800.0 and music.position_seconds() < 1805.0, "only the final requested position supplies audio")
	await create_timer(.5).timeout # Includes the debounced bookmark write.
	check(worst_gap < 50000, "scene stays responsive during long-song scrubbing (%d us max gap, %s)" % [worst_gap, worst_phase])
	measuring = false
	phase = "pause and resume"
	music.toggle_playback()
	music.seek(3000)
	check(is_equal_approx(music.position_seconds(), 3000.0), "paused scrub retains its requested position")
	music.toggle_playback()
	deadline = Time.get_ticks_msec() + 15000
	while music.local_submitted == 0 and Time.get_ticks_msec() < deadline: await create_timer(.005).timeout
	check(music.local_submitted > 0 and music.position_seconds() >= 3000.0, "resume seeks on the worker")
	var probe = preload("res://scripts/audio/music_decode_worker.gd").new()
	probe.start()
	probe.request(music.local_audio, 1000.0, AudioServer.get_mix_rate())
	var samples := PackedVector2Array()
	deadline = Time.get_ticks_msec() + 15000
	while samples.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(.005).timeout
		samples = probe.take().frames
	var peak := 0.0
	var finite := true
	for sample in samples:
		finite = finite and sample.is_finite()
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(finite and peak > .001 and peak < 1.5, "worker output contains finite audible PCM")
	probe.close()
	music.seek(3400)
	music.stop()
	await create_timer(.1).timeout
	check(music.player.stream == null and music.local_block.is_empty(), "stop invalidates a pending seek")
	if app != null: app.queue_free()
	else: music.queue_free()
	await process_frame
	print("ASYNC MUSIC SEEK COMPLETE failures=", failures, " scene_ticks=", ticks)
	quit(1 if failures else 0)
