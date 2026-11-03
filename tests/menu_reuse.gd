extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func ids(menu) -> Array:
	return menu.rows.map(func(row): return row.get_instance_id())
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(3): await process_frame
	check(app.load_game(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")), "diagnostic game loads")
	var menu = app.menu
	menu.open_pause()
	var original := ids(menu)
	menu.open_pause()
	check(ids(menu) == original, "unchanged pause menu retains its controls")
	check(menu.rows.filter(func(row): return row.item.get("layout", "") == "tile").all(func(row): return row.item.has("tile_index") and row.item.has("tile_columns")), "reused tiles retain directional navigation metadata")
	var save_path: String = app.emulator.state_path()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_8(0); file.close()
	menu.open_pause()
	check(ids(menu) == original and not menu.rows.filter(func(row): return row.item.id == "load_state")[0].item.disabled, "save availability refreshes without rebuilding controls")
	DirAccess.remove_absolute(save_path)
	menu.open_settings()
	menu.open_pause()
	check(ids(menu) == original, "pause controls survive visiting another page")
	check(menu.rows.all(func(row): return row.is_inside_tree() and row.is_visible_in_tree()), "restored controls are attached and visible")
	app.menu_large_text = not app.menu_large_text
	menu.open_pause()
	check(ids(menu) != original, "accessibility changes invalidate the cached layout")
	menu.hide()
	menu.discard_pause_cache()
	menu.call("prepare_pause")
	menu.show()
	menu.open_settings()
	for i in range(8): await process_frame
	check(menu.mode == "settings" and menu.visible and not menu.preparing_pause, "opening another page safely cancels hidden preparation")
	menu.open_pause()
	menu.select("resume", false)
	menu.activate()
	check(not menu.visible, "retained controls still invoke their actions")
	app.queue_free()
	await process_frame
	print("MENU REUSE COMPLETE failures=", failures)
	quit(1 if failures else 0)
