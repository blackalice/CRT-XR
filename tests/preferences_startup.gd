extends SceneTree
const UI=preload("res://tests/menu_test_helpers.gd")
const Store = preload("res://scripts/ui/settings_store.gd")
const Startup = preload("res://scripts/ui/startup_status.gd")
const LinuxTracking = preload("res://scripts/tracking/xr_linux_tracking.gd")
var failures := 0
var app
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1
func settle():
	for i in range(4): await process_frame
func a_press(control: Control):
	control.grab_focus()
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	app.handle_settings_gamepad(event)
	event.pressed = false
	app.handle_settings_gamepad(event)
	await settle()
func run():
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	check(app.menu.visible and app.menu.selected_id=="games","Startup selects Choose game in the shared pause menu")
	check(app.menu.CATEGORIES.size()==5,"Settings have five explicit categories")
	UI.page(app,1,1)
	await settle()
	check(app.menu.section_title.text=="Screen fit" and app.menu.selected_row()!=null,"Screen-fit page focuses its first editable row")
	UI.page(app,4,0)
	app.menu.activate()
	check(app.menu.mode=="slot","Saved setup opens with the controller action")
	app.distance = 2.8
	app.world.ambient = .8
	app.world.picture.set_value("gamma",2.1)
	app.save_profile("My warm setup")
	app.distance = 4.1
	app.world.ambient = .2
	app.world.picture.set_value("gamma",2.6)
	app.set_stereo(true)
	app.toggle_settings()
	app.load_profile()
	await settle()
	check(is_equal_approx(app.distance,2.8) and is_equal_approx(app.world.ambient,.8) and is_equal_approx(app.world.picture.values.gamma,2.1),"Named setup restores view, room and picture")
	check(app.stereo and not app.provider is LinuxTracking,"Loading a setup preserves display mode and tracking provider")
	app.undo_profile()
	await settle()
	check(is_equal_approx(app.distance,4.1) and is_equal_approx(app.world.ambient,.2) and is_equal_approx(app.world.picture.values.gamma,2.6),"Undo restores preferences from before setup load")
	app.world.picture.set_value("gamma",2.1)
	if not app.menu.visible: app.toggle_settings()
	app.close_settings()
	var global := ConfigFile.new()
	global.load("user://settings.cfg")
	check(is_equal_approx(global.get_value("picture","gamma"),2.1),"Closing settings automatically persists adjustments")
	var probe := ProjectSettings.globalize_path("res://build/retrocrt-probe.sfc")
	check(app.load_game(probe),"Original diagnostic game loads through the startup flow")
	app.world.picture.set_value("gamma",1.75)
	app.world.picture.set_value("width",.7)
	app.world.picture.mode = 2
	app.distance = 3.8
	app.save_settings()
	global.load("user://settings.cfg")
	check(is_equal_approx(global.get_value("picture","gamma"),2.1) and is_equal_approx(global.get_value("view","distance"),3.8),"Game-specific picture stays separate while view remains global")
	app.emulator.stop()
	check(is_equal_approx(app.world.picture.values.gamma,2.1) and is_equal_approx(app.world.picture.values.width,1),"Stopping a game restores the global picture baseline")
	var moved := "user://renamed-probe.sfc"
	var file := FileAccess.open(moved,FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(probe))
	file.close()
	app.load_game(ProjectSettings.globalize_path(moved))
	check(is_equal_approx(app.world.picture.values.gamma,1.75) and is_equal_approx(app.world.picture.values.width,.7) and app.world.picture.mode==2,"ROM content identity restores preferences after moving or renaming the file")
	var second := FileAccess.get_file_as_bytes(probe)
	second[0x7fd9] = 2 # Original probe with PAL region and a fresh valid checksum.
	second.encode_u32(0x7fdc,0)
	var checksum := 0x1fe
	for byte in second: checksum = (checksum+byte)&0xffff
	second.encode_u16(0x7fdc,checksum^0xffff)
	second.encode_u16(0x7fde,checksum)
	file = FileAccess.open("user://second-probe.sfc",FileAccess.WRITE)
	file.store_buffer(second)
	file.close()
	app.load_game(ProjectSettings.globalize_path("user://second-probe.sfc"))
	check(is_equal_approx(app.world.picture.values.gamma,2.1) and app.emulator.fps<55 and is_equal_approx(app.distance,3.8),"A different PAL cartridge starts with global picture while retaining global view")
	app.world.picture.set_value("gamma",2.5)
	app.load_game(probe)
	check(is_equal_approx(app.world.picture.values.gamma,1.75),"Switching directly between games saves each picture override independently")
	app.set_remember_game_picture(false)
	check(app.active_game_key.is_empty() and is_equal_approx(app.world.picture.values.gamma,2.1),"Disabling per-game picture restores global preferences")
	app.set_remember_game_picture(true)
	check(is_equal_approx(app.world.picture.values.gamma,1.75),"Re-enabling per-game picture restores the saved game preference")
	app.forget_game_picture()
	check(is_equal_approx(app.world.picture.values.gamma,2.1),"A game can return to global picture settings")
	app.close_settings()
	app.emulator.stop()
	check(not app.load_game("user://missing-game.sfc") and app.settings_panel.visible and app.startup_message.contains("Could not open"),"Missing ROM opens actionable recovery without a blank screen")
	var state := Startup.describe(false,"user://missing-card","user://missing.sfc",false,false,"",false,Vector2i(1280,720),false)
	check(state.title=="Last game unavailable" and state.detail.contains("Reconnect"),"Missing library paths retain a reconnect instruction")
	state = Startup.describe(true,"","",true,false,"XR: stale tracking",true,Vector2i(3840,1080),true)
	check(state.title=="Tracking unavailable" and state.detail.contains("held steady") and state.detail.contains("Retry"),"Lost tracking explains the steady view and retry path")
	state = Startup.describe(true,"","",true,true,"LIVE",true,Vector2i(1920,1080),true)
	check(state.title=="Check SBS resolution" and state.detail.contains("Native"),"Gaming Mode resolution mismatch gets explicit Native-resolution guidance")
	var defaults := ConfigFile.new()
	defaults.set_value("view","distance",3.4)
	var invalid := ConfigFile.new()
	invalid.set_value("view","distance","wrong type")
	Store.write("user://invalid-types.cfg",invalid)
	var reader := Store.new()
	check(is_equal_approx(reader.read("user://invalid-types.cfg",defaults).get_value("view","distance"),3.4) and not reader.warning.is_empty(),"Invalid saved value types fall back safely")
	Store.write("user://recovery.cfg",defaults)
	invalid.set_value("view","distance",4.0)
	Store.write("user://recovery.cfg",invalid)
	file = FileAccess.open("user://recovery.cfg",FileAccess.WRITE)
	file.store_string("[broken")
	file.close()
	reader = Store.new()
	check(is_equal_approx(reader.read("user://recovery.cfg",defaults).get_value("view","distance"),3.4) and reader.recovered,"Truncated settings recover the previous valid atomic-write backup")
	app.free()
	quit(1 if failures else 0)
