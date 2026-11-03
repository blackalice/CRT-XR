extends SceneTree
## Which way of changing GameCube game survives inside one process?
## CRT_XR_GC_MODE: "swap" keeps the loaded core and replaces only the game;
## "reopen" closes the core and opens it again (what the app did). Needs a display.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Support = preload("res://scripts/emulation/dolphin_support.gd")
func _initialize(): call_deferred("run")
func run():
	var games: PackedStringArray = OS.get_environment("CRT_XR_GC_GAMES").split(";", false)
	var saves := OS.get_environment("CRT_XR_GAMECUBE_SAVE")
	var mode := OS.get_environment("CRT_XR_GC_MODE")
	Support.stage(saves)
	var core = null
	for round in range(2):
		for game in games:
			if core == null or mode.begins_with("reopen"):
				if core != null: core.close()
				core = ClassDB.instantiate("RetroCore")
				core.set_hardware_rendering(true)
				if not core.load_core(Registry.core_path("gamecube")): print("FAIL core ", core.last_error()); quit(1); return
			for key in Registry.SYSTEMS.gamecube.options: core.set_option(key, Registry.SYSTEMS.gamecube.options[key])
			if not core.load_game(game, saves): print("FAIL load ", game.get_file(), " ", core.last_error()); quit(1); return
			var ok := true
			for frame in range(int(OS.get_environment("CRT_XR_GC_FRAMES")) if not OS.get_environment("CRT_XR_GC_FRAMES").is_empty() else 240):
				if not core.run_frame(0): ok = false; break
			print("%s %s round %d %s" % ["PASS" if ok else "FAIL", mode, round, game.get_file()])
			if mode.contains("state"): print("saved state bytes ", core.save_state().size())
			if mode.contains("ram"): core.save_ram()
			core.close_game()
	core.close()
	print("RELOAD COMPLETE ", mode)
	quit()
