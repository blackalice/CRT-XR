extends Node
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Layouts = preload("res://scripts/emulation/controller_layouts.gd")
## Godot owns presentation; the native Libretro host owns frame execution/callbacks.
signal content_changed(texture: Texture2D)
signal frame_presented(image: Image)
signal status_changed(message: String)
signal game_changed(active: bool)
## A disc ZIP being unpacked before play: bytes done of total, then the outcome
## ("" when the disc is ready).
signal unpack_progress(path: String, done: int, total: int)
signal unpack_finished(path: String, error: String)

var auto_saved := true
var core: RefCounted
var loaded := false
var paused := false
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
		report("%s core missing. Restore %s from the application package." % [Registry.SYSTEMS[detected].name, selected_path], true)
		return false
	if not Registry.bios_satisfied(detected):
		report("%s needs its BIOS. Put one of %s in the bios folder next to your roms folder, or in %s, then reload the game." % [Registry.SYSTEMS[detected].name, ", ".join(PackedStringArray(Registry.SYSTEMS[detected].bios_any)), Registry.preferred_bios_folder()], true)
		return false
	# Checked before the playing game stops: the menu unpacks discs beforehand.
	if Registry.needs_unpacking(path):
		report("The disc in " + path.get_file() + " has to be unpacked first. Choose the game again from the library.", true)
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
	core.set_hardware_rendering(Registry.SYSTEMS[system_id].get("hardware", false))
	if not core.load_core(selected_path):
		report(str(core.last_error()), true)
		core = null
		return false
	var saves := ProjectSettings.globalize_path(save_directory)
	var error := DirAccess.make_dir_recursive_absolute(saves)
	if error != OK:
		report("Cannot create save directory: " + error_string(error), true)
		return false
	Registry.stage_bios(system_id, saves)
	var spec: Dictionary = Registry.SYSTEMS[system_id]
	if spec.has("controller"): core.set_controller(spec.controller)
	for key in spec.get("options", {}): core.set_option(key, spec.options[key])
	var content := Registry.content_file(path)
	if content.is_empty():
		report("Could not unpack the game from " + path.get_file() + ". Its ZIP may be damaged or use a compression method other than Deflate.", true)
		return false
	if not core.load_game(content, saves):
		report(str(core.last_error()), true)
		return false
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
	reload_controls()
	core_identity = str(info.name)
	fps = float(info.fps)
	auto_saved = true
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
		if ram.is_empty() or not core.load_ram(ram):
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
	if not loaded or paused:
		return
	if skip_delta:
		skip_delta = false
		return
	accumulator += minf(delta, 0.25)
	late_pressure = maxf(0.0, late_pressure - delta * 2.0)
	var period := 1.0 / fps
	var frames := 0
	var rendered := false
	var input := read_input()
	var buttons: int = input.mask
	var sticks: PackedInt32Array = input.analog
	core.set_analog(sticks[0], sticks[1], sticks[2], sticks[3])
	while accumulator >= period and frames < 8:
		if not core.run_frame(buttons):
			set_paused(true)
			report(str(core.last_error()), true)
			return
		accumulator -= period
		frames += 1
		auto_saved = false
		rendered = rendered or core.video_changed()
		if playback != null and core.push_audio(playback) < 0:
			audio_overflows += 1
			if audio_overflows == 1 or audio_overflows % 300 == 0:
				push_warning("Audio buffer full; dropped an audio batch. Check frame pacing.")
	if accumulator >= period:
		slow_frames += 1
		accumulator = fmod(accumulator, period)
		late_pressure += 1.0
		if run_ahead > 0 and not preview_suspended and late_pressure >= PREVIEW_SUSPEND_PRESSURE:
			preview_suspended = true
			if core != null: core.close_preview()
			preview_copy = ""
			report("Input preview paused for this game: it needs the full frame time.", true)
		if slow_frames == 1 or slow_frames % 300 == 0:
			push_warning("Emulator cannot keep up with real time; reduce rendering load")
	if rendered:
		var preview := preview_frame(buttons, run_ahead) if run_ahead > 0 and preview_possible() else {}
		if not paused: update_texture(true, preview)
	sram_timer += delta
	if sram_timer >= 10.0:
		sram_timer = 0.0
		flush_sram()

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
	if gamepad.menu_active: return {"mask": 0, "analog": PackedInt32Array([0, 0, 0, 0])}
	# Before a game loads, the current console's standard layout.
	var layout: Dictionary = controls if not controls.is_empty() else Layouts.standard(system_id, Registry.SYSTEMS[system_id])
	var input: Dictionary = gamepad.read(layout)
	for id in range(12):
		if Input.is_physical_key_pressed(KEYBOARD_PAD[id]): input.mask |= 1 << id
	return input

## Applies the layout saved for this game, or for its console, or the standard one.
func reload_controls() -> void:
	controls = Layouts.resolve(system_id, Registry.SYSTEMS[system_id], rom_hash)
	# The right stick moves the TV only while the game has no use for it.
	gamepad.right_stick_game = controls.right_stick != "buttons" or controls.buttons.keys().any(func(input): return input.begins_with("rs_"))

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
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<4 or file.get_length()>64*1024*1024: return {}
	var value = bytes_to_var(file.get_buffer(file.get_length()))
	if not value is Dictionary or value.get("format")!=1 or not value.get("state") is PackedByteArray: return {}
	return value

## When a state was saved (Unix time), or 0 when unknown.
static func state_stamp(path: String) -> int:
	return int(state_details(path).get("saved_at", FileAccess.get_modified_time(path)))

static func state_time(path: String) -> String:
	var value := state_details(path)
	var stamp := int(value.get("saved_at",FileAccess.get_modified_time(path)))
	return Time.get_datetime_string_from_unix_time(stamp).replace("T"," ")+" UTC" if stamp>0 else "Unknown time"

func save_auto() -> bool:
	if not loaded or auto_saved: return true
	if not save_to(auto_path(),"Automatic resume saved"): return false
	auto_saved=true
	return true

func save_state(slot := 0) -> bool:
	return save_to(state_path(slot),"Saved • Slot %d" % (slot + 1))

func save_to(path: String, description: String) -> bool:
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
	if not write_bytes_atomic(path, var_to_bytes(envelope)):
		return false
	report("%s • %s" % [description,rom_path.get_file().get_basename()])
	return true

## The console's reset button: the game restarts; battery saves and states are kept.
func reset_game() -> bool:
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
	report("%s • %s" % [description,rom_path.get_file().get_basename()])
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
	last_frame = null
	controls = {}
	gamepad.right_stick_game = false
	game_changed.emit(false)

## The loaded game's discs: {count, index, labels}; count is 0 for one-disc games.
func disc_info() -> Dictionary:
	return core.disc_info() if loaded else {"count": 0, "index": 0, "labels": PackedStringArray()}

func change_disc(index: int) -> bool:
	if not loaded: return false
	if not core.change_disc(index):
		report(str(core.last_error()), true)
		return false
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
	unpack_cancelled = true
	if unpack_thread != null: unpack_thread.wait_to_finish()
	save_auto()
	stop()
	if core != null: core.close()
	core = null
