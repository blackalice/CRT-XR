extends SceneTree
var failures := 0
var app
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1
func settle():
	for i in range(8): await process_frame
func chrome(menu) -> Array:
	return [menu.heading.get_global_rect(), menu.subtitle_row.get_global_rect(), menu.sidebar_panel.get_global_rect(), menu.section_bar.get_global_rect(), menu.scroll.get_global_rect(), menu.help_frame.get_global_rect()]
func run():
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.use_tracking(false)
	await settle()
	var menu = app.menu
	check(menu.sidebar_buttons.filter(func(button): return button.visible).size() == 8, "Eight settings categories are exposed")
	check(not menu.pictures.PRESET_IDS.has("showcase"), "Obsolete picture preset is removed")
	app.picture_preset_id = "showcase"; app.picture_preset_signature = menu.pictures.picture_signature()
	check(menu.pictures.preset_caption() == "Custom", "Historical preset identity keeps its picture without a stale label")
	check(menu.catalog.pages(5).size() == 1 and menu.catalog.pages(5)[0].rows.size() == 3, "Saved setups contains three personal slots and no redundant tab")
	check(not menu.catalog.pages(2).any(func(page): return page.title == "TV effects"), "Sound no longer owns visual TV effects")
	check(not menu.catalog.pages(2).any(func(page): return page.title == "Balance") and menu.catalog.pages(2)[0].rows.any(func(row): return row.id == "music.duck_game"), "Game and music balance lives beside game volume")
	check(menu.catalog.pages(1).map(func(page): return page.title) == ["Looks", "Tube", "Colour & signal", "Fit & TV"], "Picture has four stable tabs")
	var tv_rows: Array = menu.catalog.pages(1)[3].rows
	check(tv_rows.any(func(row): return row.id == "picture.tv_policy") and not tv_rows.any(func(row): return row.id == "picture.video_policy" or row.id == "picture.cabinet" or row.id == "picture.scope"), "Idle Fit & TV shows the starting TV for games without duplicate cabinet or scope selectors")
	check(menu.catalog.pages(3).any(func(page): return page.title == "TV moments") and not menu.catalog.pages(1).any(func(page): return page.title == "TV effects"), "TV moments have one home under Room")
	for category in menu.SETTINGS_ORDER:
		check(menu.catalog.pages(category).size() <= 5, "%s has at most five tabs" % menu.CATEGORIES[category])
	check(not menu.catalog.pages(10).any(func(page): return page.title.contains("VMU")), "Console accessories stay out of unrelated sessions")
	var room_pages: Array = menu.catalog.pages(3)
	check(room_pages[1].rows.any(func(row): return row.id == "room.spill_strength") and room_pages[1].rows.any(func(row): return row.id == "room.screen_bloom"), "Screen glow and bloom are lighting controls")
	for large in [false, true]:
		app.menu_large_text = large
		for kind in ["keyboard", "controller"]:
			menu.set_input_kind(kind)
			var reference: Array = []
			for category in menu.SETTINGS_ORDER:
				for section in range(menu.catalog.pages(category).size()):
					menu.mode = "settings"; menu.category = category; menu.subsection = section; menu.preview = false; menu.render()
					await settle()
					if reference.is_empty(): reference = chrome(menu)
					check(chrome(menu) == reference, "Settings frame stays fixed: %d/%d %s large=%s" % [category,section,kind,large])
	menu.open_settings_section(8, "Picture")
	check(menu.category == 8 and menu.sidebar_buttons[8].visible, "Video shortcut reaches the Videos category")
	menu.open_pause()
	menu.music.open_music_browser(ProjectSettings.globalize_path("user://"))
	check(menu.items.any(func(item): return item.id == "music.radio") and menu.items.any(func(item): return item.id == "music.visualiser"), "Radio and the visualiser are played from the music browser")
	menu.select("music.settings", false); menu.activate()
	check(menu.catalog.pages(menu.category)[menu.subsection].title == "Music" and menu.items.any(func(item): return item.id == "visualiser.preset"), "Music shortcut reaches music and visualiser preferences")
	menu.back()
	check(menu.mode == "music_browser" and menu.selected_id == "music.settings", "Back returns to the music folder and shortcut")
	app.free()
	await process_frame
	print("SETTINGS STRUCTURE COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
