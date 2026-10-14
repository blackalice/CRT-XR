extends SceneTree

var failures := 0

func check(value: bool, description: String) -> void:
	if value: print("PASS: ", description)
	else:
		push_error(description)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(4): await process_frame

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	await settle()
	app.set_stereo(true)
	app.toggle_settings()
	await settle()
	check(app.stereo and app.settings_panel.visible, "Opening menu preserves SBS")
	check(app.menu_overlays[0].visible and app.menu_overlays[1].visible, "Menu appears in both eyes")
	check(app.menu_overlays[0].texture == app.menu_overlays[1].texture, "Eyes share one synchronized menu")
	var before: Control = app.menu_view.gui_get_focus_owner()
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	Input.parse_input_event(down)
	await settle()
	check(app.menu_view.gui_get_focus_owner() != before, "Controller D-pad moves menu focus")
	down.pressed = false
	Input.parse_input_event(down)
	check(app.settings_tabs.get_tab_count() == 5, "Settings are grouped into five tabs")
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	await settle()
	check(app.settings_tabs.current_tab == 4 and app.menu_view.gui_get_focus_owner().is_visible_in_tree(), "L1 wraps to Setup and focuses a visible control")
	shoulder.pressed = false
	Input.parse_input_event(shoulder)
	shoulder = shoulder.duplicate()
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	await settle()
	check(app.settings_tabs.current_tab == 0, "R1 wraps back to Game")
	shoulder.pressed = false
	Input.parse_input_event(shoulder)
	app.settings_tabs.current_tab = 3
	await settle()
	check(app.menu_view.gui_get_focus_owner().name == "Warm", "Room tab starts at the lighting presets")
	check(app.settings_panel.get_rect().end.y <= 720 and app.settings_panel.get_rect().end.x <= 960, "Tabbed menu fits within the shared eye canvas")
	await RenderingServer.frame_post_draw
	app.menu_view.get_texture().get_image().save_png("res://build/room-menu-preview.png")
	app.settings_tabs.current_tab = 0
	await settle()
	app.choose_rom()
	await settle()
	check(app.stereo and app.rom_dialog.visible, "ROM browser preserves SBS")
	check(app.rom_dialog.get_parent() == app.menu_view, "ROM browser is embedded in shared eye menu")
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await settle()
	check(not app.rom_dialog.visible and app.stereo, "Controller B cancels browser without leaving SBS")
	cancel.pressed = false
	Input.parse_input_event(cancel)
	app.last_game_path = ProjectSettings.globalize_path("res://build/retrocrt-probe.sfc")
	app.choose_rom()
	await settle()
	var entries: ItemList = app.rom_dialog.entries
	for index in range(entries.item_count):
		if entries.get_item_metadata(index).path == app.last_game_path:
			entries.select(index)
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	Input.parse_input_event(accept)
	await settle()
	check(app.emulator.loaded and not app.rom_dialog.visible, "Controller A opens the selected SNES game")
	accept.pressed = false
	Input.parse_input_event(accept)
	app.toggle_settings()
	await settle()
	check(app.emulator.paused and app.stereo, "Menu pauses gameplay while preserving SBS")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/stereo-menu-preview.png")
	app.close_settings()
	await settle()
	check(not app.emulator.paused, "Closing menu restores running game")
	check(not app.menu_overlays[0].visible and not app.menu_overlays[1].visible, "Closing menu clears both eye overlays")
	app.emulator.set_paused(true)
	app.toggle_settings()
	app.close_settings()
	check(app.emulator.paused, "A previously paused game stays paused after menu")
	app.toggle_settings()
	await settle()
	app.settings_panel.find_child("Close", true, false).grab_focus()
	await settle()
	accept.device = 42
	accept.pressed = true
	Input.parse_input_event(accept)
	Input.flush_buffered_events()
	await settle()
	accept.pressed = false
	Input.parse_input_event(accept)
	Input.flush_buffered_events()
	await settle()
	check(not app.settings_panel.visible, "Controller A activates the focused settings button from any device")
	app.queue_free()
	await process_frame
	print("Stereo menu checks complete: ", failures, " failures")
	quit(1 if failures else 0)
