extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func game(app,system: String,id: String):
	app.emulator.system_id=system;app.emulator.rom_hash=id;app.change_game_preferences(true)
func run():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await process_frame;await process_frame;app.use_tracking(false)
	var prefs=app.display_settings
	for system in app.emulator.Registry.DEFINITIONS:
		game(app,system,"default-"+system)
		var expected:=0
		check(prefs.display_choice()==expected,system+" launches with "+prefs.DISPLAY_CHOICES[expected])
	var legacy:=ConfigFile.new()
	legacy.set_value("display_profiles","data",{"version":1,"defaults":{"game":"wide","video":"wide"},
		"platforms":{"wii":{"screen":"wide"},"ps2":{"screen":"standard"}},
		"games":{"kept-game":{"screen":"standard"}},"videos":{},
		"views":{"desktop.standard":{"distance":2.1,"height_offset":.1,"tv_scale":.9}},
		"pictures":{"game.wide.platform.ps2":{"picture.width":.8,"picture.keep_aspect":true},
			"game.standard.content.kept-game":{"picture.keep_aspect":true,"picture.fit_mode":1}}})
	app.restore_settings(legacy)
	check(prefs.preferred_screen("game","wii","")=="wide" and prefs.preferred_screen("game","ps2","")=="standard","Loading existing settings preserves console preferences")
	check(prefs.data.pictures["game.wide.platform.ps2"]["picture.width"]==.8,"Migration preserves other platform picture adjustments")
	check(prefs.data.views["desktop.standard"].distance==2.1 and prefs.data.defaults.video=="wide","Viewing profiles and separate video default survive")
	game(app,"psp","kept-game")
	check(prefs.display_choice()==1,"Explicit per-game TV and Crop override survives the defaults update")
	game(app,"psp","explicit-fit");prefs.choose_display(3)
	prefs.reset_platform_display_defaults();prefs.resolve_picture()
	check(prefs.display_choice()==3,"Explicit Fit remains an override when platform defaults are reapplied")
	prefs.set_platform_screen("wii",2)
	var saved:ConfigFile=app.capture_settings();app.restore_settings(saved)
	check(prefs.preferred_screen("game","wii","")=="wide","Later platform edits survive reload rather than being reset on every read")
	app.settings_panel.show();app.reset_all_options()
	for system in app.emulator.Registry.DEFINITIONS:
		game(app,system,"reset-"+system)
		check(prefs.display_choice()==0,"Factory reset restores display defaults for "+system)
	app.queue_free();await process_frame
	print("PLATFORM DISPLAY DEFAULTS: ",failures," failures")
	quit(1 if failures else 0)
