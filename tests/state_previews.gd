extends SceneTree
const Store = preload("res://scripts/emulation/state_store.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://large-preview-test.rst"
	var state := PackedByteArray(); state.resize(32 * 1024 * 1024)
	var image := Image.create(32, 24, false, Image.FORMAT_RGB8); image.fill(Color.RED)
	var envelope := {"format": 1, "state": state, "saved_at": 1234567890, "game": "Old game", "thumbnail": image.save_png_to_buffer()}
	check(Store.write_state(path, envelope) == OK, "large state and preview commit")
	check(FileAccess.get_size(path + ".preview") < 4096 and not Store.metadata(path).has("state"), "sidecar contains only small display metadata")
	check(preload("res://scripts/emulation/emulation_session.gd").state_stamp(path) == 1234567890, "saved timestamp comes from the sidecar")
	DirAccess.remove_absolute(path + ".preview")
	var before := FileAccess.get_sha256(path)
	check(Store.metadata(path).is_empty(), "legacy state initially uses a placeholder")
	var previews = preload("res://scripts/emulation/state_previews.gd").new()
	root.add_child(previews)
	previews.request(path)
	var ticks := 0
	var deadline := Time.get_ticks_msec() + 5000
	while Store.metadata(path).is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(.005).timeout; ticks += 1
	check(not Store.metadata(path).is_empty() and ticks > 0, "legacy preview migrates while the scene continues")
	check(FileAccess.get_sha256(path) == before, "migration never rewrites the state")
	envelope.game = "New game"; envelope.saved_at = 1234567891
	DirAccess.remove_absolute(path + ".preview")
	var migration := Thread.new(); var writer := Thread.new()
	migration.start(func(): return Store.ensure_metadata(path))
	writer.start(func(): return Store.write_state(path, envelope))
	while migration.is_alive() or writer.is_alive(): await create_timer(.005).timeout
	migration.wait_to_finish()
	check(writer.wait_to_finish() == OK and Store.metadata(path).game == "New game", "concurrent migration cannot replace the newly saved preview")
	check(Store.read_state(path).game == "New game", "sidecar and primary state describe the same committed save")
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_8(0); file.close()
	check(Store.metadata(path).is_empty(), "a mismatched sidecar is rejected")
	previews.request(path)
	await create_timer(.1).timeout
	check(Store.metadata(path).is_empty() and previews.pending.is_empty(), "invalid legacy state does not create a retry loop")
	previews.queue_free()
	await process_frame
	print("STATE PREVIEW COMPLETE failures=", failures)
	quit(1 if failures else 0)
