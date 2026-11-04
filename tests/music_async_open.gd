extends SceneTree
var failures := 0
var ticks := 0
var last_tick := 0
var worst_gap := 0
func tick() -> void:
	var now := Time.get_ticks_usec()
	if last_tick > 0: worst_gap = maxi(worst_gap, now - last_tick)
	last_tick = now; ticks += 1
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func settle(music) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while (music.music_loading or music.open_thread != null) and Time.get_ticks_msec() < deadline: await create_timer(.005).timeout
func run() -> void:
	var app: Node
	var music: Node
	if OS.get_environment("CRT_XR_OPEN_ROOM") == "1":
		app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
		music = app.music
		for i in range(30): await process_frame
	else:
		music = preload("res://scripts/audio/music_player.gd").new(); root.add_child(music)
	var long_track := OS.get_environment("CRT_XR_LONG_MP3")
	if long_track.is_empty(): long_track = ProjectSettings.globalize_path("res://build/music-long-seek.mp3")
	var short_track := OS.get_environment("CRT_XR_SHORT_MP3")
	if short_track.is_empty(): short_track = ProjectSettings.globalize_path("res://build/crt-power-original-preview.mp3")
	check(music.play_file(short_track), "initial track loads")
	process_frame.connect(tick)
	var before := ticks
	var started := Time.get_ticks_usec()
	music.call("play_file_async", long_track)
	check(Time.get_ticks_usec() - started < 30000 and music.music_loading and music.last_file == short_track, "file request returns without scanning and preserves the playing track")
	await settle(music)
	check(not music.music_loading and music.last_file == long_track and music.duration() > 3500 and ticks > before, "one-hour MP3 opens while scene updates continue")
	var original = music.player.stream
	check(not await music.play_file_async(long_track + ".missing") and music.player.stream == original, "failed opening preserves the playing stream")
	music.call("play_file_async", long_track)
	music.call("play_file_async", short_track)
	await settle(music)
	check(music.last_file == short_track, "latest file selection wins")
	music.call("play_file_async", long_track)
	music.stop()
	await settle(music)
	check(music.player.stream == null and not music.music_loading, "Stop invalidates an unfinished open")
	print("PROFILE music_open worst_scene_gap_us=", worst_gap)
	if app != null: app.queue_free()
	else: music.queue_free()
	await process_frame
	print("MUSIC OPEN COMPLETE failures=", failures)
	quit(1 if failures else 0)
