extends SceneTree
## Restore immediately after a frame, including the first boot frame. This
## exposes CPU/GPU synchronization defects which plain game switching misses.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Support = preload("res://scripts/emulation/dolphin_support.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var core = ClassDB.instantiate("RetroCore")
	core.set_hardware_rendering(true)
	var saves := OS.get_environment("CRT_XR_GAMECUBE_SAVE")
	Support.stage(saves)
	if not core.load_core(Registry.core_path("gamecube")): print("FAIL core"); quit(1); return
	for key in Registry.SYSTEMS.gamecube.options: core.set_option(key, Registry.SYSTEMS.gamecube.options[key])
	if not core.load_game(OS.get_environment("CRT_XR_GAMECUBE_ROM"), saves): print("FAIL game"); quit(1); return
	for frame in range(300):
		if not core.run_frame(0): print("FAIL frame ", frame); quit(1); return
		var state: PackedByteArray = core.save_state()
		if state.is_empty() or not core.load_state(state): print("FAIL state ", frame); quit(1); return
		if frame % 25 == 0: print("STATE ROUNDTRIP ", frame)
	core.close()
	print("PASS 300 immediate state roundtrips")
	quit()
