extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func wait_for(test: Callable, seconds:=6.0):
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not test.call() and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	return test.call()
func run():
	var base := AudioServer.bus_count
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); app.use_tracking(false)
	var music=app.music
	music.reset_defaults()
	check(not music.player.playing and music.http==null,"Music never autoplays on startup")
	check(AudioServer.bus_count==base+2,"TV and music use separate shared mixer buses")
	check(music.play_file(ProjectSettings.globalize_path("res://build/crt-power-original-preview.mp3")),"Local MP3 opens")
	app.menu.open_settings(); app.menu.category=2; app.menu.subsection=1; app.menu.render()
	check(music.player.playing,"Music continues while the settings menu is open")
	check(app.menu.CATEGORIES[2]=="Audio" and app.menu.items.any(func(i): return i.id=="music.file"),"Audio has its own category and music page")
	music.volume=.3; music.game_volume=.2; music.apply()
	check(is_equal_approx(music.player.volume_db,linear_to_db(.3)) and is_equal_approx(app.emulator.player.volume_db,-6+linear_to_db(.2)),"Game and music volume controls are independent")
	var config: ConfigFile=app.capture_settings()
	music.volume=.9; app.apply_settings(config)
	check(is_equal_approx(music.volume,.3) and not music.last_file.is_empty(),"Source and levels persist through the existing settings store")
	music.update_pose(Quaternion.IDENTITY,Vector3.ZERO,Vector3(0,0,-3),1)
	check(music.panner.pan<0,"Radio sits to the left of the TV")
	music.update_pose(Quaternion(Vector3.UP,PI/2),Vector3.ZERO,Vector3(0,0,-3),1)
	check(music.panner.pan>0,"Radio follows head-relative direction")
	music.reverb=0; music.directional=0; music.apply()
	var index := AudioServer.get_bus_index(music.bus_name)
	check(not AudioServer.is_bus_effect_enabled(index,0) and not AudioServer.is_bus_effect_enabled(index,1),"Zero reverb and direction disable the native effects")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/music-fixture"))
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://build/crt-power-original-preview.mp3"),ProjectSettings.globalize_path("res://build/music-fixture/test.mp3"))
	app.menu.music.open_music_browser(ProjectSettings.globalize_path("res://build/music-fixture"))
	check(app.menu.items.any(func(i): return i.id.begins_with("music.track.")),"Music browser exposes MP3s without altering the ROM library")
	app.menu.back(); check(app.menu.mode=="settings" and app.menu.category==2,"Music browser returns to Audio")
	app.menu.music.edit_radio_url(); app.menu.rename_field.text="https://example.org/radio.mp3"; app.menu.music.save_radio_url()
	check(music.station_url=="https://example.org/radio.mp3" and app.menu.mode=="settings","Radio URL editor saves and returns to its originating page")
	check(not music.play_station("file:///not-radio"),"Non-HTTP sources are rejected")
	check(ClassDB.class_exists("RadioMP3Decoder"),"Native streaming MP3 decoder is packaged")
	if ClassDB.class_exists("RadioMP3Decoder"):
		var decoder=ClassDB.instantiate("RadioMP3Decoder")
		var bytes := FileAccess.get_file_as_bytes("res://build/crt-power-original-preview.mp3")
		var count := 0
		var peak := 0.0
		var finite := true
		for start in range(0,bytes.size(),137):
			decoder.append(bytes.slice(start,mini(start+137,bytes.size())))
			var frames: PackedVector2Array=decoder.decode(8)
			count+=frames.size()
			for frame in frames:
				finite=finite and frame.is_finite()
				peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		check(count>1000 and decoder.get_sample_rate()>0,"Fragmented MP3 input decodes while retaining partial frames")
		check(finite and peak>.001 and peak<1.5,"Decoded PCM contains finite, audible, correctly scaled float samples")
		var huge := PackedByteArray(); huge.resize(262145)
		check(not decoder.append(huge),"Decoder rejects unbounded network buffering")
	for route in ["stream","icy","redirect"]:
		music.play_station("http://127.0.0.1:18764/"+route)
		var ready: bool=await wait_for(func(): return music.streaming)
		print("RADIO STATUS: ",music.status," processing=",music.is_processing()," requested=",music.requested," idle=",music.idle," http=",music.http.get_status() if music.http!=null else -1)
		check(ready,"Radio plays "+route+" with fragmented HTTP input")
		if ready:
			await create_timer(.35).timeout
			check(music.player.playing and music.decoder.get_buffered_bytes()<262144,"Radio remains active with bounded buffers")
		music.stop()
	music.play_station("http://127.0.0.1:18764/bad")
	await wait_for(func(): return music.http==null)
	check("not an MP3" in music.status,"Unsupported station format gives an actionable error")
	music.play_station("http://127.0.0.1:18764/drop")
	await wait_for(func(): return music.http==null)
	check(not music.player.playing and ("ended" in music.status or "disconnected" in music.status),"Disconnect stops radio and offers reconnection")
	app.free()
	await process_frame
	check(AudioServer.bus_count==base,"Music and TV mixer buses are released on exit")
	print("MUSIC CHECKS COMPLETE: ",failures," failures"); quit(1 if failures else 0)
