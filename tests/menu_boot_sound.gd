extends SceneTree
var failures := 0
var app
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func settle() -> void:
	for i in range(8): await process_frame
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.apply_settings(ConfigFile.new())
	check(app.menu_boot_sound and not app.menu_sounds, "Boot sound defaults on independently of menu ticks")
	app.menu_reduced_motion = false
	var options: Array = app.menu.catalog.pages(9)[2].rows
	var option: Dictionary = options.filter(func(row): return row.id == "access.boot_sound")[0]
	option.setter.call(false)
	var saved: ConfigFile = app.capture_settings()
	app.menu_boot_sound = true
	app.apply_settings(saved)
	check(not app.menu_boot_sound, "Boot sound Off survives save and restore")
	app.play_boot_sound()
	check(not is_instance_valid(app.boot_audio), "Disabled boot sound creates no playing audio")
	option.setter.call(true)
	app.menu_reduced_motion = true
	# Exercise the real handover gate, even with animation reduced.
	app.power_on.set_progress(1.0)
	app.power_on.set_process(false)
	app.menu_boot_pending = true
	await settle()
	check(app.boot_audio.playing and not app.menu_boot_pending, "Sound starts at handover independently of reduced animation")
	check(absf(app.boot_audio.stream.get_length() - 11.918277) < 0.01, "NewBoot stereo WAV retains its full tail")
	var before: float = app.boot_audio.get_playback_position()
	await settle()
	check(app.boot_audio.get_playback_position() >= before, "Subsequent frames do not restart boot sound")
	app.menu_reduced_motion = false
	app.menu.begin_boot(); app.menu.boot.set_process(false)
	await settle()
	app.menu.boot.seek(3.8)
	await settle()
	check(app.boot_audio.playing, "Natural visual completion lets the sound tail finish")
	option.setter.call(false)
	check(not app.boot_audio.playing, "Turning Boot sound off immediately stops its tail")
	option.setter.call(true)
	app.play_boot_sound()
	app.menu.begin_boot(); app.menu.boot.set_process(false)
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A; event.pressed = true
	app._input(event)
	check(app.boot_audio.playing and app.menu.mode == "pause", "A reveals the menu without cutting off the boot cue or activating an action")
	await settle()
	for key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		var arrow := InputEventKey.new(); arrow.physical_keycode=key; arrow.pressed=true
		app._input(arrow)
		arrow.pressed=false; app._input(arrow)
	check(app.boot_audio.playing, "Keyboard directions preserve the boot tail after the logo has finished")
	event.button_index=JOY_BUTTON_B
	app._input(event)
	check(not app.boot_audio.playing, "B stops the boot tail after the logo has finished")
	if app.menu.mode=="confirm": app.menu.back()
	if not app.settings_panel.visible: app.toggle_settings()
	app.play_boot_sound()
	app.menu.begin_boot(); app.menu.boot.set_process(false)
	event.button_index=JOY_BUTTON_DPAD_DOWN
	app._input(event)
	check(app.boot_audio.playing, "D-pad input can reveal the menu while preserving boot sound")
	await settle()
	var own_audio := AudioStreamWAV.new(); own_audio.mix_rate=44100; own_audio.data=PackedByteArray(); own_audio.data.resize(88200)
	app.music.player.stream=own_audio; app.music.player.play()
	app._process(0.0)
	check(not app.boot_audio.playing, "Starting the user's music stops the boot tail")
	app.play_boot_sound()
	check(not app.boot_audio.playing, "Boot sound never starts over music already playing")
	app.music.stop()
	app.play_boot_sound()
	app.close_settings()
	check(not app.boot_audio.playing, "Leaving the menu stops the remaining boot tail")
	app.free()
	print("BOOT SOUND: ", failures, " failures")
	quit(1 if failures else 0)
