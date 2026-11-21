extends SceneTree
## Settings' category rail and drawer: L1/R1 open it and step a category, each press
## restarts one 1.2 s timer, the timeout and A put the player back on the page they
## left, A never touches the setting behind it, and B always leaves Settings.
const UI = preload("res://tests/menu_test_helpers.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func settle(frames := 6) -> void:
	for i in range(frames): await process_frame

func joy(m, code: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new(); event.device = 0; event.button_index = code; event.pressed = pressed
	m.handle(event)

## A button pressed and let go, as a thumb does it.
func tap(m, code: int) -> void:
	joy(m, code, true); joy(m, code, false)

func trigger(m, axis: int) -> void:
	for value in [1.0, 0.0]:
		var event := InputEventJoypadMotion.new(); event.device = 0; event.axis = axis; event.axis_value = value
		m.handle(event)

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
	# The drawer's timer runs in _process: stop real time and drive it by hand, so
	# the checks do not depend on how fast frames come.
	m.set_process(false)
	var order: Array = m.SETTINGS_ORDER
	var picture: int = 1
	var after_picture: int = order[(order.find(picture) + 1) % order.size()]
	var before_picture: int = order[(order.find(picture) - 1 + order.size()) % order.size()]

	# Geometry: a 68 px rail that opens into a 330 px drawer from the same corner.
	UI.page(app, picture, 1); await settle()
	var rail: Rect2 = m.sidebar_panel.get_global_rect()
	check(rail.size == Vector2(68, 509) and rail.position.y == 104.0, "The rail is 68 px wide and 509 px tall from y = 104: %s" % [rail])
	var first_icon_y: float = m.sidebar_buttons[order[0]].get_global_rect().position.y
	var icon_rows := []
	for category in order: icon_rows.append(m.sidebar_buttons[category].get_global_rect().position.y)
	m.step_category(1); await settle()
	var open_rail: Rect2 = m.sidebar_panel.get_global_rect()
	check(open_rail.size == Vector2(330, 509) and open_rail.position == rail.position, "The open drawer is 330 px wide over the same place: %s" % [open_rail])
	var same_rows := true
	for i in range(order.size()): same_rows = same_rows and is_equal_approx(icon_rows[i], m.sidebar_buttons[order[i]].get_global_rect().position.y)
	check(same_rows and is_equal_approx(first_icon_y, m.sidebar_buttons[order[0]].get_global_rect().position.y), "The category icons keep their rows when the drawer opens")
	check(m.sidebar_buttons[order[0]].get_node("CategoryCaption").visible and m.drawer_dim.visible, "The drawer shows its labels and dims the page")
	m.end_drawer(); m.render(); await settle()

	# Larger text: the rail keeps its icons, and a long name stays inside the drawer.
	app.menu_large_text = true; m.render(); await settle()
	check(m.sidebar_buttons.filter(func(button): return button.visible).all(func(button): return button.icon != null) and m.sidebar_panel.size.x == 68.0, "Larger text keeps the rail's icons")
	m.step_category(1); await settle()
	var fits := true
	for category in order:
		var caption: Label = m.sidebar_buttons[category].get_node("CategoryCaption")
		var width := caption.get_theme_font("font").get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x
		fits = fits and caption.position.x + minf(width, caption.size.x) <= m.sidebar_panel.get_global_rect().size.x
	check(fits, "Category names fit the drawer at larger text")
	app.menu_large_text = false; m.end_drawer(); m.render(); await settle()

	# One R1: the drawer opens and steps one category, and the page behind follows.
	UI.page(app, picture, 1); await settle()
	check(not m.drawer_open, "The drawer starts closed")
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle()
	check(m.drawer_open and m.category == after_picture and is_equal_approx(m.drawer_time, m.DRAWER_TIME), "One R1 opens the drawer and steps one category forward")
	check(m.heading.text == m.CATEGORIES[after_picture] and m.hints.text.contains("Done") and m.hints.text.contains("Back") and not m.hints.text.contains("Adjust"), "The page behind shows that category; the footer offers A Done and B Back only")
	check(m.selected_row() != null and not m.selected_row().selected_now, "No setting row shows a selection while the drawer is open")

	# Rapid presses: each one steps again and restarts the single timer.
	m._process(0.7)
	check(m.drawer_open and m.drawer_time < 0.6, "The timer counts down while the drawer is open")
	tap(m, JOY_BUTTON_RIGHT_SHOULDER)
	check(m.drawer_open and is_equal_approx(m.drawer_time, m.DRAWER_TIME) and m.category == order[(order.find(picture) + 2) % order.size()], "A second press steps again and restarts the timer")
	m._process(0.7); tap(m, JOY_BUTTON_LEFT_SHOULDER); m._process(0.7)
	check(m.drawer_open and m.category == after_picture, "Presses 0.7 s apart keep the drawer open past 1.2 s in all (and L1 steps back)")
	m._process(0.4)
	check(m.drawer_open, "The drawer is still open 1.1 s after the last press")
	m._process(0.15)
	check(not m.drawer_open and m.drawer_time == 0.0, "It closes 1.2 s after the last press")
	await settle()

	# Timeout returns focus to the same row, tab and scroll of the selected category.
	UI.page(app, picture, 1); await settle()
	var row_id: String = str(m.rows[2].item.id)
	m.select(row_id, false); await settle()
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle()
	tap(m, JOY_BUTTON_LEFT_SHOULDER); await settle()
	check(m.category == picture and m.drawer_open, "R1 then L1 comes back to Picture with the drawer open")
	m._process(1.3); await settle()
	check(not m.drawer_open and m.category == picture and m.subsection == 1 and m.selected_id == row_id and m.selected_row().selected_now, "The timeout returns focus to the same row on the same tab")
	# Another category keeps its own place.
	UI.page(app, 0, 1); await settle()
	m.select("view.height_offset", false)
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle()
	check(m.category == order[1], "R1 from View steps to Picture")
	m._process(1.3); await settle()
	check(m.category == order[1] and m.subsection == 1 and m.selected_id == row_id, "A category left and revisited returns to its saved tab and row")
	tap(m, JOY_BUTTON_LEFT_SHOULDER); await settle()
	m._process(1.3); await settle()
	check(m.category == 0 and m.subsection == 1 and m.selected_id == "view.height_offset", "View keeps its own tab and row too")

	# A long page restores its scroll position, and the focused row, after the drawer has been used.
	app.settings_advanced = true
	var long_category := -1
	var long_section := 0
	for target in order:
		for section in range(m.catalog.pages(target).size()):
			if long_category < 0 and m.catalog.pages(target)[section].rows.size() >= 10: long_category = target; long_section = section
	check(long_category >= 0, "There is a page long enough to scroll")
	UI.page(app, long_category, long_section); await settle()
	var last_row: String = str(m.rows[m.rows.size() - 1].item.id)
	m.select(last_row, false); await settle(); m.remember()
	var scrolled: int = m.scroll.scroll_vertical
	check(scrolled > 0, "The long page scrolls to its last row: %d" % scrolled)
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle(); tap(m, JOY_BUTTON_LEFT_SHOULDER); await settle()
	m._process(1.3); await settle(10)
	check(m.category == long_category and m.selected_id == last_row and m.scroll.scroll_vertical == scrolled, "The drawer's timeout restores the same row and scroll: %d vs %d" % [m.scroll.scroll_vertical, scrolled])
	app.settings_advanced = false

	# Wraparound at both ends of the rail's order.
	UI.page(app, order[0], 0); await settle()
	tap(m, JOY_BUTTON_LEFT_SHOULDER); await settle()
	check(m.category == order[order.size() - 1], "L1 from the first category wraps to the last")
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle()
	check(m.category == order[0], "R1 from the last category wraps to the first")
	m.end_drawer(); m.render(); await settle()
	# The keyboard does the same.
	var key := InputEventKey.new(); key.physical_keycode = KEY_E; key.pressed = true
	m.handle(key)
	check(m.drawer_open and m.category == order[1], "E opens the drawer and steps like R1")
	m.end_drawer(); m.render(); await settle()

	# D-pad up and down step categories and restart the timer; right is Done; others are ignored.
	UI.page(app, picture, 1); await settle()
	m.select(row_id, false)
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); m._process(0.8)
	m.navigate(Vector2i.DOWN)
	check(m.category == order[(order.find(picture) + 2) % order.size()] and is_equal_approx(m.drawer_time, m.DRAWER_TIME), "Down steps a category and restarts the timer")
	m.navigate(Vector2i.UP); m.navigate(Vector2i.UP); await settle()
	check(m.category == picture, "Up steps back through the order")
	tap(m, JOY_BUTTON_X); tap(m, JOY_BUTTON_Y); tap(m, JOY_BUTTON_START); tap(m, JOY_BUTTON_BACK)
	trigger(m, JOY_AXIS_TRIGGER_RIGHT)
	check(m.drawer_open and m.mode == "settings" and not m.preview and m.subsection == int(m.sections.get(m.category, 0)), "X, Y, Start, View and the triggers are ignored while the drawer is open")
	m.end_drawer(); m.render(); await settle()

	# A closes the drawer and never touches the setting behind it.
	UI.page(app, 0, 1); await settle()
	m.select("controls.distance", false); await settle()
	var toggle_before: bool = app.right_stick_distance
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle()
	tap(m, JOY_BUTTON_LEFT_SHOULDER); await settle()
	check(m.drawer_open and m.category == 0 and m.selected_id == "controls.distance", "The drawer is open over the toggle's page")
	joy(m, JOY_BUTTON_A, true)
	check(not m.drawer_open and app.right_stick_distance == toggle_before and m.selected_id == "controls.distance" and m.selected_row().selected_now, "A dismisses the drawer, returns to the focused setting, and does not toggle it")
	joy(m, JOY_BUTTON_A, true)
	check(app.right_stick_distance == toggle_before, "A held down cannot activate the setting after the dismissal")
	joy(m, JOY_BUTTON_A, false)
	check(app.right_stick_distance == toggle_before, "Letting go of A does not activate it either")
	tap(m, JOY_BUTTON_A)
	check(app.right_stick_distance != toggle_before, "A pressed again afterwards works as usual")
	app.right_stick_distance = toggle_before
	# A number is not adjusted by the dismissal, nor by a held D-pad right.
	UI.page(app, 0, 1); await settle()
	m.select("view.distance", false); app.distance = 3.0
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle()
	tap(m, JOY_BUTTON_LEFT_SHOULDER); await settle()
	tap(m, JOY_BUTTON_A)
	check(is_equal_approx(app.distance, 3.0) and not m.drawer_open, "A leaves a number setting at its value")
	tap(m, JOY_BUTTON_LEFT_SHOULDER); await settle()
	joy(m, JOY_BUTTON_DPAD_RIGHT, true)
	check(not m.drawer_open, "D-pad right dismisses the drawer like A")
	m._process(0.4); m._process(0.11)
	joy(m, JOY_BUTTON_DPAD_RIGHT, false)
	check(is_equal_approx(app.distance, 3.0) and m.direction == Vector2i.ZERO, "Holding D-pad right after the dismissal does not adjust the setting")
	await settle()

	# L2 / R2 switch tabs only while the drawer is closed.
	UI.page(app, 0, 0); await settle()
	trigger(m, JOY_AXIS_TRIGGER_RIGHT)
	check(m.subsection == 1, "R2 changes tab with the drawer closed")
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle()
	var drawer_tab: int = m.subsection
	trigger(m, JOY_AXIS_TRIGGER_RIGHT); trigger(m, JOY_AXIS_TRIGGER_LEFT)
	check(m.subsection == drawer_tab and m.drawer_open, "L2 and R2 do nothing while the drawer is open")
	m._process(1.3); await settle()
	trigger(m, JOY_AXIS_TRIGGER_LEFT)
	check(m.subsection == maxi(drawer_tab - 1, 0) or m.catalog.pages(m.category).size() == 1, "L2 changes tab once the drawer has closed")

	# B leaves Settings from either state, to where Settings was opened from.
	m.open_pause(); await settle()
	m.select("home.settings", false)
	m.open_settings(); await settle()
	check(m.mode == "settings" and not m.drawer_open, "Settings opens with the drawer closed")
	tap(m, JOY_BUTTON_B); await settle()
	check(m.mode == "pause" and not m.drawer_open, "B with the drawer closed leaves Settings")
	m.open_settings(); await settle()
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle()
	check(m.drawer_open, "The drawer is open before B")
	tap(m, JOY_BUTTON_B); await settle()
	check(m.mode == "pause" and not m.drawer_open and m.drawer_time == 0.0, "B with the drawer open leaves Settings, not into the categories")
	# A direct link (Music settings) goes back to the music page.
	m.music.open_music_browser(ProjectSettings.globalize_path("res://build")); await settle()
	check(m.mode == "music_browser", "The music page is open")
	m.open_settings_section(2, "Music"); await settle()
	check(m.mode == "settings" and not m.settings_origin.is_empty(), "Music settings is a direct link with an origin")
	tap(m, JOY_BUTTON_B); await settle()
	check(m.mode == "music_browser" and not m.drawer_open, "B from a direct link returns to its origin")
	m.open_settings_section(2, "Music"); await settle()
	tap(m, JOY_BUTTON_RIGHT_SHOULDER); await settle()
	tap(m, JOY_BUTTON_B); await settle()
	check(m.mode == "music_browser" and not m.drawer_open, "B with the drawer open returns a direct link to its origin")
	# The pause menu of a game is another origin: mode pause either way.
	m.open_pause(); m.open_settings(); await settle()
	tap(m, JOY_BUTTON_LEFT_SHOULDER); await settle()
	m.open_pause(); await settle()
	check(m.mode == "pause" and not m.drawer_open and m.drawer_time == 0.0, "Opening the pause menu clears the drawer and its timer")
	m.open_settings(); await settle()
	tap(m, JOY_BUTTON_LEFT_SHOULDER); await settle()
	m.hide(); await settle()
	check(not m.drawer_open and m.drawer_time == 0.0, "Hiding the menu clears the drawer and its timer")
	m.show(); m.set_process(false)

	# The mouse picks a category directly and closes the drawer.
	m.open_settings(); await settle()
	m.step_category(1); await settle()
	m.pick_category(order[3]); await settle()
	check(m.category == order[3] and not m.drawer_open, "Clicking a category switches to it and closes the drawer")
	m.sidebar_buttons[order[1]].pressed.emit(); await settle()
	check(m.category == order[1] and not m.drawer_open, "Clicking a rail icon switches category")

	# The help panel names the focused setting and its source, and every help text fits it.
	UI.page(app, picture, 1); await settle()
	m.select(str(m.rows[1].item.id), false); await settle()
	check(m.info_title.text == str(m.rows[1].item.label).to_upper() and m.info_text.text == str(m.rows[1].item.help), "The help panel shows the focused setting's name and its help text")
	check(not m.info_from.text.is_empty() and not m.info_source.text.is_empty(), "The help panel's footer says where the value comes from: %s / %s" % [m.info_from.text, m.info_source.text])
	check(not m.help_frame.visible, "The old bottom help window is not shown in Settings")
	# Adjusting a setting says "Changed" on its own line; the help text stays.
	var tube_row = m.rows[1]
	var tube_help: String = str(tube_row.item.help)
	m.adjust(-1); await settle()
	check(m.notification_time > 0.0 and m.info_text.text == tube_help and m.info_title.text == str(tube_row.item.label).to_upper(), "Adjusting a value leaves the panel's help text in place")
	check(m.info_notice.visible and m.info_notice.text.begins_with("Changed"), "The change message has its own line in the panel: %s" % m.info_notice.text)
	tube_row.item.setter.call(tube_row.item.default)
	# A plain setting at its default adds no footer; once changed, it names the default.
	UI.page(app, m.CATEGORIES.find("Sound"), 0); await settle()
	var plain := {}
	for row in m.rows:
		if not row.disabled and row.item.get("kind", "") == "number" and row.item.has("default") and not row.item.has("picture_field") and not row.item.has("detail_getter"): plain = row.item; break
	check(not plain.is_empty(), "Sound has a plain setting with a default")
	if not plain.is_empty():
		var before = plain.getter.call()
		plain.setter.call(plain.default); m.refresh(); await settle(); m.select(str(plain.id), false); await settle()
		check(not m.info_from.get_parent().visible, "A setting at its default shows no source footer")
		var step := float(plain.get("step", 0.05)) * 2.0
		var other := float(plain.default) + step
		if other > float(plain.get("max", 1.0)): other = float(plain.default) - step
		plain.setter.call(other); m.refresh(); await settle(); m.select(str(plain.id), false); await settle()
		check(m.info_from.get_parent().visible and m.info_from.text == "DEFAULT" and not m.info_source.text.begins_with("Default"), "A changed setting names its default once: %s / %s" % [m.info_from.text, m.info_source.text])
		plain.setter.call(before); m.refresh(); await settle()
	for large in [false, true]:
		app.menu_large_text = large
		var clipped: Array = []
		for target in m.SETTINGS_ORDER:
			for section in range(m.catalog.pages(target).size()):
				m.mode = "settings"; m.category = target; m.subsection = section; m.preview = false; m.render()
				for row in m.rows:
					if row.disabled: continue
					m.select(row.item.id, false)
					await process_frame; await process_frame
					if m.info_text.get_combined_minimum_size().y > m.info_slot.size.y + 1.0: clipped.append("%s (%d/%d)" % [row.item.id, target, section])
		check(clipped.is_empty(), "Every setting's help fits the help panel%s: %s" % [" with larger text" if large else "", clipped])
	app.menu_large_text = false

	# A greyed-out row can be focused for its explanation, and does nothing when used.
	app.world.ambience = 0
	UI.page(app, 2, 0); await settle()
	var room_sound = m.rows.filter(func(row): return row.item.id == "room.ambience_level")[0]
	check(room_sound.disabled and room_sound.custom_minimum_size.y == 56.0 and room_sound.size.y == 56.0, "The unavailable Room sound row stays one 56 px line: %s" % [room_sound.size])
	m.select("room.ambience_level", false); await settle()
	var level_before: float = app.world.ambience_level
	check(m.selected_id == "room.ambience_level" and m.info_title.text == "ROOM SOUND", "A disabled Settings row can be focused: %s" % m.selected_id)
	check(m.info_text.text.begins_with(str(room_sound.item.disabled_reason)) and m.info_text.text.contains(str(room_sound.item.help)), "The help panel gives the reason first, then the help: %s" % m.info_text.text)
	m.adjust(1); m.activate(); m.reset_option(); await settle()
	check(is_equal_approx(app.world.ambience_level, level_before), "Adjusting, activating or resetting an unavailable row changes nothing")
	m.navigate(Vector2i.DOWN); var below: String = m.selected_id; m.navigate(Vector2i.UP); await settle()
	check(below != "room.ambience_level" and m.selected_id == "room.ambience_level", "Up and down step through the unavailable row like any other: %s, %s" % [below, m.selected_id])

	app.free(); await settle()
	print("SETTINGS DRAWER COMPLETE: ", failures, " failures"); quit(1 if failures else 0)
