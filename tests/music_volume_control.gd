extends SceneTree
var failures:=0
var app
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func settle():
	for i in range(6): await process_frame
func fits():
	return app.menu.rows.filter(func(row):return row.item.get("layout","")=="transport").all(func(row):return row.position.x+row.size.x<=row.get_parent().size.x+1)
func run():
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.use_tracking(false)
	if is_instance_valid(app.menu.boot):app.menu.boot.finish()
	app.menu_boot_pending=false
	var sound:=AudioStreamWAV.new();sound.mix_rate=44100;sound.format=AudioStreamWAV.FORMAT_16_BITS
	var bytes:=PackedByteArray();bytes.resize(88200);sound.data=bytes
	sound.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.loop_end=44100
	app.music.kind="local";app.music.player.stream=sound;app.music.player.play()
	app.menu.music.panel_hidden=false;app.menu.open_pause();await settle()
	var menu=app.menu
	menu.select("transport.volume",false)
	var volume=menu.selected_row()
	check(volume.item.id=="transport.volume" and volume.item.icon=="volume" and volume.volume_label!=null,"Audio player has a speaker icon and percentage control")
	var visual=menu.rows.filter(func(row):return row.item.id=="transport.visualiser")[0]
	check(visual.caption==null and visual.item.icon=="visualiser","Visualiser is icon-only and keeps its accessible label")
	var width: float=volume.size.x
	var slot_width: float=volume.volume_label.size.x
	for value in [0.0,.01,.09,.1,.99,1.0]:
		app.music.volume=value;app.music.apply();volume.refresh();await settle()
		check(volume.volume_label.text=="%d%%" % roundi(value*100) and volume.size.x==width and volume.volume_label.size.x==slot_width,"Volume slot remains fixed at %d%%" % roundi(value*100))
	check(fits(),"All player keys fit with the 100% volume slot")
	app.music.volume=.5;app.music.apply()
	var bed: float=app.menu_music_volume
	menu.activate();menu.navigate(Vector2i.LEFT)
	check(menu.editing_id=="transport.volume" and menu.selected_id=="transport.volume" and is_equal_approx(app.music.volume,.45),"A activates volume and left adjusts without navigating away")
	check(app.menu_music_volume==bed and not menu.preview,"Player volume leaves menu music and picture preview unchanged")
	menu.navigate(Vector2i.RIGHT);menu.activate()
	check(is_equal_approx(app.music.volume,.5) and menu.editing_id.is_empty(),"Right adjusts and A finishes")
	menu.navigate(Vector2i.LEFT)
	check(menu.selected_id=="transport.visualiser","Left resumes navigation after finishing volume adjustment")
	menu.select("transport.volume");menu.activate();menu.back()
	check(menu.editing_id.is_empty() and menu.mode=="pause","B finishes volume adjustment and leaves the player open")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		app.menu_view.get_texture().get_image().save_png("res://build/player-display-update/music-volume.png")
	app.set_widescreen(true);await settle()
	check(fits() and volume.size.x==width,"Wide menu keeps the audio player and fixed percentage at the same size")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		app.menu_view.get_texture().get_image().save_png("res://build/player-display-update/wide-music-volume.png")
	app.music.stop();menu.open_pause();await settle()
	check(menu.items.any(func(item):return item.id=="transport.volume") and fits(),"Stopped music keeps volume beside the icon-only visualiser")
	app.menu_large_text=true;menu.apply_accessibility();await settle()
	check(fits(),"Player keys also fit with larger menu text")
	app.queue_free();await process_frame
	quit(1 if failures else 0)
