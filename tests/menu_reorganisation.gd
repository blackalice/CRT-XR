extends SceneTree
## The reorganised settings: eight categories in task order, tabs that keep their
## names, the editing scope strip, B to the sidebar, the changed-settings list,
## a test signal that asks first, and the controls that say what they do.
const UI = preload("res://tests/menu_test_helpers.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func settle(frames := 6) -> void:
	for i in range(frames): await process_frame

func button(m, code: int) -> void:
	var press := InputEventJoypadButton.new(); press.device = 0; press.button_index = code; press.pressed = true
	m.handle(press)
	press = press.duplicate(); press.pressed = false
	m.handle(press)

func key(m, code: int) -> void:
	var press := InputEventKey.new(); press.physical_keycode = code; press.pressed = true
	m.handle(press)
	press = press.duplicate(); press.pressed = false
	m.handle(press)

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle(10)
	app.apply_settings(ConfigFile.new())
	app.use_tracking(false)
	app.menu_reduced_motion = true
	var m = app.menu
	if not app.settings_panel.visible: app.toggle_settings()
	await settle()

	# Order and names.
	var shown: Array = []
	for button_node in m.sidebar.get_children():
		if button_node is Button and button_node.visible: shown.append(m.CATEGORIES[m.sidebar_buttons.find(button_node)])
	check(shown == ["View & glasses", "Picture", "Room", "Sound", "Games", "Videos", "Menu & access", "Setups & help"], "The sidebar reads in task order: %s" % [shown])
	m.open_settings(); m.category = 0; m.subsection = 0; m.render(); await settle()
	check(m.tab_position.visible and m.tab_position.text == "1 / 4", "The tab marker shows where this tab sits")
	app.world.set_widescreen(true); m.render(); await settle()
	check(m.catalog.pages(0)[1].title == "TV placement" and m.catalog.pages(1)[3].title == "Fit & TV", "Tab titles stay the same on the wide TV")
	app.world.set_widescreen(false)

	# B moves into the sidebar; up and down change category; A goes back in.
	m.open_settings(); m.category = 0; m.subsection = 1; m.render(); await settle()
	m.select("view.distance", false)
	button(m, JOY_BUTTON_B); await settle()
	check(m.mode == "settings" and m.sidebar_focus and m.selected_row() != null and not m.selected_row().selected_now, "B moves the focus to the sidebar and the page shows no selection")
	check(m.hints.text.contains("Category"), "The footer says up and down change category")
	m.navigate(Vector2i.DOWN); await settle()
	check(m.category == 1 and m.sidebar_focus, "Down in the sidebar moves to the next category")
	m.navigate(Vector2i.UP); await settle()
	button(m, JOY_BUTTON_A); await settle()
	check(m.category == 0 and not m.sidebar_focus and m.selected_id == "view.distance", "A goes back into the page where it was")
	m.select("view.fit", false); m.navigate(Vector2i.LEFT); await settle()
	check(m.sidebar_focus, "Left on a row with nothing to adjust also reaches the sidebar")
	button(m, JOY_BUTTON_B); await settle()
	check(m.mode == "pause" and not m.sidebar_focus, "B on the sidebar leaves Settings")

	# The scope strip with nothing loaded: game or video defaults.
	UI.page(app, 1, 1); await settle()
	check(m.scope_strip.visible and m.current_scope().choices == ["Game defaults", "Video defaults"], "Picture's strip edits game or video defaults when idle")
	check(not m.subtitle.visible and m.subtitle_row.visible, "The strip takes the context line's place")
	key(m, KEY_S); await settle()
	check(app.display_settings.kind == "video" and m.current_scope().index == 1, "S moves the strip to video defaults")
	key(m, KEY_S); await settle()
	check(app.display_settings.kind == "game", "S wraps back to game defaults")
	UI.page(app, 0, 2); await settle()
	check(not m.scope_strip.visible and m.subtitle.visible, "Unscoped tabs keep their context line")

	# Y names what it restores.
	UI.select(app, "view.distance"); await settle()
	check(m.hints.text.contains("Y Default"), "Y says it restores the default")

	# The changed-settings list and its jump.
	app.scanlines = 0.35
	app.world.screen_material.set_shader_parameter("scanlines", app.scanlines)
	UI.page(app, 0, 0); await settle()
	key(m, KEY_F); await settle()
	check(m.mode == "changed" and m.heading.text == "Changed settings", "F opens the changed-settings list")
	var found: Array = m.items.filter(func(item): return item.id == "changed.crt.scanlines")
	check(not found.is_empty() and str(found[0].value) == "50%" and str(found[0].section).contains("PICTURE"), "The list names the setting, its value and where it lives")
	m.select("changed.crt.scanlines", false); m.activate(); await settle()
	check(m.mode == "settings" and m.category == 1 and m.catalog.pages(1)[m.subsection].title == "Tube" and m.selected_id == "crt.scanlines", "Choosing it jumps to the setting")
	button(m, JOY_BUTTON_START); await settle()
	check(m.mode == "changed", "Start opens the list too")
	button(m, JOY_BUTTON_START); await settle()
	check(m.mode == "settings", "Start again closes it")

	# Fullscreen is a desktop window control.
	var deck: bool = m.deck_controls
	m.deck_controls = true
	check(not m.catalog.stereo_rows().any(func(row): return row.id == "view.fullscreen"), "The Steam Deck does not offer Toggle fullscreen")
	m.deck_controls = false
	check(m.catalog.stereo_rows().any(func(row): return row.id == "view.fullscreen"), "Desktops still offer Toggle fullscreen")
	m.deck_controls = deck

	# Every setting's help fits the help box, in normal and larger text.
	for large in [false, true]:
		app.menu_large_text = large
		var clipped: Array = []
		for target in m.SETTINGS_ORDER:
			for section in range(m.catalog.pages(target).size()):
				m.mode = "settings"; m.category = target; m.subsection = section; m.preview = false; m.sidebar_focus = false; m.render()
				for row in m.rows:
					if row.disabled: continue
					m.notification_time = 0.0
					m.select(row.item.id, false)
					await process_frame
					if m.help_label.size.y > m.help_slot.size.y + 1.0: clipped.append("%s (%d/%d)" % [row.item.id, target, section])
		check(clipped.is_empty(), "Help fits its box%s: %s" % [" with larger text" if large else "", clipped])
	app.menu_large_text = false

	# Empty setup slots are numbered, not named as if something were saved.
	var slots: Array = m.catalog.saved_setups_page().rows
	check(slots[0].label == "Setup 1" and slots[0].value == "Empty", "An empty slot reads Setup 1 · Empty")

	# Picture rows say where their value comes from, on the row.
	var gamma: Dictionary = m.catalog.pages(1)[2].rows.filter(func(row): return row.id == "picture.gamma")[0]
	check(gamma.has("detail_getter") and gamma.detail_getter.call() in ["Default", "From defaults", "From console", "Changed here"] and not str(gamma.help).contains("inherited value"), "Picture rows show their source under the title, not in the help")
	check(not m.catalog.pages(3)[1].rows.any(func(row): return str(row.get("unit", "")) == "x"), "Room values read as percentages, not multipliers")

	# Settings from a game's pause menu opens on its picture.
	m.category = 0; m.subsection = 1
	check(app.load_game(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")), "Probe game loads for Settings")
	await settle()
	m.open_settings_for_game(); await settle()
	check(m.mode == "settings" and m.category == 1 and m.current_scope().index == 0, "Settings from a game opens on Picture, editing this game")
	m.category = 10; m.open_settings_for_game(); await settle()
	check(m.category == 10, "…unless you were last in Games")
	app.emulator.stop(); await settle()

	# First-run setup asks how you play; This screen skips the glasses steps.
	m.welcome.open(); m.welcome.go("view"); await settle()
	check(m.items[0].id == "welcome.view.playing" and m.items.any(func(item): return item.id == "welcome.view.distance"), "Setup asks how you play, then shows TV position for glasses")
	m.items[0].setter.call(1); await settle()
	check(app.flat_screen and not m.items.any(func(item): return item.id in ["welcome.view.distance", "welcome.view.height_offset", "welcome.view.menu", "welcome.view.recentre"]) and app.flat_view_offered, "This screen turns on Flat view and skips placement")
	m.items[0].setter.call(0); await settle()
	m.welcome.active = false
	app.welcome_done = true

	# Without glasses, the menu offers Flat view once.
	app.flat_view_offered = false; app.flat_offer_in_tests = true
	m.open_pause(); await settle()
	app.offer_flat_view(app.FLAT_VIEW_OFFER_SECONDS + 0.1)
	check(m.mode == "confirm" and str(m.confirmation.title) == "Use Flat view?" and app.flat_view_offered, "No glasses: the menu asks once whether to use Flat view")
	check(m.items.map(func(item): return item.label) == ["Keep the room", "Use Flat view"], "Its buttons say what they do")
	m.back(); await settle()
	app.offer_flat_view(app.FLAT_VIEW_OFFER_SECONDS + 0.1)
	check(m.mode == "pause" and not app.flat_screen, "Saying no keeps the room and does not ask again")
	check(app.capture_settings().get_value("display", "flat_view_offered") == true, "Having asked is remembered")
	app.flat_offer_in_tests = false

	# Saved setups hold the view, room and picture, never input delay.
	app.selected_profile = 2
	app.emulator.run_ahead = 2
	app.distance = 2.5
	check(app.save_profile("Test setup"), "A setup saves")
	var stored := ConfigFile.new(); stored.load(app.profile_path())
	check(stored.has_section("view") and stored.has_section("room") and stored.has_section("picture") and not stored.has_section("emulation"), "A setup stores the view, room and picture but not input delay")
	app.emulator.run_ahead = 0
	app.distance = 3.5
	app.load_profile()
	check(is_equal_approx(app.distance, 2.5) and app.emulator.run_ahead == 0, "Loading a setup restores the view and leaves input delay alone")
	stored.set_value("emulation", "run_ahead", 2); stored.save(app.profile_path())
	app.load_profile()
	check(app.emulator.run_ahead == 0, "An older setup's input delay is ignored")

	# With a game: the scope strip, and a test signal that asks and saves first.
	app.close_settings()
	check(app.load_game(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")), "Probe game loads")
	await settle()
	UI.page(app, 1, 0); await settle()
	var strip: Dictionary = m.current_scope()
	check(strip.choices.size() == 3 and strip.choices[0] == "This game" and strip.choices[1] == "All SNES games" and strip.index == 0, "A game's Picture strip offers this game, its console and the defaults")
	button(m, JOY_BUTTON_BACK); await settle()
	check(app.display_settings.scope == 1 and m.current_scope().index == 1, "View moves the scope to all SNES games")
	UI.page(app, 10, 0); await settle()
	check(m.current_scope().choices == ["This game", "All SNES games"], "Games has the same strip")
	var auto: String = app.emulator.auto_path()
	if FileAccess.file_exists(auto): DirAccess.remove_absolute(auto)
	UI.select(app, "system.signal"); m.activate(); await settle()
	check(m.mode == "confirm" and app.emulator.loaded, "Show test signal asks before stopping the game")
	m.back(); await settle()
	check(app.emulator.loaded and m.mode == "settings", "Cancel leaves the game running")
	UI.select(app, "system.signal"); m.activate(); await settle()
	m.confirmed(); await settle()
	check(not app.emulator.loaded and FileAccess.file_exists(auto) and m.mode == "pause", "Stopping saves a resume point first")
	app.free()
	await process_frame
	print("MENU REORGANISATION CHECKS: ", "failed " + str(failures) if failures else "all passed")
	quit(1 if failures else 0)
