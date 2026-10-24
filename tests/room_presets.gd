extends SceneTree
## Room presets: built-in moods, your own rooms, Custom kept safe, and the
## quick switch in the pause menus and Quick settings.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func ids(menu) -> Array:
	return menu.items.map(func(item): return item.id)

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(6): await process_frame
	var rooms = app.rooms
	for index in range(rooms.COUNT): rooms.delete(index)
	check(rooms.active() == "late" and rooms.label(rooms.active()) == "Late night", "The default room is the Late night mood, not Custom")
	rooms.apply("dark")
	check(rooms.active() == "dark" and app.world.ambient == 0.0 and app.world.key_energy == 0.0 and app.world.fill_energy == 0.0 and app.world.spill_strength == 1.0,
		"Lights off leaves only the screen's full glow")
	app.world.show_vcr = false; app.world.apply_room_settings()
	check(rooms.active() == "dark", "Switching a prop doesn't stop the room counting as its mood")
	app.world.show_vcr = true
	# A hand-tuned room first.
	app.world.ambient = 0.33
	app.world.apply_room_settings()
	check(rooms.active() == "" and rooms.label(rooms.active()) == "Custom", "A tuned room reads as Custom")
	rooms.apply("warm")
	check(rooms.active() == "warm" and is_equal_approx(app.world.ambient, 0.45), "Warm bedroom applies its lighting and reads as active")
	rooms.apply("dim")
	check(rooms.active() == "dim" and is_equal_approx(app.world.ambient, 0.15), "Dim XR switches straight from another preset")
	rooms.apply("")
	check(rooms.active() == "" and is_equal_approx(app.world.ambient, 0.33), "Custom brings back the room you tuned")

	# Your own rooms: lighting, floor and props together.
	app.world.floor_style = 2
	app.world.show_vcr = false
	app.world.apply_room_settings()
	check(rooms.save(0) == OK and rooms.saved(0) and rooms.active() == "mine.0", "Saving keeps the room in a slot and marks it in use")
	check(rooms.rename(0, "Late night") == OK and rooms.name(0) == "Late night", "A saved room can be renamed")
	rooms.apply("bright")
	check(app.world.floor_style == 2 and rooms.active() == "bright", "Built-in moods change lighting only")
	app.world.floor_style = 0
	app.world.show_vcr = true
	app.world.apply_room_settings()
	rooms.apply("mine.0")
	check(rooms.active() == "mine.0" and app.world.floor_style == 2 and not app.world.show_vcr and is_equal_approx(app.world.ambient, 0.33),
		"Your room brings back its lighting, floor and props")
	var choices: Array = rooms.choices().map(func(pair): return pair[1])
	check(choices == ["Custom", "Lights off", "Late night", "Dim XR", "Warm bedroom", "Bright inspection", "Late night"], "The switch lists Custom, the moods and your rooms: %s" % [choices])
	check(app.capture_settings().get_value("menu", "room_preset_id") == "mine.0", "The room in use is remembered with the settings")

	# The switch: Room → Presets, Quick settings and every pause menu.
	if not app.settings_panel.visible: app.toggle_settings()
	var menu = app.menu
	menu.open_pause()
	check("pause.room" in ids(menu), "The home menu offers the room switch")
	menu.select("pause.room", false)
	var before: String = rooms.active()
	menu.adjust(-1) # "Late night" is last; choices stop at the ends
	check(rooms.active() != before, "Left/right on the switch changes the room at once (%s → %s)" % [before, rooms.active()])
	var quick_rows: Array = menu.catalog.pages(7)[0].rows.map(func(row): return row.id)
	check("quick.room" in quick_rows, "Quick settings offers the room switch")
	var room_page: Array = menu.catalog.pages(3)[0].rows.map(func(row): return row.id)
	check(menu.catalog.pages(3)[0].title == "Presets" and room_page.slice(0, 4) == ["room.preset", "room.mine.0", "room.mine.1", "room.mine.2"], "Room → Presets has the switch and three rooms of your own")
	menu.open_my_room(0)
	check(menu.mode == "my_room" and menu.heading.text == "Late night" and "room_mine.apply" in ids(menu), "Each room has its own page")
	var in_use: String = rooms.active()
	rooms.delete(0)
	check(not rooms.saved(0) and rooms.active() == in_use, "Deleting a room leaves the room you're in (%s)" % in_use)

	# The resume screen shows where you were beside the choices.
	menu.games.launch_path = "res://missing.sfc"
	menu.mode = "launch"; menu.render()
	await process_frame
	check(menu.rows.size() == 3 and menu.rows[0].get_parent() != menu.column, "The resume screen puts its choices beside the picture")
	# Rooms saved before the glow was rescaled keep their meaning.
	for pair in [[0.4, 0.5], [0.2, 0.25], [0.0, 0.0]]:
		var legacy := ConfigFile.new(); legacy.set_value("room", "spill_strength", pair[0])
		app.SettingsStore.migrate_screen_glow(legacy)
		check(is_equal_approx(float(legacy.get_value("room", "spill_strength")), pair[1]) and legacy.get_value("room", "lighting_version") == 2, "An old screen light of %.2f becomes %.2f" % pair)
	var current := ConfigFile.new(); current.set_value("room", "spill_strength", 0.8); current.set_value("room", "lighting_version", 2)
	app.SettingsStore.migrate_screen_glow(current)
	check(is_equal_approx(float(current.get_value("room", "spill_strength")), 0.8), "A rescaled room is never migrated twice")
	print("ROOM PRESET CHECKS COMPLETE: %d failures" % failures)
	quit(1 if failures else 0)
