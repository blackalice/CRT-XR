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
	app.set_process(false)
	app.apply_settings(ConfigFile.new())
	var bed = app.menu_ambience
	bed.silence()
	check(app.menu_music_enabled and is_equal_approx(app.menu_music_volume, 0.10), "Menu music defaults to a quiet 10 percent")
	check(bed.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and bed.stream.loop_end == 732739, "Native sample loop spans the complete supplied WAV")
	bed.update(1.0, true, false, null, true)
	check(not bed.playing, "Display setup and startup curtains keep background music silent")
	app.play_boot_sound()
	bed.update(1.0, true, false, app.boot_audio)
	check(not bed.playing, "Menu music waits during the main boot cue")
	app.boot_audio.seek(4.2)
	await create_timer(0.05).timeout
	bed.update(0.75, true, false, app.boot_audio)
	check(bed.playing and is_equal_approx(bed.gain, 0.5) and bed.volume_db < -20.0, "Menu music fades in as the boot sound tails off")
	app.stop_boot_sound()
	bed.update(0.75, true, false, app.boot_audio)
	check(is_equal_approx(bed.gain, 1.0), "Crossfade reaches the chosen low volume")
	var options: Array = app.menu.catalog.pages(9)[2].rows
	var toggle: Dictionary = options.filter(func(row): return row.id == "access.menu_music")[0]
	var volume: Dictionary = options.filter(func(row): return row.id == "access.menu_music_volume")[0]
	volume.setter.call(0.05)
	check(is_equal_approx(bed.volume_db, linear_to_db(0.05)), "Volume changes apply live independently of album volume")
	volume.setter.call(0.0)
	check(not bed.playing, "Zero volume mutes the menu loop")
	volume.setter.call(0.10); toggle.setter.call(false)
	var saved: ConfigFile = app.capture_settings()
	toggle.setter.call(true); volume.setter.call(0.8)
	app.apply_settings(saved)
	bed.update(1.0, true, false, null)
	check(not bed.playing and not app.menu_music_enabled and is_equal_approx(app.menu_music_volume, 0.1), "On/off and volume survive settings restore")
	toggle.setter.call(true)
	bed.update(1.5, true, false, null)
	bed.seek(16.55)
	await create_timer(0.3).timeout
	check(bed.playing and bed.get_playback_position() < 1.0, "Audio crosses the loop boundary without stopping or restarting its player")
	app.music.player.stream = preload("res://assets/audio/menu-bgm.wav")
	app.music.player.play()
	app._process(0.1)
	check(not bed.playing, "The user's own music takes priority in menus")
	app.music.player.stream_paused = true
	app._process(1.5)
	check(bed.playing, "Background returns when the user's music is paused")
	app.music.stop()
	app.close_settings()
	check(not bed.playing, "Returning to gameplay stops the menu music immediately")
	app.toggle_settings(); app._process(1.5)
	check(bed.playing, "Reopening menus brings the quiet music back")
	toggle.setter.call(false)
	check(not bed.playing, "Turning menu music off silences it immediately")
	app.free()
	print("MENU AMBIENCE: ", failures, " failures")
	quit(1 if failures else 0)
