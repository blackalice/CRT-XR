extends SceneTree
## The menu on the TV: the tube shows the menu with a reading picture, the TV
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
	app.use_tracking(false)
	# Startup with no game opens the menu: it must come up on a switched-on TV.
	check(app.settings_panel.visible and app.tv_menu.active and app.power_on.started, "At startup the TV switches on with the menu on it")
	app.menu_reduced_motion = true # the lean completes at once for measurement
	if app.settings_panel.visible: app.close_settings()
	await settle()
	var programme: Texture2D = app.world.picture.source_texture
	var scanlines := float(app.world.screen_material.get_shader_parameter("scanlines"))
	var place: Vector3 = app.world.television.position
	var mode: int = app.world.picture.mode
	var distance: float = app.distance
	check(app.menu_on_tv, "The menu shows on the TV by default")
	app.toggle_settings()
	await process_frame
	check(app.tv_menu.active and not app.menu_overlays[0].visible and not app.menu_overlays[1].visible, "On the very first frame the menu is on the TV, never floating")
	await settle()
	check(app.tv_menu.active and app.world.picture.source_texture == app.menu_view.get_texture(), "Opening the menu switches the tube to the menu")
	check(not app.menu_overlays[0].visible and not app.menu_depth_view.dim_nodes[0].visible, "Nothing floats over the room and the room stays undimmed")
	check(app.world.picture.mode == 0 and float(app.world.screen_material.get_shader_parameter("scanlines")) < scanlines, "The tube switches to a clean RGB picture with light scanlines")
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
	app.close_settings()
	await settle()
	check(not app.tv_menu.active and app.world.picture.source_texture == programme, "Closing gives the tube back to the programme")
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
	var saved: ConfigFile = app.capture_settings()
	check(saved.get_value("accessibility", "menu_on_tv") == true, "Menu on the TV is saved")
	app.menu_on_tv = false
	app.toggle_settings(); await settle()
	check(not app.tv_menu.active and app.menu_overlays[0].visible, "Off floats the menu in front of the TV as before")
	app.close_settings()
	app.free()
	print("MENU ON TV CHECKS: ", "PASS" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)
