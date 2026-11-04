extends SceneTree
## Real-core test using a caller-supplied game and an isolated writable folder.
## Does not open the player's settings or saves.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Support = preload("res://scripts/emulation/dolphin_support.gd")
func _initialize(): call_deferred("run")
func fail(message: String):
	print("FAIL: ", message)
	quit(1)
func run():
	var rom := OS.get_environment("CRT_XR_GAMECUBE_ROM")
	var saves := OS.get_environment("CRT_XR_GAMECUBE_SAVE")
	if rom.is_empty() or saves.is_empty(): fail("Set an existing ROM and an isolated test save directory"); return
	if Registry.identify(rom) != "gamecube": fail("Game is not identified as GameCube"); return
	if Support.stage(saves) != OK: fail("Dolphin Sys data cannot be staged"); return
	var core = ClassDB.instantiate("RetroCore")
	core.set_hardware_rendering(true)
	if not core.load_core(Registry.core_path("gamecube")): fail(str(core.last_error())); return
	for key in Registry.SYSTEMS.gamecube.options: core.set_option(key, Registry.SYSTEMS.gamecube.options[key])
	if not core.load_game(rom, saves): fail(str(core.last_error())); return
	print("PASS: Real Dolphin core loads ", rom.get_file())
	var pictures := 0
	var audio_frames := 0
	var changed := 0
	var previous := PackedByteArray()
	var timings: Array[int] = []
	for frame in range(1200):
		var buttons := (1 << 3) if frame % 180 == 120 else ((1 << 8) if frame > 300 and frame % 120 < 2 else 0)
		if not core.run_frame(buttons): fail(str(core.last_error())); core.close(); return
		var info: Dictionary = core.info()
		audio_frames += int(info.audio_frames)
		if info.video_changed: pictures += 1
		if frame >= 300: timings.append(int(info.step_usec))
		if frame % 120 == 0 and info.width > 0:
			var pixels: PackedByteArray = core.frame()
			if pixels != previous: changed += 1
			previous = pixels
		if frame % 300 == 0: print("DOLPHIN_FRAME ",frame," ",JSON.stringify(info))
	var info: Dictionary = core.info()
	if pictures == 0 or changed < 2 or audio_frames == 0: fail("Expected changing video and audio"); core.close(); return
	var image_path := OS.get_environment("CRT_XR_GAMECUBE_IMAGE")
	if not image_path.is_empty(): Image.create_from_data(info.width,info.height,false,Image.FORMAT_RGBA8,core.frame()).save_png(image_path)
	var state: PackedByteArray = core.save_state()
	if state.is_empty() or not core.load_state(state): fail("Dolphin save-state round trip failed: " + str(core.last_error())); core.close(); return
	if not core.run_frame(0) or not core.reset(): fail("Dolphin restore/reset failed"); core.close(); return
	core.close_game()
	core.close()
	timings.sort()
	var total := 0
	for value in timings: total += value
	print("DOLPHIN_RESULT ",JSON.stringify({"rom":rom.get_file(),"pictures":pictures,"changes":changed,"audio_frames":audio_frames,"mean_usec":float(total)/timings.size(),"p95_usec":timings[int(timings.size()*0.95)],"max_usec":timings[-1],"state_bytes":state.size()}))
	print("PASS: Real Dolphin video, audio, state restore, reset and unload")
	quit()
