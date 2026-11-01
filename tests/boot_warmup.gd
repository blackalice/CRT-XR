extends SceneTree
var app
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func settle() -> void:
	for i in range(8): await process_frame
func stage() -> void:
	app.stop_boot_sound()
	app.power_on.enabled = true; app.power_on.reduced_motion = false
	app.power_on.begin(true); app.power_on.set_process(false)
	app.menu.begin_boot(); app.menu.boot.set_process(false)
	app.menu_boot_pending = true
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await settle()
	app.set_process(false)
	app.menu_reduced_motion = false; app.menu_high_contrast = false
	stage()
	await settle()
	app._process(0.0)
	check(app.menu_boot_pending and not app.menu.boot.is_processing() and app.menu.boot.elapsed == 0.0, "Logo timeline waits for the CRT warm-up")
	check(not is_instance_valid(app.boot_audio) or not app.boot_audio.playing, "Boot cue stays synchronized with the held logo")
	var motion = app.menu.backdrop.material.get_shader_parameter("motion")
	check((motion == null or motion == 1.0) and app.menu.backdrop.material.get_shader_parameter("boot_settle") == 0.0, "Planet and stars keep native motion while the boot camera holds")
	for diamond in app.menu.boot.diamonds: check(diamond.modulate.a == 1.0, "Diamonds remain still on the first frame")
	app.power_on._process(0.69); app._process(0.0)
	check(app.menu_boot_pending and app.menu.boot.elapsed == 0.0, "Sequence stays held through the last part of tube warm-up")
	app.power_on._process(0.02); app._process(0.0)
	check(not app.menu_boot_pending and app.menu.boot.is_processing() and app.boot_audio.playing, "Completed CRT reveal releases logo and boot cue together")
	app.menu.boot.set_process(false); app.menu.boot._process(0.05)
	check(app.menu.boot.elapsed > 0.0 and app.menu.boot.diamonds[0].modulate.a < 1.0, "Diamond sequence begins only after warm-up completes")
	app.menu.boot.finish(); await settle()
	stage(); await settle()
	app.menu.boot.finish(); await settle()
	app.power_on.set_progress(1.0); app._process(0.0)
	check(not app.menu_boot_pending and not app.boot_audio.playing, "Skipping during warm-up never starts a delayed boot cue")
	stage(); await settle()
	app.power_on.enabled = false; app.power_on.apply(); app._process(0.0)
	check(not app.menu_boot_pending and app.menu.boot.is_processing(), "Disabled CRT animation releases boot immediately")
	app.menu.boot.finish(); await settle()
	app.menu_on_tv = false; stage(); await settle()
	app.power_on.started = false; app._process(0.0)
	check(app.power_on.started and app.menu_boot_pending, "Floating menus also start the CRT reveal instead of waiting indefinitely")
	app.menu.boot.finish(); app.free()
	print("BOOT WARMUP: ", failures, " failures")
	quit(1 if failures else 0)
