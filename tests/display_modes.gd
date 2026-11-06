extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func settle():
	for i in range(5):await process_frame
func run():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.use_tracking(false)
	if is_instance_valid(app.menu.boot):app.menu.boot.finish()
	app.menu_boot_pending=false;await settle()
	var prefs=app.display_settings
	app.emulator.system_id="wii";app.emulator.rom_hash="brawl-fit-test";app.change_game_preferences(true)
	var platform:Dictionary=prefs.entry("platforms","wii").duplicate(true)
	for value in range(6):
		prefs.choose_display(value);await settle()
		check(prefs.display_choice()==value and app.world.widescreen==(value>=3),"Combined choice applies "+prefs.DISPLAY_CHOICES[value])
		check(app.world.picture.keep_aspect==(value%3!=2) and app.world.picture.fit_mode==(1 if value%3==1 else 0),"Fitting matches the selected display mode")
		check(prefs.entry("platforms","wii")==platform,"Quick Display keeps platform defaults unchanged")
		app.menu.open_pause();app.menu.select("pause.display",false);await settle()
		var row=app.menu.selected_row()
		check(row.value_label.text==prefs.DISPLAY_CHOICES[value] and row.value_label.get_line_count()==1,"Combined display caption fits one line")
	app.menu_large_text=true;app.menu.apply_accessibility();await settle()
	var largest=app.menu.selected_row()
	var text_width:float=largest.value_label.get_theme_font("font").get_string_size(largest.value_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,largest.value_label.get_theme_font_size("font_size")).x
	check(largest.value_label.size.x>=text_width,"Longest display label fits without truncation in larger text")
	prefs.choose_display(4);app.save_settings()
	var saved:ConfigFile=app.SettingsStore.new().read("user://settings.cfg")
	app.change_game_preferences(false);app.change_game_preferences(true)
	check(prefs.display_choice()==4,"Game restores Wide TV (Crop)")
	app.video.path="res://build/modes-video.mp4";app.change_game_preferences(true,app.VIDEO_PROFILE)
	prefs.choose_display(5)
	check(prefs.display_choice()==5,"Video independently selects Wide TV (Stretch)")
	app.change_game_preferences(true)
	check(prefs.display_choice()==4,"Game fitting is unaffected by video fitting")
	app.restore_settings(saved);app.change_game_preferences(true)
	check(prefs.display_choice()==4,"Combined mode survives saved-settings restoration")
	# Reproduce a core-metadata packet followed by image-only packets. Polls
	# without a fresh image must retain exactly the same rectangle as uploads.
	app.close_settings();await settle()
	app.emulator.update_display_aspect({"display_aspect":16.0/9.0})
	app.world.picture.menu_fitting=false;app.world.picture.keep_aspect=true;app.world.picture.fit_mode=0
	var stable:Rect2=app.world.picture.picture_rect()
	var changes:=[0]
	app.emulator.aspect_changed.connect(func(_value):changes[0]+=1)
	for i in range(30):
		app.emulator.update_display_aspect({"display_aspect":16.0/9.0})
		app.emulator.update_display_aspect({"width":640,"height":528,"bytes":PackedByteArray()})
	check(changes[0]==0 and app.world.picture.picture_rect()==stable,"Streaming image-only packets cannot make a wide picture alternate with 4:3")
	app.emulator.update_display_aspect({"display_aspect":4.0/3.0})
	stable=app.world.picture.picture_rect()
	for i in range(30):app.emulator.update_display_aspect({"width":640,"height":480})
	check(changes[0]==1 and app.world.picture.picture_rect()==stable,"4:3 output stays stable on the wide TV despite raster-size changes")
	app.emulator.update_display_aspect({"display_aspect":1.27242})
	stable=app.world.picture.picture_rect()
	var pixels:=PackedByteArray();pixels.resize(16*16*4)
	for i in range(30):app.emulator.update_texture(true,{"bytes":pixels,"width":16,"height":16})
	check(is_equal_approx(app.emulator.display_aspect,1.27242) and app.world.picture.picture_rect()==stable,"Actual image uploads preserve the Wii ratio seen in the Deck trace")
	app.emulator.update_display_aspect({"display_aspect":0.0})
	check(is_equal_approx(app.emulator.display_aspect,4.0/3.0),"Explicitly unspecified core geometry still uses the platform fallback")
	app.queue_free();await process_frame
	print("DISPLAY MODES: ",failures," failures")
	quit(1 if failures else 0)
