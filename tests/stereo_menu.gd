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
	app.queue_free()
	await process_frame
	print("Stereo menu checks complete: ", failures, " failures")
	quit(1 if failures else 0)
