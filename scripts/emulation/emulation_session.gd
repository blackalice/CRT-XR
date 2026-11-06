extends Node
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Folders = preload("res://scripts/content/console_folders.gd")
const Layouts = preload("res://scripts/emulation/controller_layouts.gd")
const CoreOptions = preload("res://scripts/emulation/core_options.gd")
const StateStore = preload("res://scripts/emulation/state_store.gd")
const DolphinSupport = preload("res://scripts/emulation/dolphin_support.gd")
const CoreData = preload("res://scripts/emulation/core_data.gd")
## Godot owns presentation; the native Libretro host owns frame execution/callbacks.
signal content_changed(texture: Texture2D)
signal frame_presented(image: Image)
signal aspect_changed(aspect: float)
## Opt-in diagnostic trace. Includes every emulated frame in a catch-up batch,
## rather than just the last frame left in core.info(). Disabled during play.
signal frame_profiled(metrics: Dictionary)
signal status_changed(message: String)
signal game_changed(active: bool)
## A disc ZIP being unpacked before play: bytes done of total, then the outcome
## ("" when the disc is ready).
signal unpack_progress(path: String, done: int, total: int)
signal unpack_finished(path: String, error: String)

var disc_snapshot := {"count": 0, "index": 0, "labels": PackedStringArray()}
var transition_busy := false
var transition_thread: Thread
var profile_frames := false
# Hardware cores may spend hundreds of milliseconds compiling. Never wait for that
# work in a room update; collect completed batches before submitting more.
var async_pending := false
var async_completed := false
var async_sample_rate := 48000.0
var vmu_pixels := PackedByteArray()
const ASYNC_AUDIO_RESERVE_FRAMES := 8
## Hardware cores stream: the native worker runs frames back to back, paced by
## the queued audio, instead of one batch per room update. Each picture is read
## back without waiting for the GPU (one emulated frame later). Both can be
## turned off for comparison with CRT_XR_STREAM=0 / CRT_XR_ASYNC_READBACK=0.
var streaming_enabled := OS.get_environment("CRT_XR_STREAM") != "0"
var async_readback := OS.get_environment("CRT_XR_ASYNC_READBACK") != "0"
## SRAM is read between frames: the stream stops, the read follows, it restarts.
var stream_sram_pending := false
## Audio queued ahead of the speaker, in emulated frames: it is the sound's delay
## behind the picture, and the cover for slow frames. It starts low, grows when
## the device runs dry, and shrinks again after a calm spell.
const STREAM_RESERVE_MIN := 3
const STREAM_RESERVE_START := 4
const STREAM_RESERVE_MAX := 10
const STREAM_RESERVE_CALM := 10.0
var stream_reserve := STREAM_RESERVE_START
var stream_calm := 0.0
var async_audio_capacity := 0
var async_audio_skips := 0
var async_audio_priming := false
var async_audio_recoveries := 0
var auto_saved := true
var core: RefCounted
var loaded := false
var paused := false
## The core reported a failed frame or lost its state: it cannot be trusted to
## run again or to be written as a resume point until a game is loaded afresh.
var core_failed := false
var status := "Test signal / no game loaded"
var rom_path := ""
## The file the core opened: rom_path, or its cartridge unpacked from a ZIP.
var content_path := ""
var rom_hash := ""
var core_identity := ""
var system_id := "snes"
var save_directory := "user://saves"
var display_aspect := 4.0 / 3.0
var fps := 60.0
var accumulator := 0.0
var texture: ImageTexture
var last_frame: Image
var player := AudioStreamPlayer.new()
var tv_audio := preload("res://scripts/emulation/tv_audio.gd").new()
var playback: AudioStreamGeneratorPlayback
var audio_overflows := 0
var slow_frames := 0
# Recent late frames, decaying each second. Sustained lateness with the input
# preview on suspends the preview for this game: a frame of latency is better
# than dropped game frames on a heavy core.
var late_pressure := 0.0
var preview_suspended := false
const PREVIEW_SUSPEND_PRESSURE := 20.0
var sram_timer := 0.0
var sram_written := PackedByteArray() # last battery RAM on disk; skip identical writes
var sram_restore_ok := true
var skip_delta := true
var run_ahead := 1
## Preview in a second copy of the core: the playing core is never rewound, so
## its sound stays continuous on every console. Off limits preview to cores whose
## audio survives a same-instance restore (Registry.PREVIEW_SAFE_CORES).
var separate_preview := true
var preview_copy := "" # "", "ready" or "failed" for the loaded game
var preview_time_usec := 0
var preview_count := 0
var gamepad := preload("res://scripts/emulation/gamepad_input.gd").new()
## The controller layout in force for the loaded game (see controller_layouts.gd).
var controls: Dictionary = {}
var unpack_thread: Thread
var unpacking := ""
var unpack_cancelled := false
var unpack_reported := 0

func _ready() -> void:
	# Poll close to frame execution, after ordinary scene/UI processing.
	process_priority = 100
	add_child(player)
	player.volume_db = -6.0
	add_child(tv_audio)
	tv_audio.setup(player)

func report(message: String, failure := false) -> void:
	status = message
	status_changed.emit(message)
	if failure: push_error(message)
	else: print("Emulation: ", message)

func default_core_path() -> String:
	return Registry.core_path(system_id)

func load_rom(path: String) -> bool:
	if transition_busy: return false
	# The shared implementation only yields when background is true. Dynamic
	# dispatch keeps this existing synchronous API usable by probes/startup.
	return call("_load_rom", path, false)

func run_job(job: Callable):
	transition_thread = Thread.new()
	var error := transition_thread.start(job)
	if error != OK:
		push_error("Background loading worker unavailable: " + error_string(error))
		transition_thread = null
		return job.call()
	while transition_thread.is_alive(): await get_tree().process_frame
	var result = transition_thread.wait_to_finish()
	transition_thread = null
	return result

