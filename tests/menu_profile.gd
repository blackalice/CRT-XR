extends SceneTree
var last_tick := 0
var worst_gap := 0
func tick() -> void:
	var now := Time.get_ticks_usec()
	if last_tick > 0: worst_gap = maxi(worst_gap, now - last_tick)
	last_tick = now
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await process_frame
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(30)
	var rom := OS.get_environment("CRT_XR_MENU_PROBE")
	if rom.is_empty(): rom = ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
	if not app.load_game(rom): print("FAIL menu probe"); quit(1); return
	app.was_paused_before_menu = true
	app.emulator.set_paused(true)
	app.emulator.profile_frames = true
	app.close_settings()
	process_frame.connect(tick)
	await app.menu.prepare_pause()
	for i in range(12):
		app.close_settings()
		await frames(3)
		var start := Time.get_ticks_usec()
		app.toggle_settings()
		print("PROFILE_MENU_OPEN ", i, " us=", Time.get_ticks_usec() - start)
		await frames(3)
	print("PROFILE_MENU worst_frame_gap_us=", worst_gap)
	if worst_gap > 50000: print("FAIL menu frame gap"); quit(1); return
	app.queue_free()
	await process_frame
	print("PASS MENU PROFILE COMPLETE")
	quit()
