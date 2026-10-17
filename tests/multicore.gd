extends SceneTree
const Registry = preload("res://scripts/emulation/core_registry.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session = load("res://scripts/emulation/emulation_session.gd").new()
	root.add_child(session)
	session.set_process(false)
	var library = load("res://scripts/ui/rom_library.gd").new()
	check(library.show_folder(ProjectSettings.globalize_path("res://build")), "ROM browser opens diagnostic folder")
	for ext in ["nes","md","sms","gg"]:
		check(library.entries.any(func(entry): return entry.path.ends_with("crt-xr-probe."+ext)), "Browser includes "+ext)
	for pair in [["sfc","snes"],["nes","nes"],["md","megadrive"],["md","megadrive"],["sms","mastersystem"],["gg","gamegear"],["nes","nes"],["sfc","snes"]]:
		var path := ProjectSettings.globalize_path("res://build/crt-xr-probe."+pair[0])
		check(session.load_rom(path), "Loads/switches to "+pair[1])
		if not session.loaded: continue
		print("CORE: ", session.core_identity)
		check(session.system_id==pair[1], "Selected correct system")
		check(session.sram_restore_ok,"Battery saves load without a size mismatch")
		check(session.state_path().begins_with("user://saves/"+pair[1]+"/") if pair[1]!="snes" else session.state_path()=="user://saves/%s.slot0.rst" % session.rom_hash, "Namespaced saves, legacy SNES path retained")
		var executed := true
		for i in range(90): executed = session.core.run_frame(0) and executed
		var info: Dictionary = session.core.info()
		check(executed and info.width>0 and info.height>0, "Executes 90 frames and returns video")
		check(info.audio_frames>0, "Core audio callback runs")
		check(session.save_state() and session.load_state(), "State round-trip")
		var normal: PackedByteArray = session.core.frame()
		if pair[0] in ["nes","md"]:
			print("PIXEL normal: ",normal.slice(normal.size()/2,normal.size()/2+4))
			var event := InputEventJoypadButton.new()
			event.device=99; event.button_index=JOY_BUTTON_A; event.pressed=true
			session.gamepad.handle_event(event)
			for i in range(8): session.core.run_frame(session.input_mask())
			event.pressed=false; session.gamepad.handle_event(event)
			var pressed: PackedByteArray = session.core.frame()
			print("PIXEL pressed: ",pressed.slice(pressed.size()/2,pressed.size()/2+4))
			check(normal!=pressed, "Physical bottom button reaches game B")
		var before: PackedByteArray = session.core.save_state()
		session.preview_frame(0,1)
		check(session.core.save_state()==before and session.run_ahead>0, "Latency preview restores core state")
		session.update_texture(true)
		check(session.texture!=null, "Frame uploaded to presentation texture")
		if pair[0] in ["nes","md"]:
			session.flush_sram()
			var ram: PackedByteArray = FileAccess.get_file_as_bytes(session.save_directory.path_join(session.rom_hash+".srm"))
			check(not ram.is_empty() and 0x5A in ram, "Cartridge battery RAM persisted")
		check(is_equal_approx(session.display_aspect,10.0/9.0 if pair[1]=="gamegear" else 4.0/3.0), "System display proportions")
	var copy := FileAccess.get_file_as_bytes("res://build/crt-xr-probe.md")
	var bin := FileAccess.open("user://probe.bin",FileAccess.WRITE); bin.store_buffer(copy); bin.close()
	check(Registry.identify("user://probe.bin")=="megadrive", "Ambiguous .bin accepts Sega header")
	bin = FileAccess.open("user://unrelated.bin",FileAccess.WRITE); bin.store_buffer(PackedByteArray([1,2,3])); bin.close()
	check(Registry.identify("user://unrelated.bin").is_empty(), "Unrelated binary is not treated as a game")
	for ext in ["nes", "md"]:
		check(session.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe-pal."+ext)) and session.fps<55.0, "PAL console timing: "+ext)
	var fitting = load("res://scripts/rendering/picture_pipeline.gd").new()
	fitting.source_aspect=10.0/9.0
	var area: Rect2 = fitting.picture_rect()
	check(is_equal_approx(fitting.tube_aspect*area.size.x/area.size.y,10.0/9.0), "Handheld image fits tube without stretching")
	fitting.free()
	OS.set_environment("CRT_XR_CORE","missing-core.dll")
	check(not session.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe.nes")) and session.loaded, "Missing core leaves running game intact")
	OS.set_environment("CRT_XR_CORE","")
	session.stop(); session.queue_free()
	await process_frame
	print("Multicore checks complete: ",failures," failures")
	quit(1 if failures else 0)
