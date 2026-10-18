extends SceneTree
const LinuxTracking=preload("res://scripts/tracking/xr_linux_tracking.gd")
const Setup=preload("res://scripts/ui/windows_setup.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for size in [Vector2i(3840,1080),Vector2i(5120,1440),Vector2i(3840,1200)]: assert(Setup.usable_sbs(size))
	for size in [Vector2i.ZERO,Vector2i(1920,1080),Vector2i(1280,720),Vector2i(3839,1080),Vector2i(18000,1080)]: assert(not Setup.usable_sbs(size))
	var setup=Setup.new()
	root.add_child(setup)
	assert(setup.selected_row==1 and not setup.armed)
	var accept=InputEventJoypadButton.new();accept.button_index=JOY_BUTTON_A;accept.pressed=true
	setup.elapsed=0.0
	setup._input(accept)
	assert(not setup.armed)
	var up=InputEventJoypadButton.new();up.button_index=JOY_BUTTON_DPAD_UP;up.pressed=true
	setup._input(up); setup._input(up)
	assert(setup.selected_row==0)
	var down=InputEventJoypadButton.new();down.button_index=JOY_BUTTON_DPAD_DOWN;down.pressed=true
	setup._input(down); setup._input(down)
	assert(setup.selected_row==2)
	var results=[]
	setup.desktop_ready.connect(func(): results.append("desktop"))
	setup.elapsed=1.0
	setup._input(accept); setup._input(accept)
	assert(results==["desktop"] and setup.proceeding and not setup.armed)
	setup.free()
	if OS.get_name()=="Windows" and "--windows-xr" in OS.get_cmdline_user_args():
		var app=load("res://scenes/main.tscn").instantiate()
		root.add_child(app)
		assert(is_instance_valid(app.sbs_prompt) and not is_instance_valid(app.world))
		app.sbs_prompt.desktop_ready.emit()
		for i in range(4): await process_frame
		assert(app.windows_fixed_start and not app.stereo and is_instance_valid(app.world))
		assert(not app.provider is LinuxTracking)
		app.queue_free()
		await process_frame
	print("PASS: Windows setup SBS modes, input guard, focus boundaries, desktop fallback and single transition")
	quit()
