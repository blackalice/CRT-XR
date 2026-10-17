extends Node
const Registry = preload("res://scripts/emulation/core_registry.gd")
## Godot owns presentation; the native Libretro host owns frame execution/callbacks.
signal content_changed(texture: Texture2D)
signal frame_presented(image: Image)
signal status_changed(message: String)
signal game_changed(active: bool)

var auto_saved := true
var core: RefCounted
var loaded := false
var paused := false
var status := "Test signal / no game loaded"
var rom_path := ""
var rom_hash := ""
var core_identity := ""
var system_id := "snes"
var save_directory := "user://saves"
var display_aspect := 4.0 / 3.0
var fps := 60.0
var accumulator := 0.0
var texture: ImageTexture
var player := AudioStreamPlayer.new()
var tv_audio := preload("res://scripts/emulation/tv_audio.gd").new()
var playback: AudioStreamGeneratorPlayback
var audio_overflows := 0
var slow_frames := 0
var sram_timer := 0.0
var sram_restore_ok := true
var skip_delta := true
var run_ahead := 1
var preview_time_usec := 0
var preview_count := 0
var gamepad := preload("res://scripts/emulation/gamepad_input.gd").new()

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
	if not ClassDB.class_exists("RetroCore"):
		report("Native emulation module missing. Build the emulator dependencies first.", true)
		return false
	if not FileAccess.file_exists(path):
		report("ROM file not found: " + path, true)
		return false
	var detected := Registry.identify(path)
	if detected.is_empty():
		report("Unsupported cartridge. Use an uncompressed SNES, NES or Sega cartridge file; .bin needs a SEGA header.", true)
		return false
	var selected_path := Registry.core_path(detected)
	if not FileAccess.file_exists(selected_path):
		report("%s core missing. Restore %s from the application package." % [Registry.SYSTEMS[detected].name, selected_path], true)
		return false
	if not save_auto(): return false
	stop()
	# Explicitly close/deinit before changing libraries: callbacks have one owner.
	if core != null: core.close()
	core = ClassDB.instantiate("RetroCore")
	system_id = detected
	display_aspect = Registry.SYSTEMS[system_id].aspect
	# Preserve existing SNES paths; new systems have independent save namespaces.
	save_directory = "user://saves" if system_id == "snes" else "user://saves/" + system_id + "/" + Registry.SYSTEMS[system_id].core
	if not core.load_core(selected_path):
		report(str(core.last_error()), true)
		core = null
		return false
	var saves := ProjectSettings.globalize_path(save_directory)
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
	auto_saved = true
	loaded = true
	paused = false
	accumulator = 0.0
	audio_overflows = 0
	slow_frames = 0
	sram_timer = 0.0
	skip_delta = true
	preview_time_usec = 0
	preview_count = 0
	var sram_path := save_directory.path_join(rom_hash + ".srm")
	sram_restore_ok = true
	if FileAccess.file_exists(sram_path):
		var ram := FileAccess.get_file_as_bytes(sram_path)
		# Genesis Plus GX writes only the modified prefix but requests its full
		# 64 KiB capacity when loading. Retain the core's erased tail bytes.
		if Registry.SYSTEMS[system_id].core == "genesis_plus_gx" and not ram.is_empty():
			var initial: PackedByteArray = core.save_ram()
			if ram.size()<initial.size():
				for i in range(ram.size()): initial[i]=ram[i]
				ram=initial
		if ram.is_empty() or not core.load_ram(ram):
			sram_restore_ok = false
			report("Could not restore SRAM: " + str(core.last_error()), true)
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
	if not loaded or paused:
		return
	if skip_delta:
		skip_delta = false
		return
	accumulator += minf(delta, 0.25)
	var period := 1.0 / fps
	var frames := 0
	var rendered := false
	var buttons := input_mask()
	while accumulator >= period and frames < 8:
		if not core.run_frame(buttons):
			set_paused(true)
			report(str(core.last_error()), true)
			return
		accumulator -= period
		frames += 1
		auto_saved = false
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
		var preview := preview_frame(buttons, run_ahead) if run_ahead > 0 else {}
		if not paused: update_texture(true, preview)
	sram_timer += delta
	if sram_timer >= 10.0:
		sram_timer = 0.0
		flush_sram()

func preview_frame(buttons: int, frames := 1) -> Dictionary:
	# Advance disposable frames for presentation only. Audio was already queued
	# from the real frames above; never enqueue preview audio.
	var started := Time.get_ticks_usec()
	var state: PackedByteArray = core.save_state()
	if state.is_empty():
		run_ahead = 0
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
		set_paused(true)
		report("Input preview could not restore game state. Reload the game with preview disabled.", true)
		run_ahead = 0
		return {}
	preview_time_usec += Time.get_ticks_usec() - started
	preview_count += 1
	if not ok:
		run_ahead = 0
		push_warning("Input preview failed; using normal presentation.")
		return {}
	return {"bytes": bytes, "width": info.width, "height": info.height}

