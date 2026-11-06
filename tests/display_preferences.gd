extends SceneTree
## Full application transitions, inheritance and persistence.
var failures:=0
var app
var prefs
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	if ok: print("PASS: ",message)
	else: push_error(message); failures+=1
func width(value: float): app.world.picture.set_value("width",value)
func equals(value: float) -> bool: return is_equal_approx(app.world.picture.values.width,value)
func game(system: String,id: String):
	app.emulator.system_id=system; app.emulator.rom_hash=id
	app.change_game_preferences(true)
func run():
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await process_frame; await process_frame
	app.set_process(false);prefs=app.display_settings
	check(app.scene_msaa==0 and app.views.all(func(view): return view.msaa_3d==Viewport.MSAA_DISABLED),"Room MSAA defaults off in both eyes")
	app.scene_msaa=1;app.apply_scene_msaa()
	check(app.views.all(func(view): return view.msaa_3d==Viewport.MSAA_2X),"Optional MSAA changes both eyes")
	app.scene_msaa=0;app.apply_scene_msaa()
	check(prefs.preferred_screen("game","psp","")=="wide" and prefs.preferred_screen("game","snes","")=="standard","Native wide platforms start wide; classic platforms remain standard")
	app.set_widescreen(false);width(.81);app.distance=2.0
	app.set_widescreen(true);width(.94);app.distance=3.4
	app.set_widescreen(false)
	check(equals(.81) and is_equal_approx(app.distance,2.0),"Standard TV restores its picture and distance")
	app.set_widescreen(true)
	check(equals(.94) and is_equal_approx(app.distance,3.4),"Wide TV restores its picture and distance")
	app.set_widescreen(false)
	game("psp","game-a")
	check(app.world.widescreen,"Platform preference selects wide on launch")
	width(.89);app.world.picture.aspect_override=2
	game("psp","game-b")
	check(equals(.94) and app.world.picture.aspect_override==0,"Another game inherits wide defaults")
	game("psp","game-a")
	check(equals(.89) and app.world.picture.aspect_override==2,"Game fitting and anamorphic aspect restore")
	app.set_widescreen(false);width(.76)
	game("psp","game-b");game("psp","game-a")
	check(not app.world.widescreen and equals(.76),"Game TV override wins over its platform")
	prefs.inherit_screen()
	check(app.world.widescreen and equals(.89),"Clearing TV override restores the platform TV")
	prefs.set_scope(1);width(.92);prefs.set_scope(0)
	check(equals(.89),"Game picture wins over edited platform defaults")
	prefs.reset_field("picture.width")
	check(equals(.92),"Resetting a field inherits the current platform value")
	game("psp","game-b")
	check(equals(.92),"Other games follow changed platform defaults")
	prefs.set_scope(2);width(.97);prefs.set_scope(0)
	check(equals(.92),"Platform picture wins over TV defaults")
	game("snes","classic-a")
	check(not app.world.widescreen and equals(.81),"Classic game uses independent standard defaults")
	app.video.path="res://build/fixture-movie-a.mkv"
	app.change_game_preferences(true,app.VIDEO_PROFILE)
	var video_default: float=prefs.base["picture.width"]
	check(app.world.widescreen and equals(video_default),"Videos use wide with independent picture defaults")
	width(.88);app.world.picture.fit_mode=1
	app.video.path="res://build/fixture-movie-b.mkv";app.change_game_preferences(true,app.VIDEO_PROFILE)
	check(equals(video_default) and app.world.picture.fit_mode==0,"A second video inherits defaults without movie-specific crop")
	app.video.path="res://build/fixture-movie-a.mkv";app.change_game_preferences(true,app.VIDEO_PROFILE)
	check(equals(.88) and app.world.picture.fit_mode==1,"Video-specific fitting restores")
	app.change_game_preferences(false,app.VIDEO_PROFILE)
	check(not app.world.widescreen and equals(.81),"Stopping returns to the default game TV")
	app.save_settings()
	var config: ConfigFile=app.SettingsStore.new().read("user://settings.cfg")
	check(config.get_value("display_profiles","data",{}).pictures.has("game.wide.platform.psp"),"Layered picture overrides persist")
	app.apply_settings(config);prefs.base=prefs.live_picture();prefs.resolve_picture()
	game("psp","game-a")
	check(app.world.widescreen and equals(.92),"Inherited overrides survive reload")
	app.emulator.update_display_aspect({"display_aspect":16.0/9.0})
	check(is_equal_approx(app.emulator.display_aspect,16.0/9.0),"Core-reported aspect reaches the session")
	app.video.info={"display_aspect":2.39};app.video.set_style(0)
	check(is_equal_approx(app.video.display_aspect(),2.39),"Cinema aspect survives the video session")
	app.video.set_style(1)
	check(is_equal_approx(app.video.display_aspect(),4.0/3.0),"Legacy broadcast styles retain 4:3")
	for category in range(11): check(not app.menu.catalog.pages(category).is_empty(),"Settings category %d builds" % category)
	check(not app.rooms.room_only().has_section_key("room","widescreen"),"Room presets exclude TV selection")
	app.change_game_preferences(false)
	app.queue_free();await process_frame
	quit(1 if failures else 0)
