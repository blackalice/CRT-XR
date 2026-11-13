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
	check(menu.items.filter(func(item): return item.get("quick", false)).map(func(item): return item.id) == ["pause.room", "pause.preset", "pause.game_volume", "pause.view.distance", "pause.tv", "pause.fit"], "Six quick tiles: room, picture, volume, TV position, TV and fit")
	menu.select("pause.view.distance",false); await settle()
	var position_row = menu.selected_row()
	check(position_row.item.label == "TV position", "The placement tile is called TV position")
	var position_size: Vector2 = position_row.size
	var position_lines: int = position_row.title_label.get_line_count()
	for value in [1.2, 2.0, 4.95, app.Showcase.VIEW.distance]:
		app.distance=value; position_row.refresh(); await settle()
		check(position_row.size==position_size and position_row.title_label.get_line_count()==position_lines and position_row.title_label.text==position_row.item.label, "Changed-value dot cannot alter the tile layout at %.2f m" % value)
		check(menu.column.size.y<=menu.scroll.size.y+1.0, "A changed distance keeps the default Home free of scrolling")
	var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
	app.last_game_path = rom; menu.open_pause()
	await fits("Home with Continue")
	check(app.emulator.load_rom(rom), "Diagnostic game loads for pause/preview checks")
	app.emulator.set_paused(true); menu.open_pause()
	await fits("Paused game")
	for kind in ["controller", "keyboard"]:
		menu.set_input_kind(kind)
		for id in ["pause.view.distance", "pause.view.height_offset"]:
			# TV position opens the preview; height is the second control inside it.
			menu.select("pause.view.distance", false); menu.activate(); await settle()
			if id.ends_with("height_offset"): menu.navigate(Vector2i.DOWN); await settle()
			check(menu.preview and menu.mode == "pause" and not menu.body.visible and not app.tv_menu.active, id + " opens the floating placement preview: " + kind)
			var before: float = app.distance if id.ends_with("distance") else app.height_offset
			menu.navigate(Vector2i.RIGHT); await settle()
			var after: float = app.distance if id.ends_with("distance") else app.height_offset
			check(after > before and app.emulator.paused, "Preview adjusts the real placement while the game stays paused")
			menu.reset_option()
			check(is_equal_approx(app.distance if id.ends_with("distance") else app.height_offset, app.Showcase.VIEW.distance if id.ends_with("distance") else app.Showcase.VIEW.height_offset), "Y restores the placement default")
			menu.back(); await settle()
			check(not menu.preview and menu.selected_id == "pause.view.distance" and menu.column.size.y <= menu.scroll.size.y + 1.0, "Back returns to the TV position tile without a scrollbar")
	menu.select("pause.view.distance", false); menu.activate(); await settle()
	menu.navigate(Vector2i.DOWN)
	check(menu.selected_id == "pause.view.height_offset" and menu.preview, "Preview up/down switches between the two placement controls")
	menu.back(); await settle()
	check(not menu.items.any(func(item):return item.id=="pause.music_volume"), "Quick settings no longer duplicates music volume")
	var previous: int=app.display_settings.display_choice()
	menu.select("pause.tv", false); menu.activate()
	menu.navigate(Vector2i.RIGHT)
	var now: int = app.display_settings.display_choice()
	check(now / 3 != previous / 3 and now % 3 == previous % 3 and app.world.widescreen == (now >= 3) and not menu.preview, "The TV tile switches the TV and keeps the fit")
	check(menu.selected_id=="pause.tv" and menu.editing_id=="pause.tv", "The TV switch keeps focus and adjustment mode")
	menu.back()
	menu.select("pause.fit", false); menu.activate()
	menu.navigate(Vector2i.RIGHT)
	var fitted: int = app.display_settings.display_choice()
	check(fitted / 3 == now / 3 and fitted % 3 == (now % 3 + 1) % 3, "The Fit tile changes the fit and keeps the TV")
	menu.back()
	app.free()
	print("QUICK SETTINGS: ", failures, " failures")
	quit(1 if failures else 0)
