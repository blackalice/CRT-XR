extends SceneTree
## Run against an exported PCK with --script <absolute path to this file> -- <probe folder>.
## Generate the original diagnostic programs with tests/make_*probe*.py first.
var failures := 0

func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failures += 1

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Pass the folder containing crt-xr-probe diagnostic programs after --")
		quit(2)
		return
	var base := OS.get_executable_path().get_base_dir()
	for asset in ["optimised/cabinet.scn", "wood-table/table.scn", "room-bake/table_contact_albedo.res", "ao/tvfront_ao.res", "ao/tvback_ao.res"]:
		check(ResourceLoader.load(base.path_join("assets/" + asset)) != null, "Packaged resource loads: " + asset)
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.vcr_sounds.enabled = false
	app.vcr_sounds.stop_all()
	if is_instance_valid(app.sbs_prompt): app.sbs_prompt.desktop_ready.emit()
	await process_frame
	await process_frame
	check(is_instance_valid(app.world), "Exported scene starts")
	check(app.world.screen_light.lights.all(func(light): return not light.shadow_enabled), "Screen glow avoids live shadow passes")
	app.close_settings()
	app.use_tracking(false)
	var session = app.emulator
	session.set_process(false)
	for extension in ["sfc", "nes", "md", "sms", "gg", "gb", "gba", "pce", "a26"]:
		var loaded: bool = session.load_rom(arguments[0].path_join("crt-xr-probe." + extension))
		check(loaded, "Packaged core loads " + extension)
		if not loaded: continue
		var executed := true
		for frame in range(90): executed = session.core.run_frame(0) and executed
		var info: Dictionary = session.core.info()
		check(executed and info.width > 0 and info.height > 0, "Packaged core supplies frames: " + extension)
	app.queue_free()
	await process_frame
	print("PACKAGED SMOKE: ", failures, " failures")
	quit(0 if failures == 0 else 1)
