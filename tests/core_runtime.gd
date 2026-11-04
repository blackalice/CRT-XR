extends SceneTree
## Real-core boot test for any hardware or software core, using a caller-supplied
## game and an isolated writable folder. Does not open the player's settings or saves.
## CRT_XR_TEST_ROM, CRT_XR_TEST_SAVE; optional CRT_XR_TEST_FRAMES (default 1800),
## CRT_XR_TEST_IMAGE (a PNG of the last picture), CRT_XR_TEST_STATE=0 to skip the
## save-state round trip.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const DolphinSupport = preload("res://scripts/emulation/dolphin_support.gd")
const CoreData = preload("res://scripts/emulation/core_data.gd")
const StateStore = preload("res://scripts/emulation/state_store.gd")
func _initialize(): call_deferred("run")
func fail(message: String):
	printerr("FAIL: ", message)
	quit(1)
## CRT_XR_TEST_ROM may list several games separated by ";": each runs in turn
## in this one process, as a play session switching games would.
func run():
	var roms := OS.get_environment("CRT_XR_TEST_ROM").split(";", false)
	var saves := OS.get_environment("CRT_XR_TEST_SAVE")
	if roms.is_empty() or saves.is_empty(): fail("Set an existing ROM and an isolated test save directory"); return
	for index in roms.size():
		if not run_one(roms[index], saves.path_join(str(index)) if roms.size() > 1 else saves): return
	quit()

