extends Node
## Godot owns presentation; the native Libretro host owns frame execution/callbacks.
signal content_changed(texture: Texture2D)
signal status_changed(message: String)
signal game_changed(active: bool)

var core: RefCounted
var loaded := false
var paused := false
var status := "Test signal / no game loaded"
var rom_path := ""
var rom_hash := ""
var core_identity := ""
var fps := 60.0
var accumulator := 0.0
var texture: ImageTexture
var player := AudioStreamPlayer.new()
var playback: AudioStreamGeneratorPlayback
var audio_overflows := 0
var slow_frames := 0
var sram_timer := 0.0
var skip_delta := true

func _ready() -> void:
	add_child(player)
	player.volume_db = -6.0

func report(message: String, failure := false) -> void:
	status = message
	status_changed.emit(message)
	if failure: push_error(message)
	else: print("Emulation: ", message)

func default_core_path() -> String:
	if not OS.get_environment("RETROCRT_CORE").is_empty():
		return OS.get_environment("RETROCRT_CORE")
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	return base.path_join("cores/snes9x_libretro." + ("dll" if OS.get_name() == "Windows" else "so"))

func load_rom(path: String) -> bool:
	if not ClassDB.class_exists("RetroCore"):
		report("Native emulation module missing. Build the emulator dependencies first.", true)
		return false
	if not FileAccess.file_exists(path):
		report("ROM file not found: " + path, true)
		return false
	stop()
	if core == null:
		core = ClassDB.instantiate("RetroCore")
		if not core.load_core(default_core_path()):
			report(str(core.last_error()), true)
			core = null
			return false
	var saves := ProjectSettings.globalize_path("user://saves")
	var error := DirAccess.make_dir_recursive_absolute(saves)
	if error != OK:
		report("Cannot create save directory: " + error_string(error), true)
		return false
	if not core.load_game(path, saves):
		report(str(core.last_error()), true)
		return false
	rom_path = path
	rom_hash = FileAccess.get_sha256(path)
	var info: Dictionary = core.info()
	core_identity = str(info.name)
	fps = float(info.fps)
	loaded = true
	paused = false
	accumulator = 0.0
	audio_overflows = 0
	slow_frames = 0
	sram_timer = 0.0
	skip_delta = true
	var sram_path := "user://saves/" + rom_hash + ".srm"
	if FileAccess.file_exists(sram_path):
		var ram := FileAccess.get_file_as_bytes(sram_path)
		if ram.is_empty() or not core.load_ram(ram):
			report("Could not restore SRAM: " + str(core.last_error()), true)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = float(info.sample_rate)
	generator.buffer_length = 0.10
	player.stream = generator
	restart_audio()
	game_changed.emit(true)
	report("%s / %s / %.3f fps" % [path.get_file(), core_identity, fps])
	return true

func _process(delta: float) -> void:
	if not loaded or paused:
		return
	if skip_delta:
		skip_delta = false
		return
	accumulator += minf(delta, 0.25)
	var period := 1.0 / fps
	var frames := 0
	var rendered := false
	while accumulator >= period and frames < 8:
		if not core.run_frame(input_mask()):
			set_paused(true)
			report(str(core.last_error()), true)
			return
		accumulator -= period
		frames += 1
		rendered = rendered or bool(core.info().video_changed)
		if playback != null and core.push_audio(playback) < 0:
			audio_overflows += 1
			if audio_overflows == 1 or audio_overflows % 300 == 0:
				push_warning("Audio buffer full; dropped an audio batch. Check frame pacing.")
	if accumulator >= period:
		slow_frames += 1
		accumulator = fmod(accumulator, period)
		if slow_frames == 1 or slow_frames % 300 == 0:
			push_warning("Emulator cannot keep up with real time; reduce rendering load")
	if rendered:
		update_texture(true)
	sram_timer += delta
	if sram_timer >= 10.0:
		sram_timer = 0.0
		flush_sram()

func update_texture(force := false) -> void:
	var info: Dictionary = core.info()
	if (not force and not info.video_changed) or int(info.width) == 0:
		return
	var bytes: PackedByteArray = core.frame()
	var image := Image.create_from_data(int(info.width), int(info.height), false, Image.FORMAT_RGBA8, bytes)
	if texture == null or texture.get_width() != image.get_width() or texture.get_height() != image.get_height():
		texture = ImageTexture.create_from_image(image)
		content_changed.emit(texture)
	else:
		texture.update(image)

func input_mask() -> int:
	var mask := 0
	# Libretro joypad IDs: B,Y,Select,Start,Up,Down,Left,Right,A,X,L,R.
	var keys := [KEY_Z, KEY_A, KEY_TAB, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_X, KEY_S, KEY_Q, KEY_W]
	var buttons := [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]
	var pads := Input.get_connected_joypads()
	for id in range(12):
		var pressed := Input.is_physical_key_pressed(keys[id])
		if not pads.is_empty(): pressed = pressed or Input.is_joy_button_pressed(pads[0], buttons[id])
		if pressed: mask |= 1 << id
	return mask

func set_paused(value: bool) -> void:
	paused = value
	accumulator = 0.0
	skip_delta = true
	restart_audio()
	if loaded: report(("Paused / " if paused else "Playing / ") + rom_path.get_file())

func restart_audio() -> void:
	# Godot forbids clearing an active generator. Stop it and obtain a new
	# playback instead; the headless Dummy driver does not need an audio queue.
	player.stop()
	playback = null
	if loaded and not paused and DisplayServer.get_name() != "headless":
		player.play()
		playback = player.get_stream_playback()

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
	if not loaded: return
	var ram: PackedByteArray = core.save_ram()
	if not ram.is_empty(): write_bytes_atomic("user://saves/" + rom_hash + ".srm", ram)

func save_state(slot := 0) -> bool:
	if not loaded: return false
	var state: PackedByteArray = core.save_state()
	if state.is_empty():
		report(str(core.last_error()), true)
		return false
	var envelope := {"format": 1, "rom": rom_hash, "core": core_identity, "state": state}
	if not write_bytes_atomic("user://saves/%s.slot%d.rst" % [rom_hash, slot], var_to_bytes(envelope)):
		return false
	report("Saved state / slot %d" % slot)
	return true

func load_state(slot := 0) -> bool:
	if not loaded: return false
	var path := "user://saves/%s.slot%d.rst" % [rom_hash, slot]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		report("No readable state in slot %d" % slot, true)
		return false
	if file.get_length() > 64 * 1024 * 1024:
		report("Save state exceeds size limit", true)
		return false
	var envelope = bytes_to_var(file.get_buffer(file.get_length()))
	if not envelope is Dictionary or envelope.get("format") != 1 or envelope.get("rom") != rom_hash or envelope.get("core") != core_identity or not envelope.get("state") is PackedByteArray:
		report("Save state does not match this ROM and core", true)
		return false
	if not core.load_state(envelope.state):
		report(str(core.last_error()), true)
		return false
	restart_audio()
	accumulator = 0.0
	skip_delta = true
	report("Loaded state / slot %d" % slot)
	return true

func stop() -> void:
	flush_sram()
	if core != null: core.close_game()
	player.stop()
	playback = null
	loaded = false
	paused = false
	texture = null
	game_changed.emit(false)

func _exit_tree() -> void:
	stop()
	if core != null: core.close()
	core = null
