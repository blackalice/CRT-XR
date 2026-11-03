extends SceneTree
var failures := 0
var ticks := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session = preload("res://scripts/emulation/emulation_session.gd").new()
	root.add_child(session)
	session.set_process(false)
	process_frame.connect(func(): ticks += 1)
	var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
	check(await session.load_rom_async(rom), "background load publishes a ready game")
	check(ticks > 0 and not session.transition_busy, "scene updates continue through native loading")
	for i in range(5): session.core.run_frame(0)
	session.auto_saved = false
	var automatic: String = session.auto_path()
	var directory: String = session.save_directory
	check(await session.stop_for_launch(), "automatic save and core shutdown finish in the background")
	check(not session.loaded and session.core == null and not session.transition_busy, "shutdown publishes an empty session")
	check(not session.state_details(automatic).get("state", PackedByteArray()).is_empty(), "automatic resume is committed before unloading")
	check(await session.load_rom_async(rom) and await session.load_auto_async(), "background Continue restores the saved game")
	check(session.loaded and not session.transition_busy, "Continue publishes a usable session")
	session.save_directory = "user://nonexistent-async-test-parent/saves"
	session.auto_saved = false
	check(not await session.stop_for_launch(), "failed automatic save cancels teardown")
	check(session.loaded and session.core != null and not session.transition_busy and FileAccess.file_exists(automatic), "failed save retains the playing core and previous resume")
	session.save_directory = directory
	session.stop()
	session.queue_free()
	await process_frame
	print("ASYNC LOAD COMPLETE failures=", failures)
	quit(1 if failures else 0)
