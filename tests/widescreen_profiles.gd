extends SceneTree
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	if ok: print("PASS: ",message)
	else: push_error(message); failures+=1
func run():
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	app.video_own_picture=true
	app.set_widescreen(false)
	app.world.picture.set_value("width",.81)
	app.screen_curvature=.24
	app.set_widescreen(true)
	app.world.picture.set_value("width",.94)
	app.screen_curvature=.38
	app.world.picture.fit_mode=1
	app.set_widescreen(false)
	check(is_equal_approx(app.world.picture.values.width,.81) and is_equal_approx(app.screen_curvature,.24),"Standard game fitting and CRT settings restore independently")
	app.change_game_preferences(true,app.VIDEO_PROFILE)
	app.world.picture.set_value("width",.73)
	app.set_widescreen(true)
	app.world.picture.set_value("width",.88)
	app.set_widescreen(false)
	check(is_equal_approx(app.world.picture.values.width,.73),"Standard video profile survives switching cabinets")
	app.set_widescreen(true)
	check(is_equal_approx(app.world.picture.values.width,.88),"Wide video profile restores independently")
	app.change_game_preferences(false,app.VIDEO_PROFILE)
	check(is_equal_approx(app.world.picture.values.width,.94) and is_equal_approx(app.screen_curvature,.38),"Leaving video restores the wide game picture")
	check(app.world.picture.fit_mode==1,"Fit mode is cabinet-specific")
	app.save_settings()
	var saved=app.SettingsStore.new().read("user://settings.cfg")
	check(saved.get_value("room","widescreen",false),"Cabinet choice persists")
	check(saved.get_value("screen_profiles","pictures",{}).size()==2,"Both cabinet baselines persist")
	app.set_widescreen(false)
	app.apply_settings(saved)
	app.picture_baseline=app.capture_settings()
	app.set_widescreen(false)
	check(is_equal_approx(app.world.picture.values.width,.81),"Standard profile survives settings reload")
	app.set_widescreen(true)
	check(is_equal_approx(app.world.picture.values.width,.94),"Wide profile survives settings reload")
	app.remember_game_picture=true
	app.emulator.rom_hash="widescreen-profile-fixture"
	app.change_game_preferences(true)
	app.world.picture.set_value("width",.91)
	app.set_widescreen(false)
	app.world.picture.set_value("width",.78)
	app.set_widescreen(true)
	check(is_equal_approx(app.world.picture.values.width,.91),"Per-game override is separate on wide")
	app.set_widescreen(false)
	check(is_equal_approx(app.world.picture.values.width,.78),"Per-game override is separate on standard")
	app.change_game_preferences(false)
	check(is_equal_approx(app.world.picture.values.width,.81),"Leaving a game restores the current cabinet baseline")
	var pages=app.menu.catalog.pages(1)
	check(not pages.is_empty(),"Screen settings menu builds with fitting choices")
	quit(1 if failures else 0)