func update_texture(force := false, preview: Dictionary = {}) -> void:
	var info: Dictionary = preview if not preview.is_empty() else core.info()
	if (not force and not info.video_changed) or int(info.width) == 0:
		return
	var bytes: PackedByteArray = preview.bytes if not preview.is_empty() else core.frame()
	var image := Image.create_from_data(int(info.width), int(info.height), false, Image.FORMAT_RGBA8, bytes)
	if texture == null or texture.get_width() != image.get_width() or texture.get_height() != image.get_height():
		texture = ImageTexture.create_from_image(image)
		content_changed.emit(texture)
	else:
		texture.update(image)
	# Reuse the CPU image already uploaded for presentation; never read the GPU.
	frame_presented.emit(image)

func input_mask() -> int:
	if gamepad.menu_active: return 0
	var mask: int = gamepad.mask()
	# Libretro joypad IDs: B,Y,Select,Start,Up,Down,Left,Right,A,X,L,R.
	var keys := [KEY_Z, KEY_A, KEY_TAB, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_X, KEY_S, KEY_Q, KEY_W]
	for id in range(12):
		var pressed := Input.is_physical_key_pressed(keys[id])
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
	tv_audio.clear_tail()
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
	if not loaded or not sram_restore_ok: return
	var ram: PackedByteArray = core.save_ram()
	if not ram.is_empty(): write_bytes_atomic(save_directory.path_join(rom_hash + ".srm"), ram)

func state_path(slot := 0) -> String:
	return save_directory.path_join("%s.slot%d.rst" % [rom_hash, slot])

static func auto_path_for(path: String) -> String:
	var system := Registry.identify(path)
	if system.is_empty(): return ""
	var folder: String = "user://saves" if system=="snes" else "user://saves/"+system+"/"+Registry.SYSTEMS[system].core
	return folder.path_join(FileAccess.get_sha256(path)+".auto.rst")

static func state_details(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<4 or file.get_length()>64*1024*1024: return {}
	var value = bytes_to_var(file.get_buffer(file.get_length()))
	if not value is Dictionary or value.get("format")!=1 or not value.get("state") is PackedByteArray: return {}
	return value

static func state_time(path: String) -> String:
	var value := state_details(path)
	var stamp := int(value.get("saved_at",FileAccess.get_modified_time(path)))
	return Time.get_datetime_string_from_unix_time(stamp).replace("T"," ")+" UTC" if stamp>0 else "Unknown time"

func save_auto() -> bool:
	if not loaded or auto_saved: return true
	if not save_to(auto_path_for(rom_path),"Automatic resume saved"): return false
	auto_saved=true
	return true

func save_state(slot := 0) -> bool:
	return save_to(state_path(slot),"Saved • Slot %d" % slot)

func save_to(path: String, description: String) -> bool:
	if not loaded: return false
	var state: PackedByteArray = core.save_state()
	if state.is_empty():
		report(str(core.last_error()), true)
		return false
	var envelope := {"format": 1, "rom": rom_hash, "core": core_identity, "state": state, "saved_at": int(Time.get_unix_time_from_system()), "game": rom_path.get_file()}
	if not write_bytes_atomic(path, var_to_bytes(envelope)):
		return false
	report("%s • %s • %s" % [description,rom_path.get_file().get_basename(),state_time(path)])
	return true

func load_state(slot := 0) -> bool:
	return load_from(state_path(slot),"Loaded • Slot %d" % slot)

func load_auto() -> bool:
	return load_from(auto_path_for(rom_path),"Continued automatic save")

func load_from(path: String, description: String) -> bool:
	if not loaded: return false
	var envelope := state_details(path)
	if envelope.get("rom")!=rom_hash or envelope.get("core")!=core_identity:
		report("Save is unreadable or does not match this ROM and core. Your save file has been kept.",true)
		return false
	if not core.load_state(envelope.state):
		report(str(core.last_error()), true)
		return false
	restart_audio()
	accumulator = 0.0
	skip_delta = true
	auto_saved=false
	update_texture(true)
	report("%s • %s • %s" % [description,rom_path.get_file().get_basename(),state_time(path)])
	return true

func stop() -> void:
	flush_sram()
	if core != null: core.close_game()
	player.stop()
	tv_audio.clear_tail()
	playback = null
	loaded = false
	paused = false
	texture = null
	game_changed.emit(false)

func _exit_tree() -> void:
	save_auto()
	stop()
	if core != null: core.close()
	core = null
