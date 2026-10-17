extends SceneTree

var failures := 0
func check(condition: bool, text: String) -> void:
	if condition: print("PASS: ", text)
	else:
		push_error(text)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ClassDB.class_exists("RetroCore"), "Native RetroCore class is registered")
	if not ClassDB.class_exists("RetroCore"):
		quit(1)
		return
	var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.close_settings()
	app.use_tracking(false)
	await process_frame
	await process_frame
	var session = app.emulator
	check(session.load_rom(rom), "Application loads original diagnostic ROM with Snes9x")
	if not session.loaded:
		quit(1)
		return
	await create_timer(0.65).timeout
	check(session.texture != null, "Running core framebuffer becomes a Godot texture")
	check(session.texture.get_width() == 256, "Game source retains native pixel dimensions")
	check(app.world.picture.source_texture == session.texture, "Live game texture is bound to the curved CRT screen")
	check(app.world.screen_light.source != null and app.world.screen_light.source.get_width() == 256, "Screen light receives the existing CPU presentation frame")
	check(not app.pattern.visible, "Test signal is replaced during gameplay")
	check(session.fps > 60.0 and session.fps < 61.0, "Runtime uses the core's console frame rate")
	check(int(session.core.info().audio_frames) > 0, "Real core produces audio frames")
	check(session.player.stream is AudioStreamGenerator, "Godot audio stream is configured at core sample rate")
	if DisplayServer.get_name() != "headless":
		check(session.playback != null, "Godot audio generator is active")
	session.set_paused(true)
	var paused_state: PackedByteArray = session.core.save_state()
	await create_timer(0.15).timeout
	check(session.core.save_state() == paused_state, "Pause stops emulated CPU/audio execution")
	check(session.save_state(0), "Application writes a save-state envelope")
	for i in range(5): session.core.run_frame(1)
	check(session.load_state(0), "Application loads its saved state")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Z
	event.pressed = true
	Input.parse_input_event(event)
	session.set_paused(false)
	await create_timer(0.15).timeout
	var bytes: PackedByteArray = session.core.frame()
	check(bytes[0] > 240 and bytes[1] < 8 and bytes[2] < 8, "Keyboard B input reaches the running SNES program")
	event.pressed = false
	Input.parse_input_event(event)
	var hash: String = session.rom_hash
	session.stop()
	check(app.pattern.visible and not session.loaded, "Stopping gameplay restores the animated test signal")
	var ram := FileAccess.get_file_as_bytes("user://saves/" + hash + ".srm")
	check(not ram.is_empty() and ram[0] == 0x5A, "Cartridge SRAM persists to disk")
	check(session.load_rom(rom), "Game can be loaded again after stopping")
	session.stop()
	app.queue_free()
	await process_frame
	await process_frame
	print("Emulation checks complete: ", failures, " failures")
	quit(1 if failures else 0)
