extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func run():
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); app.use_tracking(false)
	var original := ConfigFile.new()
	check(original.load("res://tests/fixtures/deck_showcase.cfg")==OK,"Captured Deck reference loads")
	var actual: ConfigFile=app.capture_settings()
	var mismatch: Array[String]=[]
	for section in original.get_sections():
		for key in original.get_section_keys(section):
			if section=="tracking" or (section=="view" and key=="vertical_fov"): continue
			var expected=original.get_value(section,key)
			var found=actual.get_value(section,key)
			var equal: bool=absf(float(found)-float(expected))<.000001 if expected is float or expected is int else found==expected
			if not equal: mismatch.append(section+"/"+key)
	check(mismatch.is_empty(),"Fresh application reproduces the Deck setup: "+str(mismatch))
	check(not app.metrics_visible and app.diagnostics.all(func(label): return not label.visible),"Metrics are off from the first frame")
	check(app.vertical_fov==50.0,"Desktop preview keeps its platform field of view")
	app.metrics_visible=true
	check(app.diagnostics.all(func(label): return label.visible),"Metrics switch updates both eye overlays")
	check(app.save_settings(),"Metrics preference saves")
	var saved := ConfigFile.new();saved.load("user://settings.cfg")
	check(saved.get_value("preferences","metrics_visible",false),"Explicit metrics choice persists")
	app.metrics_visible=false; app.apply_settings(saved)
	check(app.metrics_visible,"Metrics choice reloads")
	app.distance=2.2; app.world.ambient=.8; app.emulator.tv_audio.room_amount=0; app.scanlines=0
	app.load_showcase_setup()
	check(is_equal_approx(app.distance,3.284008) and is_equal_approx(app.world.ambient,.05) and is_equal_approx(app.emulator.tv_audio.room_amount,.18) and is_equal_approx(app.scanlines,.7),"Built-in setup restores placement, room, audio and CRT")
	check(not app.metrics_visible and app.profile_undo!=null,"Showcase hides metrics and retains an undo snapshot")
	app.undo_profile()
	check(is_equal_approx(app.distance,2.2) and is_equal_approx(app.world.ambient,.8) and app.metrics_visible,"Undo restores the complete previous setup")
	app.world.picture.set_value("width",.72)
	var position: float=app.distance
	var room: float=app.world.ambient
	app.apply_picture_preset("showcase")
	check(app.world.picture.mode==2 and is_equal_approx(app.world.picture.values.phase_noise,.38) and is_equal_approx(app.world.picture.values.signal_motion,.95) and is_equal_approx(app.phosphor_mask,.5),"Showcase picture preset matches the tuned PAL signal")
	check(is_equal_approx(app.world.picture.values.width,.72) and app.distance==position and app.world.ambient==room,"Picture preset preserves screen fit and room/placement")
	app.apply_picture_preset("ntsc")
	check(app.world.picture.mode==1 and app.scanlines>=.6 and app.world.picture.values.phase_noise>=.2,"Other composite presets are visibly stronger")
	app.apply_picture_preset("clean")
	check(app.scanlines==0 and app.phosphor_mask==0 and app.phosphor_glow==0 and app.world.picture.values.signal_motion==0,"Clean source remains an unprocessed reference")
	app.menu.open_settings(); app.menu.category=4; app.menu.subsection=0; app.menu.render()
	check(app.menu.items.size()==4 and app.menu.items[0].id=="slot.showcase","Built-in setup leaves all three writable slots available")
	app.metrics_visible=true; app.reset_all_options()
	check(not app.metrics_visible and is_equal_approx(app.height_offset,-.15) and app.world.picture.mode==2 and is_equal_approx(app.world.picture.values.phase_noise,.38),"Reset all uses the same Showcase defaults and clean HUD")
	app.free()
	for i in range(3): await process_frame
	print("SHOWCASE DEFAULT CHECKS COMPLETE: ",failures," failures")
	quit.call_deferred(1 if failures else 0)
