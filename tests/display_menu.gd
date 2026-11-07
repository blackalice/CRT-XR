extends SceneTree
const UI=preload("res://tests/menu_test_helpers.gd")
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func shot(app,name: String):
	if DisplayServer.get_name()=="headless": return
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	app.menu_view.get_texture().get_image().save_png("res://build/display-menu-"+name+".png")
func run():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await process_frame;await process_frame
	app.use_tracking(false);app.close_settings()
	check(app.load_game(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")),"Original diagnostic game opens")
	UI.set_value(app,"picture.cabinet",2)
	check(app.world.widescreen,"TV menu creates a wide override for this game")
	check(not app.menu.items.any(func(row): return row.id == "picture.tv_policy" or row.id == "picture.video_policy"), "Editing one game does not mix in global TV policies")
	await shot(app,"game")
	UI.set_value(app,"picture.gamma",1.75)
	UI.set_value(app,"picture.scope",1)
	check(app.display_settings.scope==1,"Scope selector edits platform defaults")
	for section in range(1,6):
		UI.page(app,1,section)
		for i in range(6): await process_frame
		check(app.menu.subtitle.visible and app.menu.subtitle.text.contains("SNES defaults"), "Picture scope remains visible on page %d" % section)
		check(app.menu.items.any(func(row): return row.id == "picture.scope.page.%d" % section), "Scope can be changed on picture page %d" % section)
	await shot(app,"scope")
	UI.set_value(app,"picture.gamma",2.1)
	UI.set_value(app,"picture.scope",0)
	check(is_equal_approx(app.world.picture.values.gamma,1.75),"Scope changes restore the game's existing override")
	UI.reset(app,"picture.gamma")
	check(is_equal_approx(app.world.picture.values.gamma,2.1),"Controller reset inherits the platform value")
	UI.set_value(app,"picture.scope",1);UI.set_value(app,"picture.cabinet",1)
	check(not app.world.widescreen,"Platform TV changes can be previewed")
	app.close_settings()
	check(app.world.widescreen and app.display_settings.scope==0,"Closing settings restores this game's TV and scope")
	UI.select(app,"view.distance");await shot(app,"placement")
	app.emulator.stop()
	if app.video.available():
		check(app.play_video(ProjectSettings.globalize_path("res://build/video-fixtures/h264_aac_25.mp4")),"Widescreen video opens")
		UI.select(app,"picture.cabinet")
		check(app.display_settings.kind=="video" and app.world.widescreen,"Video TV preferences have a separate context")
		await shot(app,"video")
		app.stop_video()
	UI.set_value(app,"picture.activity",1)
	check(app.display_settings.kind=="video","Video defaults can be edited without playback")
	app.close_settings()
	check(app.display_settings.kind=="game","Closing idle video-default editing restores the test-signal context")
	app.queue_free();await process_frame;quit(1 if failures else 0)