func run_one(rom: String, saves: String) -> bool:
	var frames := int(OS.get_environment("CRT_XR_TEST_FRAMES")) if not OS.get_environment("CRT_XR_TEST_FRAMES").is_empty() else 1800
	if rom.is_empty() or saves.is_empty(): fail("Set an existing ROM and an isolated test save directory"); return false
	Registry.library_root = rom.get_base_dir().get_base_dir()
	var system := Registry.identify(rom)
	if system.is_empty(): fail("Game is not identified: " + rom); return false
	var spec: Dictionary = Registry.SYSTEMS[system]
	print("SYSTEM ", system)
	DirAccess.make_dir_recursive_absolute(saves)
	if not Registry.bios_satisfied(system): fail("BIOS missing for " + system); return false
	Registry.stage_bios(system, saves)
	if spec.core == "dolphin" and DolphinSupport.stage(saves) != OK: fail("Dolphin Sys data cannot be staged"); return false
	if CoreData.stage(spec, saves) != OK: fail("Core data cannot be staged"); return false
	var core = ClassDB.instantiate("RetroCore")
	core.set_hardware_rendering(spec.get("hardware", false))
	core.set_destroy_context_first(spec.get("context_first", false))
	if not core.load_core(Registry.core_path(system)): fail(str(core.last_error())); return false
	if spec.has("controller"): core.set_controller(spec.controller)
	for key in spec.get("options", {}): core.set_option(key, spec.options[key])
	if spec.has("bios_option"): core.set_option(spec.bios_option, Registry.first_bios(system))
	# CRT_XR_TEST_OPTIONS="key=value;key=value" overrides options for an experiment.
	for pair in OS.get_environment("CRT_XR_TEST_OPTIONS").split(";", false):
		var parts := pair.split("=", true, 1)
		if parts.size() == 2: core.set_option(parts[0], parts[1]); print("OPTION ", parts[0], "=", parts[1])
	var started := Time.get_ticks_msec()
	if not core.load_game(rom, saves): fail(str(core.last_error())); return false
	print("PASS: Real ", spec.core, " core loads ", rom.get_file(), " in ", Time.get_ticks_msec() - started, " ms")
	# CRT_XR_TEST_CLOSE_AFTER=N closes the game after N frames, as quitting during a
	# boot does (PPSSPP is still loading for its first second or so).
	var close_after := OS.get_environment("CRT_XR_TEST_CLOSE_AFTER")
	if not close_after.is_empty():
		for frame in range(int(close_after)):
			if not core.run_frame(0): fail(str(core.last_error())); return false
		core.close_game()
		core.close()
		print("PASS: Closed ", rom.get_file(), " after ", close_after, " frames")
		return true
	# CRT_XR_TEST_RESUME: a resume save (.rst) to restore after 120 frames, so the
	# measurement covers that scene (an in-race save, say) rather than the intro.
	var resume := OS.get_environment("CRT_XR_TEST_RESUME")
	if not resume.is_empty():
		var envelope := StateStore.read_state(resume)
		if envelope.is_empty(): fail("Resume save unreadable: " + resume); return false
		for frame in range(120):
			if not core.run_frame(0): fail(str(core.last_error())); return false
			if OS.get_environment("CRT_XR_TEST_PACE") == "1": OS.delay_usec(16600)
		if not core.load_state(envelope.state): fail("Resume save did not restore: " + str(core.last_error())); return false
		print("RESUMED ", resume.get_file())
	var pictures := 0
	var audio_frames := 0
	var changed := 0
	var previous := PackedByteArray()
	var timings: Array[int] = []
	for frame in range(frames):
		# Start now and then, so intros move on.
		var buttons := (1 << 3) if frame % 240 == 200 else 0
		if not core.run_frame(buttons): fail(str(core.last_error())); core.close(); return false
		# CRT_XR_TEST_PACE=1 runs at about 60 frames a second, so cores that boot on
		# threads of their own (PPSSPP's loader) get the real time they would in play.
		if OS.get_environment("CRT_XR_TEST_PACE") == "1": OS.delay_usec(maxi(0, 16600 - int(core.info().step_usec)))
		var info: Dictionary = core.info()
		audio_frames += int(info.audio_frames)
		if info.video_changed: pictures += 1
		if frame >= 300: timings.append(int(info.step_usec))
		if frame % 120 == 0 and info.width > 0:
			var pixels: PackedByteArray = core.frame()
			if pixels != previous: changed += 1
			previous = pixels
		if frame % 300 == 0: print("CORE_FRAME ",frame," ",JSON.stringify(info))
	var info: Dictionary = core.info()
	var image_path := OS.get_environment("CRT_XR_TEST_IMAGE")
	if not image_path.is_empty() and info.width > 0: Image.create_from_data(info.width,info.height,false,Image.FORMAT_RGBA8,core.frame()).save_png(image_path)
	if pictures == 0 or changed < 2 or audio_frames == 0: fail("Expected changing video and audio (pictures %d, changes %d, audio %d)" % [pictures, changed, audio_frames]); core.close(); return false
	var state_bytes := 0
	if OS.get_environment("CRT_XR_TEST_STATE") != "0":
		var state: PackedByteArray = core.save_state()
		state_bytes = state.size()
		if state.is_empty() or not core.load_state(state): fail("Save-state round trip failed: " + str(core.last_error())); core.close(); return false
		if not core.run_frame(0) or not core.reset(): fail("Restore/reset failed"); core.close(); return false
	core.close_game()
	core.close()
	timings.sort()
	var total := 0
	for value in timings: total += value
	print("CORE_CLOSED")
	print("CORE_RESULT ",JSON.stringify({"system":system,"rom":rom.get_file(),"pictures":pictures,"changes":changed,"audio_frames":audio_frames,"mean_usec":float(total)/maxi(1, timings.size()),"p50_usec":timings[timings.size()/2] if timings.size() > 0 else 0,"p95_usec":timings[int(timings.size()*0.95)] if timings.size() > 0 else 0,"over_16ms":timings.filter(func(t): return t > 16700).size(),"over_25ms":timings.filter(func(t): return t > 25000).size(),"max_usec":timings[-1] if timings.size() > 0 else 0,"state_bytes":state_bytes}))
	print("PASS: Real core video, audio, state restore, reset and unload")
	return true
