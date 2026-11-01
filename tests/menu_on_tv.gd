extends SceneTree
## The menu on the TV: shared picture settings, an optional clean feed, the TV
## leans in, the preview strip floats, and closing puts everything back unsaved.
const UI = preload("res://tests/menu_test_helpers.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func settle(frames := 10) -> void:
	for i in range(frames): await process_frame

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.apply_settings(ConfigFile.new())
	await settle()
	app.use_tracking(false)
	# Startup with no game opens the menu: it must come up on a switched-on TV.
	check(app.settings_panel.visible and app.tv_menu.active and app.power_on.started, "At startup the TV switches on with the menu on it")
	app.menu_reduced_motion = true # the lean completes at once for measurement
	if app.settings_panel.visible: app.close_settings()
	await settle()
	var programme: Texture2D = app.world.picture.source_texture
	var scanlines := float(app.world.screen_material.get_shader_parameter("scanlines"))
	var place: Vector3 = app.world.television.position
	app.world.picture.mode = 3
	app.world.picture.source_rate = 50.0
	app.world.picture.refresh()
	var mode: int = app.world.picture.mode
	var distance: float = app.distance
	check(app.menu_on_tv, "The menu shows on the TV by default")
	app.toggle_settings()
	await process_frame
	check(app.tv_menu.active and not app.menu_overlays[0].visible and not app.menu_overlays[1].visible, "On the very first frame the menu is on the TV, never floating")
	await settle()
	check(app.tv_menu.active and app.world.picture.source_texture == app.menu_view.get_texture(), "Opening the menu switches the tube to the menu")
	check(not app.menu_overlays[0].visible and not app.menu_depth_view.dim_nodes[0].visible, "Nothing floats over the room and the room stays undimmed")
	check(not app.menu_clean_feed and app.world.picture.override.is_empty(), "The menu shares the current picture by default")
	check(app.world.picture.effective_mode() == 2 and is_equal_approx(float(app.world.screen_material.get_shader_parameter("scanlines")),scanlines), "Auto composite stays PAL and scanlines keep the programme setting")
	check(app.world.picture.shown_values() == app.world.picture.values, "Menu uses the current colour, fitting and beam settings")
	var mesh = app.world.television.get_node("PhosphorSurface").mesh
	await settle()
	check(app.world.television.get_node("PhosphorSurface").mesh == mesh, "Unchanged menu curvature does not rebuild the mesh")
	var settings_before: ConfigFile = app.capture_settings()
	var clean_row: Dictionary = app.menu.catalog.pages(9)[0].rows.filter(func(row): return row.id == "access.clean_feed")[0]
	clean_row.setter.call(true)
	await settle()
	check(app.tv_menu.active and app.world.picture.effective_mode() == 0 and is_equal_approx(float(app.world.screen_material.get_shader_parameter("scanlines")),0.18), "Accessibility switches the open menu to the previous clean picture")
	check(app.world.picture.mode == mode and app.world.picture.values.brightness == settings_before.get_value("picture","brightness"), "Clean feed leaves programme preferences intact")
	var clean_settings: ConfigFile = app.capture_settings()
	check(clean_settings.get_value("accessibility","menu_clean_feed") == true, "Clean feed preference is saved")
	clean_row.setter.call(false)
	await settle()
	check(app.world.picture.override.is_empty() and app.world.picture.effective_mode() == 2 and is_equal_approx(float(app.world.screen_material.get_shader_parameter("scanlines")),scanlines), "Disabling clean feed immediately restores the programme picture")
	check(app.world.picture.mode == mode, "The menus still read your own connection, not the menu's picture")
	check(app.world.television.position.z > place.z and is_equal_approx(app.world.television.position.x, 0.0), "The TV leans in towards you, centred (%.2f m from %.2f m)" % [-app.world.television.position.z, -place.z])
	check(not app.world.picture.paused, "The tube keeps updating while it shows the menu")
	# Changing a setting re-renders the page; its rows settle over a few frames.
	app.menu.refresh()
	await process_frame; await process_frame
	check(app.menu_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "While a re-rendered page settles, the tube keeps the last finished picture")
	await settle()
	check(app.menu_view.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Then the settled page shows")
	await settle()
	check(not app.tv_menu.lights_room(), "Game frames don't light the room while the menu is on the tube")
	# Headless runs have no GPU image to read back; a windowed run checks the snapshot.
	if DisplayServer.get_name() != "headless":
		var light: Image = app.world.screen_light.source
		check(light != null and light.get_width() == 48, "The room is lit by a snapshot of the menu")
	check(is_equal_approx(app.distance, distance), "The saved TV distance is untouched (%.2f m)" % app.distance)
	UI.select(app, "crt.scanlines"); await settle()
	app.menu.toggle_preview(); await settle()
	check(app.menu.preview and not app.tv_menu.active and app.menu_overlays[0].visible and app.world.picture.source_texture == programme, "Adjust with preview floats the menu over the programme")
	app.menu.toggle_preview(); await settle()
	check(app.tv_menu.active, "Leaving the preview puts the menu back on the TV")
	# A picture change made on the TV menu (the Quick settings Picture tile) is kept.
	var brightness: float = app.world.picture.values.brightness
	app.world.picture.set_value("brightness", brightness + 0.05)
	app.close_settings()
	await settle()
	check(not app.tv_menu.active and app.world.picture.source_texture == programme, "Closing gives the tube back to the programme")
	check(is_equal_approx(float(app.world.picture.values.brightness), brightness + 0.05), "A picture change made on the TV menu is kept when it closes")
	app.world.picture.set_value("brightness", brightness)
	check(is_equal_approx(float(app.world.screen_material.get_shader_parameter("scanlines")), scanlines) and app.world.picture.mode == mode, "Your scanlines and connection come back")
	check(app.world.television.position.is_equal_approx(place), "The TV returns to its place")
	check(app.world.screen_light.source == null or app.world.screen_light.source.get_width() != 48, "The room's light goes back to the programme")
	# Choosing a game from the TV menu: the loading card takes the tube and the
	# menu closes in the same frame. The card must stay, not the last programme.
	var last_game := ImageTexture.create_from_image(Image.create(256, 224, false, Image.FORMAT_RGBA8))
	app.world.picture.set_source(last_game, true) # the game that was playing
	app.toggle_settings(); await settle()
	app.show_loading("C:/roms/psx/Next Game (USA).cue", 0.1)
	app.close_settings()
	await settle()
	check(app.world.picture.source_texture == app.card_view.get_texture(), "A game chosen from the TV menu keeps its loading card, not the last game's frame")
	app.end_loading(); await settle()
	# With glasses, the setup screen is still up when the menu opens, and hands
	# over afterwards: the TV must switch on then, with the menu already showing.
	app.power_on.started = false
	var setup := Control.new(); app.add_child(setup); app.sbs_prompt = setup
	app.toggle_settings(); await settle()
	check(app.tv_menu.active and not app.power_on.started, "While the glasses setup screen is up, the TV stays off")
	setup.free(); await settle()
	check(app.power_on.started, "Once the setup screen hands over, the TV switches on under the menu")
	app.close_settings(); await settle()
	var saved: ConfigFile = app.capture_settings()
	check(saved.get_value("accessibility", "menu_on_tv") == true, "Menu on the TV is saved")
	app.menu_on_tv = false
	app.toggle_settings(); await settle()
	check(not app.tv_menu.active and app.menu_overlays[0].visible, "Off floats the menu in front of the TV as before")
	app.close_settings()
	app.apply_settings(clean_settings)
	check(app.menu_clean_feed, "Clean feed survives settings restore")
	app.toggle_settings()
	app.reset_all_options()
	check(not app.menu_clean_feed, "Reset all settings restores the shared menu picture")
	app.free()
	print("MENU ON TV CHECKS: ", "PASS" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)
