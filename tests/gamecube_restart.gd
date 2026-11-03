extends SceneTree
## Choosing a second GameCube game starts a fresh process (Dolphin cannot start
## twice in one). Run with user arguments "-- --test-restart": the first process
## plays CRT_XR_GC_A, then picks CRT_XR_GC_B from the menu and must restart. The
## restarted process (it carries --rom) checks that B is playing with the menu closed.
## Needs a display.
func _initialize() -> void: call_deferred("run")

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(30)
	if "--rom" in args:
		await frames(400)
		var wanted: String = args[args.find("--rom") + 1]
		var ok: bool = app.emulator.loaded and app.emulator.rom_path == wanted and not app.settings_panel.visible and not app.emulator.paused
		print("%s RESTARTED process: %s loaded=%s menu_open=%s paused=%s card=%s" % ["PASS" if ok else "FAIL", wanted.get_file(), app.emulator.loaded, app.settings_panel.visible, app.emulator.paused, "up" if not app.loading_path.is_empty() else "down"])
		quit(0 if ok else 1)
		return
	var a := OS.get_environment("CRT_XR_GC_A")
	var b := OS.get_environment("CRT_XR_GC_B")
	if not app.load_game(a): print("FAIL first game"); quit(1); return
	await frames(200)
	print("FIRST process playing ", app.emulator.rom_path.get_file(), " pid ", OS.get_process_id())
	app.menu.games.launch_game(b, false)
	# A restart ends this process; reaching the end of the wait means it did not.
	await frames(900)
	print("FAIL no restart happened")
	quit(1)
