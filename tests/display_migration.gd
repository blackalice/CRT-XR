extends SceneTree
const Store=preload("res://scripts/ui/settings_store.gd")
const Showcase=preload("res://scripts/presets/showcase.gd")
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func make_app():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await process_frame;await process_frame;app.set_process(false)
	return app
func run():
	var legacy:=Showcase.config()
	legacy.set_value("picture","width",.83);legacy.set_value("view","distance",2.4)
	legacy.set_value("preferences","per_game_picture",true)
	legacy.set_value("welcome","done",true)
	var wide:=Showcase.config();wide.set_value("picture","width",.96)
	legacy.set_value("screen_profiles","pictures",{"standard":legacy.encode_to_text(),"wide":wide.encode_to_text()})
	Store.write("user://settings.cfg",legacy)
	var game:=ConfigFile.new();game.set_value("picture","width",.71);game.set_value("picture","gamma",1.7);game.set_value("view","distance",.1)
	Store.write("user://games/legacy-game.cfg",game)
	game.set_value("picture","width",.79);Store.write("user://games/legacy-game-wide.cfg",game)
	var video:=ConfigFile.new();video.set_value("picture","width",.90);video.set_value("picture","connection",2)
	Store.write("user://games/video-wide.cfg",video)
	var app=await make_app();var prefs=app.display_settings
	check(is_equal_approx(app.distance,2.4) and not app.world.widescreen,"Legacy current TV and distance survive migration")
	app.emulator.system_id="dreamcast";app.emulator.rom_hash="legacy-game";app.change_game_preferences(true)
	check(is_equal_approx(app.world.picture.values.width,.71) and is_equal_approx(app.world.picture.values.gamma,1.7),"Legacy standard game file migrates")
	check(is_equal_approx(app.distance,2.4),"Game picture migration excludes hardware placement")
	app.set_widescreen(true)
	check(is_equal_approx(app.world.picture.values.width,.79),"Legacy wide game file migrates independently")
	var xr_distance: float=app.distance
	app.use_tracking(false);app.distance=4.2;prefs.save_view()
	app.use_tracking(true)
	check(is_equal_approx(app.distance,xr_distance),"XR and fixed view retain independent distances")
	app.use_tracking(false)
	check(is_equal_approx(app.distance,4.2),"Returning to fixed view restores its distance")
	app.video.path="res://build/migration-movie.mkv";app.change_game_preferences(true,app.VIDEO_PROFILE)
	check(is_equal_approx(app.world.picture.values.width,.90) and app.world.picture.mode==2,"Legacy video-wide picture becomes video TV defaults")
	app.world.picture.set_value("width",.86);prefs.commit();app.save_settings()
	var original:=FileAccess.get_file_as_string("user://games/legacy-game.cfg")
	app.queue_free();await process_frame
	app=await make_app();prefs=app.display_settings
	check(not app.world.widescreen and is_equal_approx(app.world.picture.values.width,.83),"Restart restores game defaults rather than the last programme's picture")
	app.emulator.system_id="dreamcast";app.emulator.rom_hash="legacy-game";app.change_game_preferences(true)
	check(app.world.widescreen and is_equal_approx(app.world.picture.values.width,.79),"Migrated game TV and picture survive a real restart")
	check(FileAccess.get_file_as_string("user://games/legacy-game.cfg")==original,"Migration preserves the original game settings file")
	app.video.path="res://build/migration-movie.mkv";app.change_game_preferences(true,app.VIDEO_PROFILE)
	check(is_equal_approx(app.world.picture.values.width,.86),"Per-video fitting survives restart")
	prefs.data.pictures[prefs.target_key()]={"picture.width":"bad","picture.gamma":NAN,"crt.scanlines":12}
	prefs.resolve_picture()
	check(is_finite(app.world.picture.values.gamma) and app.scanlines<=.7,"Invalid picture fields are ignored or clamped")
	prefs.data.views[prefs.device_id()+".wide"]="bad";prefs.restore_view()
	check(is_finite(app.distance) and app.distance>=1.2 and app.distance<=5,"Malformed viewing profiles recover safely")
	app.settings_panel.show();app.reset_all_options()
	app.change_game_preferences(false)
	app.video.path="res://build/migration-movie.mkv";app.change_game_preferences(true,app.VIDEO_PROFILE)
	check(is_equal_approx(app.world.picture.values.width,float(Showcase.config().get_value("picture","width"))) and app.world.picture.mode==3,"Factory reset does not reimport legacy video settings")
	app.queue_free();await process_frame;quit(1 if failures else 0)
