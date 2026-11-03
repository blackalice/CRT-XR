extends SceneTree
## Boot through the real room/menu with isolated XDG_DATA_HOME. Unlike the native
## runtime test this exercises rendering, pauses, audio pacing and automatic saves.
var worst_ms := 0.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(30): await process_frame
	var path := OS.get_environment("CRT_XR_GAMECUBE_ROM")
	app.menu.games.launch_game(path, false)
	var last := Time.get_ticks_usec()
	for i in range(750):
		await process_frame
		var now := Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, (now - last) / 1000.0)
		last = now
		if i == 400:
			app.toggle_settings()
			await create_timer(0.3).timeout
			app.close_settings()
	var ok: bool = app.emulator.loaded and not app.emulator.core_failed and app.emulator.rom_path == path
	print("%s BOOT %s worst_ms=%.1f audio_overflows=%d slow_frames=%d" % ["PASS" if ok else "FAIL", path.get_file(), worst_ms, app.emulator.audio_overflows, app.emulator.slow_frames])
	app.emulator.save_auto()
	app.emulator.stop()
	quit(0 if ok else 1)