static func write_transition_file(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

func drain_transition_frame() -> void:
	if streams() and (async_pending or stream_sram_pending):
		core.stop_stream()
		while core.stream_running(): await get_tree().process_frame
		if core.stream_info().failed: core_failed = true
		async_pending = false
		stream_sram_pending = false
	while async_pending and not async_completed:
		var result: int = core.poll_frame()
		if result == 0: await get_tree().process_frame
		else:
			async_completed = true
			if result < 0: core_failed = true
	drain_async()

func stop_for_launch() -> bool:
	if transition_busy: return false
	transition_busy = true
	var old_paused := paused
	paused = true
	await drain_transition_frame()
	var native_core := core
	var needs_save := loaded and not auto_saved and not core_failed
	var envelope := {"format": 1, "rom": rom_hash, "core": core_identity, "saved_at": int(Time.get_unix_time_from_system()), "game": rom_path.get_file()}
	if last_frame != null:
		var thumbnail := last_frame.duplicate()
		thumbnail.resize(mini(256, roundi(192.0 * display_aspect)), 192, Image.INTERPOLATE_NEAREST)
		envelope["thumbnail"] = thumbnail.save_png_to_buffer()
	var resume_path := auto_path()
	var ram_path := battery_path()
	var preserve_ram := loaded and sram_restore_ok
	var previous_ram := sram_written
	var error: String = await run_job(func():
		if native_core == null: return ""
		if needs_save:
			var state: PackedByteArray = native_core.save_state()
			if state.is_empty(): return "Could not save automatic resume: " + str(native_core.last_error())
			envelope["state"] = state
			var saved := StateStore.write_state(resume_path, envelope)
			if saved != OK: return "Could not save automatic resume: " + error_string(saved)
		if preserve_ram:
			var ram: PackedByteArray = native_core.save_ram()
			if not ram.is_empty() and ram != previous_ram:
				var saved := write_transition_file(ram_path, ram)
				if saved != OK: return "Could not save battery memory: " + error_string(saved)
		native_core.close()
		return "")
	if not error.is_empty():
		paused = old_paused
		transition_busy = false
		report(error, true)
		return false
	core = null
	finish_stop()
	clear_game()
	transition_busy = false
	return true

func load_auto_async() -> bool:
	return await load_from_async(auto_path(), "Continued automatic save")

func load_state_async(slot := 0) -> bool:
	return await load_from_async(state_path(slot), "Loaded • Slot %d" % (slot + 1))

func load_from_async(path: String, description: String) -> bool:
	if transition_busy or not loaded: return false
	transition_busy = true
	await drain_transition_frame()
	var native_core := core
	var hash := rom_hash
	var identity := core_identity
	var error: String = await run_job(func():
		var envelope := state_details(path)
		if envelope.get("rom") != hash or envelope.get("core") != identity: return "Save is unreadable or does not match this game. Your save was kept."
		var restored: bool = native_core.load_state(envelope.state)
		if not restored and native_core.run_frame(0): restored = native_core.load_state(envelope.state)
		return "" if restored else str(native_core.last_error()))
	transition_busy = false
	if not error.is_empty():
		report(error, true)
		return false
	restart_audio()
	accumulator = 0.0
	skip_delta = true
	auto_saved = false
	core_failed = false
	disc_snapshot = core.disc_info()
	update_texture(true)
	report(description + " • " + rom_path.get_file().get_basename())
	return true

func load_rom_async(path: String) -> bool:
	if transition_busy: return false
	if loaded:
		report("Stop the playing game before starting a background load.", true)
		return false
	transition_busy = true
	var result: bool = await _load_rom(path, true)
	transition_busy = false
	return result

func _load_rom(path: String, background: bool) -> bool:
	if not ClassDB.class_exists("RetroCore"):
		report("Native emulation module missing. Build the emulator dependencies first.", true)
		return false
	if not FileAccess.file_exists(path):
		report("ROM file not found: " + path, true)
		return false
	var detected := Registry.identify(path)
	if detected.is_empty():
		report("Unsupported game file. Use a cartridge for a supported system, alone or in a ZIP; .bin needs a SEGA or SEGADISCSYSTEM header or a PlayStation disc; CHD discs and zipped PlayStation discs go in their console's folder.", true)
		return false
	var selected_path := Registry.core_path(detected)
	if not FileAccess.file_exists(selected_path):
		if detected in Folders.EXPERIMENTAL:
			report("%s is experimental. Its core is not included in this build." % Registry.SYSTEMS[detected].name, true)
			return false
		report("%s core missing. Restore %s from the application package." % [Registry.SYSTEMS[detected].name, selected_path], true)
		return false
	if Registry.SYSTEMS[detected].core == "dolphin" and not DolphinSupport.available():
		report("Dolphin system files are missing. Restore the core-data/dolphin-emu/Sys folder from the GameCube build.", true)
		return false
	if not CoreData.available(Registry.SYSTEMS[detected]):
		report("%s system files are missing. Restore the core-data/%s folder from the application package." % [Registry.SYSTEMS[detected].name, Registry.SYSTEMS[detected].core_data.source], true)
		return false
	if not Registry.bios_satisfied(detected):
		report("%s needs its BIOS. Put one of %s in the bios folder next to your roms folder, or in %s, then reload the game." % [Registry.SYSTEMS[detected].name, ", ".join(PackedStringArray(Registry.SYSTEMS[detected].bios_any)), Registry.preferred_bios_folder()], true)
		return false
	# Checked before the playing game stops: the menu unpacks discs beforehand.
	if Registry.needs_unpacking(path):
		report("The disc in " + path.get_file() + " has to be unpacked first. Choose the game again from the library.", true)
		return false
	# Preserve existing SNES paths; new systems have independent save namespaces.
	var new_save_directory: String = "user://saves" if detected == "snes" else "user://saves/" + detected + "/" + Registry.SYSTEMS[detected].core
	var saves := ProjectSettings.globalize_path(new_save_directory)
	# Everything that can fail without touching the playing game happens first,
	# so a missing folder or system file leaves the current game running.
	# (Staging skips identical files, so it is safe beside a running core.)
	var error := DirAccess.make_dir_recursive_absolute(saves)
	if error != OK:
		report("Cannot create save directory: " + error_string(error), true)
		return false
	var staging = func():
		Registry.stage_bios(detected, saves)
		if Registry.SYSTEMS[detected].core == "dolphin": return DolphinSupport.stage(saves)
		return CoreData.stage(Registry.SYSTEMS[detected], saves)
	var stage_error: int = await run_job(staging) if background else staging.call()
	if stage_error != OK:
		report("Could not prepare console system files: " + error_string(stage_error), true)
		return false
	if not background:
		if not save_auto(): return false
		stop()
	elif core != null:
		var previous_core := core
		await run_job(func(): previous_core.close(); return true)
		core = null
	# From here the old game is gone (callbacks have one owner, so the new core
	# cannot load beside it); any failure must leave nothing loaded.
	clear_game()
	core = ClassDB.instantiate("RetroCore")
	system_id = detected
	display_aspect = Registry.SYSTEMS[system_id].aspect
	save_directory = new_save_directory
	core.set_hardware_rendering(Registry.SYSTEMS[system_id].get("hardware", false))
	if core.has_method("set_destroy_context_first"): core.set_destroy_context_first(Registry.SYSTEMS[system_id].get("context_first", false))
	var native_core := core
	var opened_core: bool = await run_job(func(): return native_core.load_core(selected_path)) if background else core.load_core(selected_path)
	if not opened_core: return fail_load(str(core.last_error()))
	var spec: Dictionary = Registry.SYSTEMS[system_id]
	if spec.has("controller"): core.set_controller(spec.controller)
	for key in spec.get("options", {}): core.set_option(key, spec.options[key])
	if spec.has("bios_option"): core.set_option(spec.bios_option, Registry.first_bios(system_id))
	var selected_options := CoreOptions.overrides(system_id, Registry.content_hash(path))
	for key in selected_options: core.set_option(key, selected_options[key])
	var content := Registry.content_file(path)
	if content.is_empty():
		return fail_load("Could not unpack the game from " + path.get_file() + ". Its ZIP may be damaged or use a compression method other than Deflate.")
	var opened_game: bool = await run_job(func(): return native_core.load_game(content, saves)) if background else core.load_game(content, saves)
	if not opened_game:
		var message := str(core.last_error())
		if background: await run_job(func(): native_core.close(); return true)
		return fail_load(message)
	rom_path = path
	content_path = content
	preview_copy = ""
	# A ZIP's cartridge was just unpacked: hash that copy and remember it. A disc
	# ZIP is named by its directory's track checksums instead.
	var disc_zip: bool = path.get_extension().to_lower() == "zip" and Registry.archive_game(path).get("disc", false)
	if disc_zip: rom_hash = Registry.content_hash(path)
	elif content != path:
		rom_hash = FileAccess.get_sha256(content)
		Registry.archive_game(path)["sha256"] = rom_hash
	else: rom_hash = Registry.content_hash(path)
	var info: Dictionary = core.info()
	disc_snapshot = core.disc_info()
	update_display_aspect(info)
	reload_controls()
	core_identity = str(info.name)
	fps = float(info.fps)
	async_sample_rate = float(info.sample_rate)
	stream_reserve = STREAM_RESERVE_START
	stream_calm = 0.0
	audio_pitch_bias = 0.0
	frame_phase = 0.0
	game_fps_samples.clear()
	game_fps = 0.0
	auto_saved = true
	core_failed = false
	loaded = true
	paused = false
	accumulator = 0.0
	audio_overflows = 0
	slow_frames = 0
	late_pressure = 0.0
	preview_suspended = false
	sram_timer = 0.0
	skip_delta = true
	preview_time_usec = 0
	preview_count = 0
	var sram_path := battery_path()
	sram_restore_ok = true
	sram_written = PackedByteArray()
	if FileAccess.file_exists(sram_path):
		var ram := FileAccess.get_file_as_bytes(sram_path)
		# Genesis Plus GX writes only the modified prefix but requests its full
		# 64 KiB capacity when loading. Retain the core's erased tail bytes.
		if Registry.SYSTEMS[system_id].core == "genesis_plus_gx" and not ram.is_empty():
			var initial: PackedByteArray = core.save_ram()
			if ram.size()<initial.size():
				for i in range(ram.size()): initial[i]=ram[i]
				ram=initial
		var restored_ram: bool = await run_job(func(): return native_core.load_ram(ram)) if background and not ram.is_empty() else (not ram.is_empty() and core.load_ram(ram))
		if not restored_ram:
			sram_restore_ok = false
			report("Could not restore SRAM: " + str(core.last_error()), true)
	# Load the preview copy now, inside the game-load pause, rather than as a
	# visible hitch on the first previewed frame.
	if run_ahead > 0 and separate_preview and Registry.SYSTEMS[system_id].get("preview", true): prepare_preview_copy()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = float(info.sample_rate)
	generator.buffer_length = 0.10
	player.stream = generator
	restart_audio()
	game_changed.emit(true)
	report("%s / %s / %.3f fps%s" % [path.get_file(), core_identity, fps,"" if sram_restore_ok else " / Battery save could not be restored; original file is protected."])
	return true

func _process(delta: float) -> void:
	Input.flush_buffered_events()
	if transition_busy or not loaded or paused:
		return
	if skip_delta:
		skip_delta = false
		return
	if uses_async():
		process_async(delta)
		return
	var profile_start := Time.get_ticks_usec() if profile_frames else 0
	var profile_steps = [] if profile_frames else null
	var profile_audio := 0
	steer_audio(delta, SYNC_AUDIO_MARGIN + 1.0 / fps)
	var due := frames_due(delta)
	late_pressure = maxf(0.0, late_pressure - delta * 2.0)
	var frames := 0
	var rendered := false
	var input := read_input()
	var buttons: int = input.mask
	var sticks: PackedInt32Array = input.analog
	core.set_analog(sticks[0], sticks[1], sticks[2], sticks[3])
	var pressure: PackedInt32Array = input.pressure
	core.set_trigger_pressure(pressure[0], pressure[1])
	while frames < mini(due, 8):
		var step_start := Time.get_ticks_usec() if profile_frames else 0
		if not core.run_frame(buttons):
			var message := str(core.last_error())
			fail_core()
			report(message, true)
			return
		if profile_frames:
			var info: Dictionary = core.info()
			profile_steps.append({"wall_us": Time.get_ticks_usec() - step_start,
				"core_us": info.step_usec, "readback_us": info.readback_usec,
				"audio_frames": info.audio_frames, "video_changed": info.video_changed})
		frames += 1
		auto_saved = false
		rendered = rendered or core.video_changed()
		var audio_start := Time.get_ticks_usec() if profile_frames else 0
		if playback != null and core.push_audio(playback) < 0:
			audio_overflows += 1
			if audio_overflows == 1 or audio_overflows % 300 == 0:
				push_warning("Audio buffer full; dropped an audio batch. Check frame pacing.")
		if profile_frames: profile_audio += Time.get_ticks_usec() - audio_start
	if due > 8: # the room fell so far behind that frames were given up
		slow_frames += 1
		late_pressure += 1.0
		if run_ahead > 0 and not preview_suspended and late_pressure >= PREVIEW_SUSPEND_PRESSURE:
			preview_suspended = true
			if core != null: core.close_preview()
			preview_copy = ""
			report("Input preview paused for this game: it needs the full frame time.", true)
		if slow_frames == 1 or slow_frames % 300 == 0:
			push_warning("Emulator cannot keep up with real time; reduce rendering load")
	count_game_frames(frames, delta)
	var present_start := Time.get_ticks_usec() if profile_frames else 0
	if rendered:
		var preview := preview_frame(buttons, run_ahead) if run_ahead > 0 and preview_possible() else {}
		if not paused: update_texture(true, preview)
	var present_us := Time.get_ticks_usec() - present_start if profile_frames else 0
	sram_timer += delta
	if sram_timer >= 10.0:
		sram_timer = 0.0
		flush_sram()
	if profile_frames:
		frame_profiled.emit({"mode": "sync", "shown": rendered, "fps": fps, "audio_skips": playback.get_skips() if playback != null else 0, "audio_queued": async_audio_capacity - playback.get_frames_available() if playback != null else 0, "at_us": profile_start, "delta_us": int(delta * 1000000.0),
			"process_us": Time.get_ticks_usec() - profile_start, "steps": profile_steps,
			"audio_us": profile_audio, "present_us": present_us,
			"audio_overflows": audio_overflows, "slow_frames": slow_frames})

## The game's own frame rate: emulated frames per second over the last two
## seconds (independent of the room's rendering rate). A rolling window keeps
## the readout steady: half-second windows swung ±2 fps on one frame's timing.
var game_fps := 0.0
var game_fps_total := 0
var game_fps_samples: Array[Vector2i] = []
func count_game_frames(frames: int, _delta: float) -> void:
	game_fps_total += frames
	var now := Time.get_ticks_msec()
	game_fps_samples.append(Vector2i(now, game_fps_total))
	while game_fps_samples.size() > 2 and now - game_fps_samples[0].x > 2000: game_fps_samples.pop_front()
	var span := now - game_fps_samples[0].x
	if span >= 500: game_fps = (game_fps_total - game_fps_samples[0].y) * 1000.0 / span

## Display-locked pacing. Each room update is one display refresh (or several,
## after a hitch). A game whose rate is within 1% of the room's runs exactly one
## frame per refresh, so every refresh shows a new game frame; other rates
## (50 Hz games at 60 Hz) follow a fixed fractional pattern. The difference
## between the game's and the display's clocks is taken up by the audio
## playback speed instead (steer_audio), never by repeating or skipping frames.
## Pacing on the audio device's demand ran frames in bursts of two at its
## ~21 ms mixing chunks, so one refresh in five repeated a frame and the next
## skipped one.
const DISPLAY_LOCK := 0.01
var room_period := 1.0 / 60.0
var frame_phase := 0.0
func frames_due(delta: float) -> int:
	delta = minf(delta, 0.25)
	if delta <= 0.0: return 0
	var refreshes := maxi(1, roundi(delta / room_period))
	if refreshes <= 2: room_period = lerpf(room_period, delta / refreshes, 0.02)
	var ratio := fps * room_period
	# Lock to an exact 1:1, 1:2 or 2:1 cadence when within 1%: a 60 Hz game on a
	# 120 Hz room then alternates evenly instead of drifting into double gaps.
	for locked in [1.0, 0.5, 2.0]:
		if absf(ratio / locked - 1.0) < DISPLAY_LOCK: ratio = locked
	frame_phase += refreshes * ratio
	var due := int(floor(frame_phase + 0.000001))
	frame_phase -= due
	return due

## Holds the audio queue (the sound's delay behind the picture) near a target
## by playing it up to 0.5% faster or slower (inaudible), with a slow integral
## for the steady offset between the audio device's clock and the display's.
## Classic cores read the queue at its low point, before this update's frames
## are pushed: SYNC_AUDIO_MARGIN plus one frame (a 22 ms low point underran on
## 50 Hz SNES; 32-35 ms ran cleanly).
const SYNC_AUDIO_MARGIN := 0.015
const AUDIO_PITCH_LIMIT := 0.005
var audio_pitch_bias := 0.0
func steer_audio(delta: float, target_seconds: float) -> void:
	if playback == null or async_audio_capacity <= 0 or async_sample_rate <= 0.0 or async_audio_priming: return
	var queued := float(async_audio_capacity - playback.get_frames_available()) / async_sample_rate
	var excess := (queued - target_seconds) / (1.0 / 60.0)
	audio_pitch_bias = clampf(audio_pitch_bias + excess * minf(delta, 0.1) * 0.0005, -0.004, 0.004)
	player.pitch_scale = clampf(1.0 + excess * 0.002 + audio_pitch_bias, 1.0 - AUDIO_PITCH_LIMIT, 1.0 + AUDIO_PITCH_LIMIT)

## Streams only with an extension built with streaming (an older native build
## keeps the batch path).
func streams() -> bool:
	return streaming_enabled and uses_async() and core != null and core.has_method("start_stream")

func uses_async() -> bool:
	return system_id in ["gamecube", "wii", "dreamcast", "n64", "ps2", "psp"]

# The VMU display only reads a completed snapshot; it must never join a job.
func vmu_lcd() -> PackedByteArray:
	return vmu_pixels

# Audio consumption paces native jobs, at most four frames per batch.
# Without an audio device, headless tests use the wall-clock accumulator.
# Silence already played by the device is lost wall time, not audio to replay.
# All generated audio is retained in order; no emulated frames are skipped.
func process_async(delta: float) -> void:
	if streams():
		process_stream(delta)
		return
	count_game_frames(0, delta)
	var started := Time.get_ticks_usec()
	accumulator += delta
	if playback != null:
		var skips := playback.get_skips()
		if skips > async_audio_skips and not async_audio_priming:
			player.stream_paused = true
			async_audio_priming = true
			async_audio_recoveries += 1
		async_audio_skips = skips
		# With sound, the device's consumed samples are the master clock.
		# A wall-clock catch-up loop cannot repay silence without racing audio.
		accumulator = 0.0
	sram_timer += delta
	var steps: Array = []
	var audio_us := 0
	var present_us := 0
	if async_pending:
		if not async_completed:
			var result: int = core.poll_frame()
			if result < 0:
				async_pending = false
				var message := str(core.last_error())
				fail_core()
				report(message, true)
				return
			async_completed = result == 1
		if async_completed:
			var audio_start := Time.get_ticks_usec()
			# Keep the completed batch until the audio queue has room.
			if playback == null or core.push_audio(playback) >= 0:
				audio_us = Time.get_ticks_usec() - audio_start
				async_pending = false
				async_completed = false
				if playback != null and async_audio_priming:
					var queued := async_audio_capacity - playback.get_frames_available()
					if queued >= mini(ceili(async_sample_rate / fps) * ASYNC_AUDIO_RESERVE_FRAMES, async_audio_capacity):
						player.stream_paused = false
						async_audio_priming = false
						accumulator = 0.0
				if system_id == "dreamcast": vmu_pixels = core.vmu_lcd(0)
				if profile_frames: steps = core.info().async_steps
				var present_start := Time.get_ticks_usec()
				if core.video_changed(): update_texture(true)
				present_us = Time.get_ticks_usec() - present_start
	if not async_pending:
		# Periodic RAM reads must also happen between jobs, never during one.
		if sram_timer >= 10.0:
			sram_timer = 0.0
			flush_sram()
		var period := 1.0 / fps
		var due := mini(4, int(accumulator / period))
		if playback != null:
			var samples_per_frame := ceili(async_sample_rate / fps)
			var queued := async_audio_capacity - playback.get_frames_available()
			var target := mini(samples_per_frame * ASYNC_AUDIO_RESERVE_FRAMES, async_audio_capacity)
			due = clampi(ceili(float(target - queued) / samples_per_frame), 0, 4)
			due = mini(due, playback.get_frames_available() / samples_per_frame)
		if due > 0:
			var input := read_input()
			var sticks: PackedInt32Array = input.analog
			core.set_analog(sticks[0], sticks[1], sticks[2], sticks[3])
			var pressure: PackedInt32Array = input.pressure
			core.set_trigger_pressure(pressure[0], pressure[1])
			if core.begin_frame(input.mask, due):
				count_game_frames(due, 0.0)
				async_pending = true
				accumulator = maxf(0.0, accumulator - period * due)
				auto_saved = false
	if profile_frames:
		frame_profiled.emit({"mode": "async", "clock": "audio" if playback != null else "wall", "priming": async_audio_priming, "audio_recoveries": async_audio_recoveries, "fps": fps, "audio_skips": playback.get_skips() if playback != null else 0, "audio_queued": async_audio_capacity - playback.get_frames_available() if playback != null else 0, "pending": async_pending, "backlog_us": int(accumulator * 1000000.0), "at_us": started, "delta_us": int(delta * 1000000.0),
			"process_us": Time.get_ticks_usec() - started, "steps": steps,
			"audio_us": audio_us, "present_us": present_us,
			"audio_overflows": audio_overflows, "slow_frames": slow_frames})

## Streaming room update: hand over input, push produced audio, show the newest
## picture. Nothing here waits for the worker.
func process_stream(delta: float) -> void:
	var started := Time.get_ticks_usec()
	stream_calm += delta
	if playback != null:
		var skips := playback.get_skips()
		if skips > async_audio_skips and not async_audio_priming:
			player.stream_paused = true
			async_audio_priming = true
			async_audio_recoveries += 1
			set_stream_reserve(stream_reserve + 2)
		async_audio_skips = skips
	if stream_calm >= STREAM_RESERVE_CALM and stream_reserve > STREAM_RESERVE_MIN:
		set_stream_reserve(stream_reserve - 1)
	sram_timer += delta
	var info: Dictionary = core.stream_info()
	update_display_aspect(info)
	count_game_frames(info.steps.size(), delta)
	if async_pending and not core.stream_running():
		async_pending = false # the loop ended: requested, or a failed frame
		if info.failed:
			fail_core()
			report(str(info.error), true)
			return
	var input := read_input()
	var sticks: PackedInt32Array = input.analog
	var pressure: PackedInt32Array = input.pressure
	core.stream_input(input.mask, sticks[0], sticks[1], sticks[2], sticks[3], pressure[0], pressure[1])
	# This refresh's frames start now, with the input just handed over.
	core.stream_tick(frames_due(delta))
	steer_audio(delta, float(stream_reserve) / fps)
	var audio_start := Time.get_ticks_usec()
	core.stream_audio(playback, async_audio_capacity)
	if playback != null and async_audio_priming:
		var queued := async_audio_capacity - playback.get_frames_available()
		if queued >= mini(ceili(async_sample_rate / fps) * stream_reserve, async_audio_capacity) * 0.8:
			player.stream_paused = false
			async_audio_priming = false
	var audio_us := Time.get_ticks_usec() - audio_start
	var present_start := Time.get_ticks_usec()
	var bytes: PackedByteArray = core.stream_frame()
	if not bytes.is_empty():
		fps = float(info.fps)
		update_texture(true, {"bytes": bytes, "width": info.width, "height": info.height})
	var present_us := Time.get_ticks_usec() - present_start
	if system_id == "dreamcast": vmu_pixels = core.stream_vmu_lcd()
	# Battery RAM is read between frames, never during one.
	if sram_timer >= 10.0 and not stream_sram_pending:
		stream_sram_pending = true
		core.stop_stream()
	if stream_sram_pending and not core.stream_running():
		async_pending = false
		stream_sram_pending = false
		sram_timer = 0.0
		flush_sram()
	if not async_pending and not stream_sram_pending:
		async_pending = core.start_stream(stream_reserve, async_readback)
		if system_id == "dreamcast": core.stream_vmu(true)
		auto_saved = false
	if profile_frames:
		frame_profiled.emit({"mode": "stream", "clock": "audio" if playback != null else "wall", "priming": async_audio_priming, "audio_recoveries": async_audio_recoveries, "fps": fps, "audio_skips": playback.get_skips() if playback != null else 0, "audio_queued": async_audio_capacity - playback.get_frames_available() if playback != null else 0, "pending": async_pending, "pending_audio": info.pending_audio, "shown": not bytes.is_empty(), "dropped": info.dropped, "at_us": started, "delta_us": int(delta * 1000000.0),
			"process_us": Time.get_ticks_usec() - started, "steps": info.steps,
			"picture_ages_us": info.picture_ages_us, "reserve": stream_reserve,
			"audio_us": audio_us, "present_us": present_us,
			"audio_overflows": audio_overflows, "slow_frames": slow_frames})

func set_stream_reserve(frames: int) -> void:
	stream_calm = 0.0
	frames = clampi(frames, STREAM_RESERVE_MIN, STREAM_RESERVE_MAX)
	if frames == stream_reserve: return
	stream_reserve = frames
	if core != null and core.has_method("stream_set_reserve"): core.stream_set_reserve(frames)

# Explicit console operations may wait. Normal presentation never does.
func drain_async() -> void:
	if core == null: return
	if streams():
		if async_pending or stream_sram_pending: core.info() # stops the stream and joins its frame
		async_pending = false
		async_completed = false
		stream_sram_pending = false
		return
	if not async_pending: return
	core.info() # Joins the job before save/restore, pause, reset or teardown.
	if not async_completed: core.poll_frame()
	async_pending = false
	async_completed = false

func preview_possible() -> bool:
	if preview_suspended or not Registry.SYSTEMS[system_id].get("preview", true): return false
	return (separate_preview and preview_copy != "failed") or Registry.preview_safe(system_id)

func set_separate_preview(value: bool) -> void:
	separate_preview = value
	if not value and core != null: core.close_preview()
	preview_copy = ""

func prepare_preview_copy() -> void:
	if not preview_copy.is_empty() or not loaded: return
	# Its own folder: a preview core must never write over real saves.
	var directory := ProjectSettings.globalize_path("user://preview/" + system_id)
	DirAccess.make_dir_recursive_absolute(directory)
	Registry.stage_bios(system_id, directory)
	preview_copy = "ready" if core.load_preview(Registry.core_path(system_id), content_path, directory) else "failed"

func separate_preview_frame(buttons: int, frames: int) -> Dictionary:
	var started := Time.get_ticks_usec()
	prepare_preview_copy()
	var result: Dictionary = core.run_preview(buttons, maxi(frames, 1)) if preview_copy == "ready" else {}
	if result.is_empty():
		preview_copy = "failed"
		core.close_preview()
		push_warning("Separate preview core unavailable for this game; " + ("using the same-core preview." if Registry.preview_safe(system_id) else "input preview is off."))
		return {}
	preview_time_usec += Time.get_ticks_usec() - started
	preview_count += 1
	return result

func preview_frame(buttons: int, frames := 1) -> Dictionary:
	if separate_preview and preview_copy != "failed":
		var separate := separate_preview_frame(buttons, frames)
		if not separate.is_empty() or not Registry.preview_safe(system_id): return separate
	# Advance disposable frames for presentation only. Audio was already queued
	# from the real frames above; never enqueue preview audio.
	var started := Time.get_ticks_usec()
	var state: PackedByteArray = core.save_state()
	if state.is_empty():
		preview_suspended = true # this game only; the run_ahead setting is the user's
		push_warning("Input preview unavailable for this core; using normal presentation.")
		return {}
	var ram: PackedByteArray = core.save_ram()
	var ok := false
	var info: Dictionary = {}
	var bytes: PackedByteArray = PackedByteArray()
	for frame in range(maxi(frames, 1)):
		ok = core.run_frame(buttons)
		if not ok:
			break
		info = core.info()
		bytes = core.frame()
	# Restore SRAM explicitly as well: not every core includes it in save states.
	var restored: bool = core.load_state(state)
	var ram_restored: bool = ram.is_empty() or core.load_ram(ram)
	if not restored or not ram_restored:
		fail_core()
		report("Input preview could not restore game state. Reload the game with preview disabled.", true)
		preview_suspended = true # this game only; the run_ahead setting is the user's
		return {}
	preview_time_usec += Time.get_ticks_usec() - started
	preview_count += 1
	if not ok:
		preview_suspended = true # this game only; the run_ahead setting is the user's
		push_warning("Input preview failed; using normal presentation.")
		return {}
	return {"bytes": bytes, "width": info.width, "height": info.height}

func update_display_aspect(info: Dictionary) -> void:
	# Image-only packets (streamed frames and input preview) carry no geometry.
	# They must not undo the aspect just received in the core's metadata packet.
	if not info.has("display_aspect"): return
	var reported := float(info.get("display_aspect",0.0))
	var aspect: float = reported if is_finite(reported) and reported>=.2 and reported<=8.0 else Registry.SYSTEMS.get(system_id,{"aspect":4.0/3.0}).aspect
	if not is_equal_approx(display_aspect,aspect):
		display_aspect=aspect
		aspect_changed.emit(aspect)

func update_texture(force := false, preview: Dictionary = {}) -> void:
	var info: Dictionary = preview if not preview.is_empty() else core.info()
	update_display_aspect(info)
	# GPU cores can revise their refresh rate after boot or a state restore.
	# Follow the live core clock rather than accumulating drift at the load rate.
	if preview.is_empty(): fps = float(info.fps)
	if (not force and not info.video_changed) or int(info.width) == 0:
		return
	var bytes: PackedByteArray = preview.bytes if not preview.is_empty() else core.frame()
	# One Image is refilled each frame instead of allocating a new one.
	if last_frame == null: last_frame = Image.create_from_data(int(info.width), int(info.height), false, Image.FORMAT_RGBA8, bytes)
	else: last_frame.set_data(int(info.width), int(info.height), false, Image.FORMAT_RGBA8, bytes)
	var image := last_frame
	if texture == null or texture.get_width() != image.get_width() or texture.get_height() != image.get_height():
		texture = ImageTexture.create_from_image(image)
		content_changed.emit(texture)
	else:
		texture.update(image)
	# Reuse the CPU image already uploaded for presentation; never read the GPU.
	frame_presented.emit(image)

# Libretro joypad IDs: B,Y,Select,Start,Up,Down,Left,Right,A,X,L,R.
const KEYBOARD_PAD := [KEY_Z, KEY_A, KEY_TAB, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_X, KEY_S, KEY_Q, KEY_W]

func input_mask() -> int:
	return read_input().mask

## The controller through the game's layout, with the keyboard's fixed keys added.
func read_input() -> Dictionary:
	if gamepad.menu_active: return {"mask": 0, "analog": PackedInt32Array([0, 0, 0, 0]), "pressure": PackedInt32Array([0, 0])}
	# Before a game loads, the current console's standard layout.
	var layout: Dictionary = controls if not controls.is_empty() else Layouts.standard(system_id, Registry.SYSTEMS[system_id])
	var input: Dictionary = gamepad.read(layout)
	for id in range(12):
		if Input.is_physical_key_pressed(KEYBOARD_PAD[id]): input.mask |= 1 << id
	return input

## Applies the layout saved for this game, or for its console, or the standard one.
func reload_controls() -> void:
	controls = Layouts.resolve(system_id, Registry.SYSTEMS[system_id], rom_hash)
	# The right stick moves the TV only on consoles without sticks whose layout
	# leaves it free; on a console with sticks a layout that switches it off
	# should not make it zoom the TV instead.
	gamepad.right_stick_game = Registry.SYSTEMS[system_id].get("analog", false) or controls.right_stick != "buttons" 		or controls.buttons.keys().any(func(input): return input.begins_with("rs_"))

## Stops a broken core without making it look like a user pause.
func fail_core() -> void:
	core_failed = true
	set_paused(true)

func set_paused(value: bool) -> void:
	if transition_busy:
		paused = value
		return
	# A submitted batch owns no scene objects. Let it finish while paused;
	# opening the menu must not wait for its CPU work or GPU readback.
	# Resume collects it normally; a launch drains it asynchronously.
	if not uses_async(): drain_async()
	# A stream stops by itself after its frame in flight; resume restarts it.
	elif value and streams(): core.stop_stream()
	if not value and core_failed:
		report("The emulator stopped after an error. Load the game again to continue.", true)
		return
	paused = value
	accumulator = 0.0
	skip_delta = true
	restart_audio()
	if loaded: report(("Paused / " if paused else "Playing / ") + rom_path.get_file())

func restart_audio() -> void:
	# Godot forbids clearing an active generator. Stop it and obtain a new
	# playback instead; the headless Dummy driver does not need an audio queue.
	player.stop()
	tv_audio.clear_tail()
	playback = null
	async_audio_skips = 0
	async_audio_priming = false
	player.stream_paused = false
	async_audio_recoveries = 0
	player.pitch_scale = 1.0 # steer_audio adjusts it within ±0.5% while playing
	if loaded and not paused and DisplayServer.get_name() != "headless":
		player.play()
		playback = player.get_stream_playback()
		async_audio_capacity = playback.get_frames_available()
		if uses_async():
			async_audio_priming = true
			player.stream_paused = true

func write_bytes_atomic(path: String, bytes: PackedByteArray) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		report("Cannot write save: " + error_string(FileAccess.get_open_error()), true)
		return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		report("Save write failed: " + error_string(error), true)
		return false
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		report("Cannot commit save: " + error_string(error), true)
	return error == OK

func flush_sram() -> void:
	if transition_busy: return
	if not loaded or not sram_restore_ok: return
	var ram: PackedByteArray = core.save_ram()
	if ram.is_empty() or ram == sram_written: return
	if write_bytes_atomic(battery_path(), ram): sram_written = ram

## The battery save (or memory card) of the loaded game. A PlayStation memory card
## belongs to the game rather than one disc: discs sold as separate files
## ("Game (Disc 2).zip") share it, so a save made on disc 1 loads on disc 2.
func battery_path() -> String:
	if system_id == "psx": return save_directory.path_join("card-" + memory_card_name(rom_path) + ".srm")
	return save_directory.path_join(rom_hash + ".srm")

## The game's name without its disc number or extension, as a file name.
static func memory_card_name(path: String) -> String:
	var title := path.get_file().get_basename()
	var disc := RegEx.create_from_string(r"\s*\((Disc|CD) ?\d+( of \d+)?\)")
	title = disc.sub(title, "", true).strip_edges()
	return title.validate_filename()

func state_path(slot := 0) -> String:
	return save_directory.path_join("%s.slot%d.rst" % [rom_hash, slot])

## The loaded game's resume point, from the hash it was loaded with.
func auto_path() -> String:
	return save_directory.path_join(rom_hash+".auto.rst")

static func auto_path_for(path: String) -> String:
	var system := Registry.identify(path)
	if system.is_empty(): return ""
	var folder: String = "user://saves" if system=="snes" else "user://saves/"+system+"/"+Registry.SYSTEMS[system].core
	var hash := Registry.content_hash(path)
	return "" if hash.is_empty() else folder.path_join(hash+".auto.rst")

static func state_details(path: String) -> Dictionary:
	return StateStore.read_state(path)

static func state_metadata(path: String) -> Dictionary:
	return StateStore.metadata(path)

## When a state was saved (Unix time), or 0 when unknown.
static func state_stamp(path: String) -> int:
	return int(state_metadata(path).get("saved_at", FileAccess.get_modified_time(path)))

static func state_time(path: String) -> String:
	var value := state_metadata(path)
	var stamp := int(value.get("saved_at",FileAccess.get_modified_time(path)))
	return Time.get_datetime_string_from_unix_time(stamp).replace("T"," ")+" UTC" if stamp>0 else "Unknown time"

func save_state_async(slot := 0) -> bool:
	if transition_busy or not loaded or core_failed: return false
	transition_busy = true
	await drain_transition_frame()
	if core_failed:
		transition_busy = false
		fail_core()
		report("Cannot save after a frame error. Your previous save was kept.", true)
		return false
	var native_core := core
	var path := state_path(slot)
	var envelope := {"format": 1, "rom": rom_hash, "core": core_identity, "saved_at": int(Time.get_unix_time_from_system()), "game": rom_path.get_file()}
	if last_frame != null:
		var image := last_frame.duplicate()
		image.resize(mini(256, roundi(192 * display_aspect)), 192, Image.INTERPOLATE_NEAREST)
		envelope["thumbnail"] = image.save_png_to_buffer()
	report("Saving • Slot %d" % (slot + 1))
	var error: String = await run_job(func():
		var state: PackedByteArray = native_core.save_state()
		if state.is_empty(): return "Could not save state: " + str(native_core.last_error())
		envelope["state"] = state
		var saved := StateStore.write_state(path, envelope)
		return "" if saved == OK else "Could not save state: " + error_string(saved))
	transition_busy = false
	accumulator = 0.0; skip_delta = true
	restart_audio()
	if not error.is_empty(): report(error, true); return false
	report("Saved • Slot %d" % (slot + 1))
	return true

func reset_game_async() -> bool:
	if transition_busy or not loaded: return false
	transition_busy = true
	await drain_transition_frame()
	var native_core := core
	var success: bool = await run_job(func(): return native_core.reset())
	transition_busy = false
	if not success: report(str(core.last_error()), true); return false
	accumulator = 0.0; skip_delta = true; auto_saved = false
	restart_audio()
	disc_snapshot = core.disc_info()
	report("Reset • " + rom_path.get_file().get_basename())
	return true

func save_auto() -> bool:
	if transition_busy:
		report("Please wait for the current game operation to finish.", true)
		return false
	if not loaded or auto_saved or core_failed: return true
	if not save_to(auto_path(),"Automatic resume saved"): return false
	auto_saved=true
	return true

func save_state(slot := 0) -> bool:
	return save_to(state_path(slot),"Saved • Slot %d" % (slot + 1))

func save_to(path: String, description: String) -> bool:
	if transition_busy:
		report("Please wait for the current game operation to finish.", true)
		return false
	drain_async()
	if not loaded: return false
	var state: PackedByteArray = core.save_state()
	if state.is_empty():
		report(str(core.last_error()), true)
		return false
	var envelope := {"format": 1, "rom": rom_hash, "core": core_identity, "state": state, "saved_at": int(Time.get_unix_time_from_system()), "game": rom_path.get_file()}
	if last_frame!=null:
		var thumbnail := last_frame.duplicate()
		var width := mini(256,roundi(192.0*display_aspect))
		thumbnail.resize(width,maxi(1,roundi(width/display_aspect)),Image.INTERPOLATE_NEAREST)
		envelope["thumbnail"]=thumbnail.save_png_to_buffer()
	var saved := StateStore.write_state(path, envelope)
	if saved != OK:
		report("Could not save state: " + error_string(saved), true)
		return false
	report("%s • %s" % [description,rom_path.get_file().get_basename()])
	return true

## The console's reset button: the game restarts; battery saves and states are kept.
func reset_game() -> bool:
	if transition_busy:
		report("Please wait for the current game operation to finish.", true)
		return false
	drain_async()
	if not loaded: return false
	if not core.reset():
		report(str(core.last_error()), true)
		return false
	restart_audio()
	accumulator = 0.0
	skip_delta = true
	auto_saved = false
	report("Reset • " + rom_path.get_file().get_basename())
	return true

func load_state(slot := 0) -> bool:
	return load_from(state_path(slot),"Loaded • Slot %d" % (slot + 1))

func load_auto() -> bool:
	return load_from(auto_path(),"Continued automatic save")

func load_from(path: String, description: String) -> bool:
	if transition_busy:
		report("Please wait for the current game operation to finish.", true)
		return false
	drain_async()
	if not loaded: return false
	var envelope := state_details(path)
	if envelope.get("rom")!=rom_hash or envelope.get("core")!=core_identity:
		report("Save is unreadable or does not match this ROM and core. Your save file has been kept.",true)
		return false
	var restored: bool = core.load_state(envelope.state)
	# Mupen64Plus-Next starts its console on the first frame and refuses a state
	# before then (as when resuming straight after loading): run it and retry.
	if not restored and core.run_frame(0): restored = core.load_state(envelope.state)
	if not restored:
		report(str(core.last_error()), true)
		return false
	restart_audio()
	accumulator = 0.0
	skip_delta = true
	auto_saved=false
	core_failed = false
	disc_snapshot = core.disc_info()
	update_texture(true)
	report("%s • %s" % [description,rom_path.get_file().get_basename()])
	return true

## Releases the core and forgets the previous game, so nothing describes a game
## that is no longer loaded.
func clear_game() -> void:
	drain_async()
	# Explicitly close/deinit before changing libraries: callbacks have one owner.
	if core != null: core.close()
	core = null
	rom_path = ""
	content_path = ""
	rom_hash = ""
	core_identity = ""
	preview_copy = ""

## A load that failed after the previous game stopped: report it and leave the
## session empty rather than holding a core with no game.
func fail_load(message: String) -> bool:
	report(message, true)
	clear_game()
	return false

func stop() -> void:
	if transition_busy: return
	drain_async()
	flush_sram()
	if core != null: core.close_game()
	finish_stop()

func finish_stop() -> void:
	player.stop()
	tv_audio.clear_tail()
	playback = null
	loaded = false
	disc_snapshot = {"count": 0, "index": 0, "labels": PackedStringArray()}
	vmu_pixels = PackedByteArray()
	paused = false
	texture = null
	last_frame = null
	controls = {}
	gamepad.right_stick_game = false
	game_changed.emit(false)

## The loaded game's discs: {count, index, labels}; count is 0 for one-disc games.
func disc_info() -> Dictionary:
	if transition_busy: return {"count": 0, "index": 0, "labels": PackedStringArray()}
	return disc_snapshot if loaded else {"count": 0, "index": 0, "labels": PackedStringArray()}

func change_disc(index: int) -> bool:
	if transition_busy:
		report("Please wait for the current game operation to finish.", true)
		return false
	if not loaded: return false
	if not core.change_disc(index):
		report(str(core.last_error()), true)
		return false
	disc_snapshot = core.disc_info()
	auto_saved = false
	report("Disc %d inserted • %s" % [index + 1, rom_path.get_file().get_basename()])
	return true

## A disc ZIP still to be unpacked (see Registry.needs_unpacking).
func needs_unpacking(path: String) -> bool:
	return Registry.needs_unpacking(path)

## Unpacks a disc ZIP on a worker thread; unpack_finished reports the outcome.
## Only one disc unpacks at a time; returns false while another is under way.
func unpack_disc(path: String) -> bool:
	if not unpacking.is_empty(): return unpacking == path
	if unpack_thread != null: unpack_thread.wait_to_finish()
	unpacking = path
	unpack_cancelled = false
	unpack_reported = 0
	unpack_thread = Thread.new()
	unpack_thread.start(_unpack.bind(path))
	return true

func _unpack(path: String) -> void:
	var error: String = Registry.Archive.unpack_disc(path, func(done: int, total: int):
		# A few updates a second are plenty for a progress line.
		if done - unpack_reported >= 16 * 1024 * 1024 or done == total:
			unpack_reported = done
			unpack_progress.emit.call_deferred(path, done, total),
		func(): return unpack_cancelled)
	_unpacked.call_deferred(path, error)

func _unpacked(path: String, error: String) -> void:
	if unpack_thread != null: unpack_thread.wait_to_finish()
	unpack_thread = null
	unpacking = ""
	unpack_finished.emit(path, error)

func _exit_tree() -> void:
	if transition_thread != null and transition_thread.is_started(): transition_thread.wait_to_finish()
	transition_busy = false
	unpack_cancelled = true
	if unpack_thread != null: unpack_thread.wait_to_finish()
	save_auto()
	stop()
	if core != null: core.close()
	core = null
