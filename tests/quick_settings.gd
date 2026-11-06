extends SceneTree
var app
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func settle() -> void:
	for i in range(8): await process_frame
func fits(context: String) -> void:
	var menu = app.menu
	var overflow := false
	for row in menu.rows:
		menu.select(row.item.id, false)
		await settle()
		overflow = overflow or menu.column.size.y > menu.scroll.size.y + 1.0
		if menu.column.size.y > menu.scroll.size.y + 1.0:
			print("Overflow: ", row.item.id, " content=", menu.column.size.y, " room=", menu.scroll.size.y)
	check(not overflow, context + " has no scrolling for any default selection")
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.use_tracking(false)
	await settle()
	app.apply_settings(ConfigFile.new())
	app.last_game_path = ""; app.default_rom_dir = ""; app.music.stop()
	var menu = app.menu
	menu.open_pause()
	await fits("First-run Home")
	menu.select("pause.view.height_offset",false); await settle()
	var height_row = menu.selected_row()
	var height_size: Vector2 = height_row.size
	var height_lines: int = height_row.title_label.get_line_count()
	for offset in [-1.5,-0.15,0.05,1.5,0.0]:
		app.height_offset=offset; height_row.refresh(); await settle()
		check(height_row.size==height_size and height_row.title_label.get_line_count()==height_lines and height_row.title_label.text==height_row.item.label, "Height dot cannot alter the tile layout at %.2f m" % offset)
		check(menu.column.size.y<=menu.scroll.size.y+1.0, "Changed height keeps the default Home free of scrolling")
	var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
	app.last_game_path = rom; menu.open_pause()
	await fits("Home with Continue")
	check(app.emulator.load_rom(rom), "Diagnostic game loads for pause/preview checks")
	app.emulator.set_paused(true); menu.open_pause()
	await fits("Paused game")
	for kind in ["controller", "keyboard"]:
		menu.set_input_kind(kind)
		for id in ["pause.view.distance", "pause.view.height_offset"]:
			menu.select(id, false); menu.activate(); await settle()
			check(menu.preview and menu.mode == "pause" and not menu.body.visible and not app.tv_menu.active, id + " opens the floating placement preview: " + kind)
			var before: float = app.distance if id.ends_with("distance") else app.height_offset
			menu.navigate(Vector2i.RIGHT); await settle()
			var after: float = app.distance if id.ends_with("distance") else app.height_offset
			check(after > before and app.emulator.paused, "Preview adjusts the real placement while the game stays paused")
			menu.reset_option()
			check(is_equal_approx(app.distance if id.ends_with("distance") else app.height_offset, app.Showcase.VIEW.distance if id.ends_with("distance") else app.Showcase.VIEW.height_offset), "Y restores the placement default")
			menu.back(); await settle()
			check(not menu.preview and menu.selected_id == id and menu.column.size.y <= menu.scroll.size.y + 1.0, "Back returns to the same quick tile without a scrollbar")
	menu.select("pause.view.distance", false); menu.activate(); await settle()
	menu.navigate(Vector2i.DOWN)
	check(menu.selected_id == "pause.view.height_offset" and menu.preview, "Preview up/down switches between the two placement controls")
	menu.back(); await settle()
	check(not menu.items.any(func(item):return item.id=="pause.music_volume"), "Quick settings no longer duplicates music volume")
	menu.select("pause.display", false); menu.activate()
	var previous: int=app.display_settings.display_choice()
	menu.navigate(Vector2i.RIGHT)
	check(app.display_settings.display_choice()==(previous+1)%6 and not menu.preview, "Quick Display switches the current game's TV and fitting in place")
	check(menu.selected_id=="pause.display" and menu.editing_id=="pause.display", "Display switch preserves controller focus and adjustment mode")
	menu.back()
	app.free()
	print("QUICK SETTINGS: ", failures, " failures")
	quit(1 if failures else 0)
