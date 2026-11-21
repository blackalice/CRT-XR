extends SceneTree
## Linked looks: consoles and games share a named picture; editing it updates
## them all; a game's own changes sit on top; fitting never travels with a look;
## share codes carry only picture values. Also Basic settings and Scenes.
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func settle(frames := 6) -> void:
	for i in range(frames): await process_frame

func run():
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle(10)
	app.apply_settings(ConfigFile.new()); app.use_tracking(false)
	var m = app.menu
	if not app.settings_panel.visible: app.toggle_settings()
	await settle()
	var p = app.display_settings
	# A pretend SNES game, as begin_context would set it up.
	p.leave_context(); p.kind = "game"; p.system = "snes"; p.content = "abc123"; p.scope = 0
	p.refresh_screen()
	var base_scan: float = app.scanlines

	var look: String = p.create_look("Sonic era", {"crt.scanlines": 0.6, "picture.saturation": 1.3, "picture.width": 0.5})
	check(p.look_exists(look) and p.look_name(look) == "Sonic era", "A look is created with its name")
	check(not p.data.pictures["look." + look].has("picture.width"), "Fitting values never go into a look")
	p.link_look("platform.snes", look)
	check(is_equal_approx(app.scanlines, 0.6), "All SNES games use the console's look")
	check(p.field_source("crt.scanlines") == "Using look", "The row says the value comes from the look")
	# A game's own change sits on top of the look.
	app.scanlines = 0.2; p.commit(); p.resolve_picture()
	check(is_equal_approx(app.scanlines, 0.2), "A game's own change wins over its look")
	m.looks.menu = m
	check(m.looks.own_changes() == 1, "This game has one change of its own")
	var key: String = "game." + p.screen_id() + ".content.abc123"
	p.data.pictures.erase(key); p.applied.clear(); p.resolve_picture()
	check(is_equal_approx(app.scanlines, 0.6), "Without its own change, the game shows the look again")

	# Editing the look changes everything that uses it.
	p.begin_look_edit(look)
	check(p.context_label() == "Look · Sonic era" and m.catalog.picture_scope().is_empty(), "Editing a look names it and hides the scope strip")
	app.scanlines = 0.45
	app.world.picture.values["width"] = 0.7
	p.end_look_edit()
	check(is_equal_approx(float(p.data.pictures["look." + look]["crt.scanlines"]), 0.45), "Edits while editing a look are saved in the look")
	check(not p.data.pictures["look." + look].has("picture.width"), "Fitting changed while editing a look stays out of it")
	check(is_equal_approx(app.scanlines, 0.45), "The game shows the edited look at once")

	# A game-level look beats the console's; by path for games picked from the library.
	var other: String = p.create_look("Arcade sharp", {"crt.scanlines": 0.1})
	p.link_look("game.abc123", other)
	check(is_equal_approx(app.scanlines, 0.1), "A game's own look beats the console look")
	check(p.look_usage(look).consoles == ["snes"] and p.look_usage(other).games == 1, "Usage counts consoles and games")
	check(m.looks.usage_text(look) == "All SNES", "Usage reads All SNES")
	p.link_look("game.abc123", "")
	check(p.look_for_game("", "/roms/snes/a.sfc") == "", "An unlinked path has no look")
	p.link_look("path./roms/snes/a.sfc", other)
	check(p.look_for_game("zzz", "/roms/snes/a.sfc") == other, "Games picked from the library link by path")

	# Sharing: name and picture values only; unknown fields are dropped.
	var code: String = p.look_share_code(look)
	check(code.begins_with("CRTXR-LOOK1:"), "A share code starts with its marker")
	var copied: String = p.import_look("Try this: " + code + " (from a friend)")
	check(not copied.is_empty() and p.look_name(copied) == "Sonic era" and is_equal_approx(float(p.data.pictures["look." + copied]["crt.scanlines"]), 0.45), "A share code adds the same look")
	var forged: String = p.LOOK_SHARE_PREFIX + Marshalls.utf8_to_base64(JSON.stringify({"name": "x", "values": {"picture.width": 9, "evil.field": 1, "crt.scanlines": "bad"}}))
	check(p.import_look(forged).is_empty(), "A code with no usable picture values adds nothing")
	check(p.import_look("hello").is_empty(), "Text that isn't a code adds nothing")

	# Duplicate, rename and delete.
	var twin: String = p.duplicate_look(look)
	check(p.look_name(twin) == "Sonic era copy" and p.look_usage(twin).consoles.is_empty(), "Duplicate is a new look used by nothing")
	p.rename_look(twin, "   ")
	check(p.look_name(twin) == "My look", "An empty name falls back to My look")
	p.delete_look(look)
	check(not p.look_exists(look) and p.look_for_console("snes") == "", "Deleting a look unlinks its console")
	check(is_equal_approx(app.scanlines, base_scan), "The console goes back to its own picture")

	# The Looks tab lists your looks and offers new and shared ones.
	var ids: Array = m.looks.rows().map(func(row): return row.id)
	check(ids.has("look.new") and ids.has("look.paste") and ids.has("look.open." + other), "Picture → Looks lists your looks, New look and Add a shared look")
	m.looks.open(other); await settle()
	check(m.mode == "look" and m.items.any(func(item): return item.id == "look.choose"), "A look's page offers Choose games and consoles")
	m.looks.open_chooser(""); await settle()
	check(m.mode == "look_games", "Choose opens the console list")
	m.back(); await settle()
	check(m.mode == "look", "Back returns to the look")

	# Old My looks slots become looks once.
	p.data.erase("looks_migrated")
	var saved := ConfigFile.new(); saved.set_value("crt", "scanlines", 0.33); saved.set_value("meta", "name", "Old favourite")
	app.SettingsStore.write(m.pictures.my_preset_path(0), saved)
	m.looks.migrate_presets()
	check(p.look_list().any(func(pair): return pair[1] == "Old favourite"), "A saved My looks slot becomes a look with its name")
	var count: int = p.look_list().size()
	m.looks.migrate_presets()
	check(p.look_list().size() == count, "Migration happens once")

	# Looks survive saving and loading settings.
	var config: ConfigFile = app.capture_settings()
	var fresh = p.get_script().new(); fresh.host = app; fresh.read(config)
	check(fresh.look_exists(other) and fresh.look_for_game("", "/roms/snes/a.sfc") == other, "Looks and their links are saved with the settings")

	# Basic settings hide fine-tuning and offer it back.
	app.settings_advanced = false
	var signal_rows: Array = m.catalog.pages(1)[2].rows
	check(not signal_rows.any(func(row): return row.id == "picture.phase_noise"), "Basic settings hide Chroma phase noise")
	var note = signal_rows.filter(func(row): return str(row.id).begins_with("advanced.note"))
	check(note.size() == 1 and str(note[0].label).contains("advanced"), "A note says how many settings are hidden")
	note[0].action.call()
	check(app.settings_advanced and m.catalog.pages(1)[2].rows.any(func(row): return row.id == "picture.phase_noise"), "Selecting the note shows every setting")
	check(m.catalog.pages(9)[0].rows.any(func(row): return row.id == "access.advanced"), "Show advanced settings is in Menu & access → Accessibility")
	check(m.catalog.pages(6)[0].title == "Scenes" and m.CATEGORIES[6] == "Scenes & help", "Saved setups are now Scenes, in Scenes & help")
	app.free(); await settle()
	print("LOOKS: %d failures" % failures)
	quit(1 if failures else 0)
