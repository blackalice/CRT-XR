extends SceneTree

var failures := 0

func check(value: bool, description: String) -> void:
	if value: print("PASS: ", description)
	else:
		push_error(description)
		failures += 1

func red(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 4 and bytes[0] > 240 and bytes[1] < 8 and bytes[2] < 8

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session = load("res://scripts/emulation/emulation_session.gd").new()
	root.add_child(session)
	session.set_process(false)
	var path := ProjectSettings.globalize_path("res://build/retrocrt-latency-probe.sfc")
	var args := OS.get_cmdline_user_args()
	var custom_rom := args.size() >= 2 and args[0] == "--rom"
	if custom_rom: path = args[1]
	if not session.load_rom(path):
		quit(1)
		return
	for i in range(90): session.core.run_frame(0)
	var initial: PackedByteArray = session.core.save_state()
	var ram: PackedByteArray = session.core.save_ram()
	var normal_response := 0
	for frame in range(1, 6):
		session.core.run_frame(1)
		if normal_response == 0 and red(session.core.frame()): normal_response = frame
	session.core.load_state(initial)
	if not ram.is_empty(): session.core.load_ram(ram)
	var preview_response := 0
	var preserved := true
	var ram_preserved := true
	for frame in range(1, 101):
		session.core.run_frame(1 if frame < 6 else 0)
		var committed: PackedByteArray = session.core.save_state()
		var committed_ram: PackedByteArray = session.core.save_ram()
		var preview: Dictionary = session.preview_frame(1 if frame < 6 else 0)
		preserved = preserved and session.core.save_state() == committed
		ram_preserved = ram_preserved and session.core.save_ram() == committed_ram
		if preview_response == 0 and not preview.is_empty() and red(preview.bytes): preview_response = frame
	check(preserved, "100 preview frames preserve the exact committed SNES state")
	check(ram_preserved, "Preview frames preserve cartridge SRAM")
	if not custom_rom or "--probe" in args:
		check(normal_response > 1 and preview_response == normal_response - 1,
			"Diagnostic input becomes visible one game frame earlier (%d -> %d)" % [normal_response, preview_response])
	var two_ok := true
	var picture_matches := true
	for frame in range(30):
		session.core.run_frame(0)
		var at_frame: PackedByteArray = session.core.save_state()
		var at_frame_ram: PackedByteArray = session.core.save_ram()
		var two: Dictionary = session.preview_frame(0, 2)
		two_ok = two_ok and not two.is_empty()
		two_ok = two_ok and session.core.save_state() == at_frame
		two_ok = two_ok and session.core.save_ram() == at_frame_ram
		session.core.run_frame(0)
		session.core.run_frame(0)
		picture_matches = picture_matches and session.core.frame() == two.bytes
	check(two_ok, "2-frame preview preserves the exact committed state and SRAM")
	check(picture_matches, "2-frame preview shows exactly the picture two game frames later")
	print("Preview cost: ", float(session.preview_time_usec) / max(1, session.preview_count) / 1000.0,
		" ms average; game-frame period: ", 1000.0 / session.fps, " ms")
	session.stop()
	session.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
