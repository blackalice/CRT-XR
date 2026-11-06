extends SceneTree
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func start_app():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await process_frame;await process_frame
	app.use_tracking(false)
	return app
func run():
	var app=await start_app()
	app.display_settings.data.defaults.game="standard"
	app.distance=2.2
	app.display_settings.set_preference("games","wide-resume-game","wide")
	app.emulator.system_id="ps2";app.emulator.rom_hash="wide-resume-game"
	app.change_game_preferences(true)
	app.distance=3.7;app.height_offset=.2
	check(app.world.widescreen,"Game selects its widescreen override")
	app.save_settings()
	app.change_game_preferences(false)
	check(not app.world.widescreen,"Leaving the game keeps existing default-TV policy")
	app.save_settings();app.queue_free();await process_frame
	app=await start_app()
	check(app.world.widescreen,"A fresh application boots on the last-used wide TV before Continue")
	check(is_equal_approx(app.distance,3.7) and is_equal_approx(app.height_offset,.2),"Boot restores that TV's viewing distance and height")
	check(app.display_settings.data.defaults.game=="standard","Remembering the last TV does not change the game default")
	var screen_id=app.world.television.get_node("PhosphorSurface").get_instance_id()
	app.emulator.system_id="ps2";app.emulator.rom_hash="wide-resume-game";app.change_game_preferences(true)
	check(app.world.television.get_node("PhosphorSurface").get_instance_id()==screen_id,"Resuming the wide game does not replace or jump between cabinets")
	app.emulator.system_id="snes";app.emulator.rom_hash="classic-game";app.change_game_preferences(true)
	check(not app.world.widescreen,"A different classic game still follows its standard-TV preference")
	app.save_settings();app.queue_free();await process_frame
	app=await start_app()
	check(not app.world.widescreen,"Last-used standard TV also restores on the next boot")
	app.queue_free();await process_frame
	quit(1 if failures else 0)
