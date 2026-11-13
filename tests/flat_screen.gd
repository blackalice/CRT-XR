extends SceneTree
## Flat screen mode: the picture without the room. It is one saved switch, the
## room's eye views stop drawing, the picture shares every tube setting with the
## TV, the menu floats over it, room-only settings say they are unused, and the
## flat shader draws exactly what the TV's surface draws.
const UI = preload("res://tests/menu_test_helpers.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func settle(frames := 10) -> void:
	for i in range(frames): await process_frame

func run() -> void:
	OS.set_environment("CRT_XR_SCREENSHOT_DIR", ProjectSettings.globalize_path("user://flat-screen-shots"))
	await shader_matches_tv()
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.apply_settings(ConfigFile.new())
	app.use_tracking(false)
	app.menu_reduced_motion = true
	if app.settings_panel.visible: app.close_settings()
	await settle()
	check(not app.flat_screen and not app.flat.layers[0].visible, "Flat screen is off by default")
	check(app.views[0].render_target_update_mode == SubViewport.UPDATE_ALWAYS, "The room draws while flat screen is off")

	UI.set_value(app, "view.flat", true)
	app.close_settings()
	await settle()
	check(app.flat_screen and app.flat.layers[0].visible and app.flat.layers[0].is_visible_in_tree(), "The switch shows the flat picture")
	check(app.views[0].render_target_update_mode == SubViewport.UPDATE_DISABLED and app.views[1].render_target_update_mode == SubViewport.UPDATE_DISABLED, "Neither eye renders the room in flat screen mode")
	check(app.flat.view.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "The flat picture draws every frame")
	check(app.capture_settings().get_value("display", "flat_screen") == true, "The choice is saved")

	# Shared settings: a picture change reaches the flat picture next frame.
	app.world.picture.set_value("brightness", 1.3)
	app.scanlines = 0.35
	app.world.screen_material.set_shader_parameter("scanlines", app.scanlines)
	await settle(3)
	check(is_equal_approx(float(app.flat.material.get_shader_parameter("brightness")), 1.3), "Picture settings are shared with the TV")
	check(is_equal_approx(float(app.flat.material.get_shader_parameter("scanlines")), 0.35), "Tube settings are shared with the TV")
	check(app.flat.material.get_shader_parameter("signal_texture") == app.world.screen_material.get_shader_parameter("signal_texture"), "The flat picture shows the same signal")
	# TV's shape: the TV's outline, with the tube's fitting mapped across.
	check(app.flat_shape == 0, "Flat view fills the whole display by default")
	app.flat_shape = 1
	await settle(3)
	var tube: Vector4 = app.world.screen_material.get_shader_parameter("picture_rect")
	var area: Rect2 = app.world.picture.safe_rect
	var flat_rect: Vector4 = app.flat.material.get_shader_parameter("picture_rect")
	check(absf(flat_rect.x - (tube.x - area.position.x) / area.size.x) < 0.0001 and absf(flat_rect.z - tube.z / area.size.x) < 0.0001, "Fitting is mapped from the tube's aperture to the whole flat picture")
	var shape := float(app.flat.view.size.x) / float(app.flat.view.size.y)
	check(absf(shape - app.flat.aspect()) < 0.02, "The flat picture keeps the TV model's shape")
	# A widescreen game filling the standard TV crops its sides past the flat picture's edges.
	app.world.picture.source_aspect = 16.0 / 9.0
	app.world.picture.fit_mode = 1
	app.world.picture.refresh()
	await settle(3)
	var filled: Vector4 = app.flat.material.get_shader_parameter("picture_rect")
	check(filled.z > 1.0 and filled.x < 0.0, "Fill crops at the flat picture's edges, as on the TV")
	app.world.picture.source_aspect = 4.0 / 3.0
	app.world.picture.fit_mode = 0
	app.world.picture.refresh()

	# Whole display: the flat picture is the panel, and the game is fitted to it.
	app.flat_shape = 0
	await settle(3)
	var panel_size: Vector2 = app.flat.layers[0].size
	check(Vector2(app.flat.view.size) == panel_size.floor(), "On the whole display the flat picture fills the panel: %s in %s" % [app.flat.view.size, panel_size])
	var whole: Vector4 = app.flat.material.get_shader_parameter("picture_rect")
	var shown_shape: float = (whole.z * panel_size.x) / (whole.w * panel_size.y)
	var border: float = float(app.world.picture.shown_values().safe_border)
	check(absf(shown_shape - 4.0 / 3.0) < 0.02 and absf(whole.y - border) < 0.01 and whole.x > border, "Fit keeps a 4:3 game's shape, as tall as the display allows: %s" % whole)
	app.world.picture.fit_mode = 1
	app.world.picture.refresh()
	await settle(3)
	whole = app.flat.material.get_shader_parameter("picture_rect")
	check(whole.w > 1.0 and whole.y < 0.0 and absf(whole.z - (1.0 - 2.0 * border)) < 0.01, "Fill widens a 4:3 game to the display, cropping top and bottom: %s" % whole)
	app.world.picture.fit_mode = 0
	app.world.picture.refresh()

	# The menu floats over the picture: there is no TV to put it on.
	app.toggle_settings()
	await settle()
	check(not app.tv_menu.active and app.menu_overlays[0].visible, "The menu floats over the flat picture")
	check(app.flat.layers[0].get_index() < app.menu_overlays[0].get_index(), "The flat picture sits under the menu")
	check(app.menu_view.size == app.tv_menu.flat_canvas() and app.menu.size == Vector2(app.menu_view.size) and app.menu.backdrop.size == app.menu.size, "Flat view's menu canvas takes the display's shape, its backdrop filling it")
	check(app.menu.reading_frame.size.x < 960.0, "The reading area keeps its standard width, centred")
	await flat_menu_shapes(app)
	var placement: Array = app.menu.catalog.pages(0)[1].rows
	check(not placement.any(func(row): return row.id == "view.distance") and str(placement[0].id).begins_with("flat.note") and placement[0].get("disabled", false), "TV placement hides what flat view does not use, behind one line")
	check(str(placement[0].label).begins_with("4 settings hidden"), "The line says how many are hidden: %s" % placement[0].label)
	check(placement.any(func(row): return row.id == "view.recenter"), "What still applies stays on the page")
	var room_rows: Array = []
	for page in app.menu.catalog.pages(3): room_rows.append_array(page.rows)
	var lighting: Array = room_rows.filter(func(row): return str(row.get("id", "")) == "room.key_energy")
	var preset: Array = room_rows.filter(func(row): return str(row.get("id", "")).begins_with("room.look."))
	var ambience: Array = app.menu.catalog.pages(2)[0].rows.filter(func(row): return str(row.get("id", "")) == "room.ambience")
	check(lighting.is_empty() and app.menu.catalog.pages(3)[1].rows.size() == 1, "Room lighting is hidden, leaving only its note")
	check(not preset.is_empty() and not preset[0].get("disabled", false) and not ambience.is_empty() and not ambience[0].get("disabled", false), "Room presets and room sound stay available")
	# The tube's glass and curve are not drawn flat; the TV model only matters in TV's shape.
	var picture_pages: Dictionary = {}
	for page in app.menu.catalog.pages(1): picture_pages[page.title] = page.rows.map(func(row): return str(row.get("id", "")))
	var tube_note: Array = app.menu.catalog.pages(1).filter(func(page): return page.title == "Tube")[0].rows.filter(func(row): return str(row.get("id", "")).begins_with("flat.note"))
	check(not "crt.glass_reflections" in picture_pages.Tube and not "crt.screen_curvature" in picture_pages.Tube and "crt.scanlines" in picture_pages.Tube, "Tube hides glass reflections and curvature, which flat view does not draw")
	check(not tube_note.is_empty() and str(tube_note[0].disabled_reason).contains("curved glass"), "The Tube note says why")
	check(not "picture.tv_policy" in picture_pages["Fit & TV"] and "picture.fitting" in picture_pages["Fit & TV"], "On the whole display, Fit & TV hides the TV model and keeps fitting")
	var fitting_section: Array = app.menu.catalog.pages(1).filter(func(page): return page.title == "Fit & TV")[0].rows.filter(func(row): return row.get("section", "") == "FITTING")
	check(not fitting_section.is_empty(), "Fitting keeps its heading")
	app.flat_shape = 1
	var tv_shape_rows: Array = app.menu.catalog.pages(1).filter(func(page): return page.title == "Fit & TV")[0].rows.map(func(row): return str(row.get("id", "")))
	check("picture.tv_policy" in tv_shape_rows, "In the TV's shape, the TV model is back")
	app.flat_shape = 0
	var quick_ids: Array = app.menu.quick_controls().map(func(row): return row.id)
	check(not "pause.view.distance" in quick_ids and "pause.flat_shape" in quick_ids, "Quick settings offer the screen's shape in place of TV position: %s" % [quick_ids])
	check("pause.game_shape" in quick_ids and not "pause.tv" in quick_ids, "On the whole display, Game shape takes the TV tile")
	app.flat_shape = 1
	quick_ids = app.menu.quick_controls().map(func(row): return row.id)
	check("pause.tv" in quick_ids and not "pause.game_shape" in quick_ids, "In the TV's shape, the TV tile is back")
	app.flat_shape = 0
	var shape_tile: Array = app.menu.quick_controls().filter(func(row): return row.id == "pause.flat_shape")
	shape_tile[0].setter.call(1)
	check(app.flat_shape == 1 and app.capture_settings().get_value("display", "flat_shape") == 1, "The Screen tile changes the shape, and it is saved")
	shape_tile[0].setter.call(0)
	# Changing Screen swaps Game shape and TV in place: nothing else moves.
	app.menu.open_pause()
	await settle(20)
	var before := row_rects(app)
	app.menu.select("pause.flat_shape", false)
	app.menu.adjust(1)
	await settle(20)
	var after := row_rects(app)
	var moved: Array = before.keys().filter(func(id): return after.has(id) and after[id] != before[id])
	check(app.flat_shape == 1 and moved.is_empty() and after.has("pause.tv") and not after.has("pause.game_shape"), "Changing Screen swaps one tile without nudging the page: %s" % [moved.map(func(id): return "%s %s -> %s" % [id, before[id], after[id]])])
	app.flat_shape = 0
	var actions: Array = app.menu.play.action_tiles().map(func(row): return row.id)
	check("xr_view" in actions and not "recenter" in actions, "XR view takes Recentre's place among the actions")
	app.menu.play.action_tiles().filter(func(row): return row.id == "xr_view")[0].action.call()
	check(not app.flat_screen and "recenter" in app.menu.play.action_tiles().map(func(row): return row.id), "XR view goes back to the room, and Recentre returns")
	app.set_flat_screen(true)
	await settle()
	var stereo_page: Array = []
	for page in app.menu.catalog.pages(0): stereo_page.append_array(page.rows)
	var shape_rows: Array = stereo_page.filter(func(row): return str(row.get("id", "")) == "view.flat_shape")
	check(not shape_rows.is_empty() and not shape_rows[0].get("disabled", false), "Stereo & comfort has Screen shape under Flat screen")
	app.close_settings()
	await settle()

	# Screenshots read the flat picture.
	var path: String = await app.take_screenshot()
	var shot := Image.load_from_file(path) if not path.is_empty() else null
	check(shot != null and shot.get_size() == app.flat.view.size, "Screenshots save the flat picture")
	if not path.is_empty(): DirAccess.remove_absolute(path)

	# Glasses sessions keep their own choice: Flat view on this screen stays out of the glasses.
	var saved: ConfigFile = app.capture_settings()
	saved.set_value("display", "flat_screen", true)
	saved.set_value("display", "flat_screen_glasses", false)
	app.sbs_startup = true
	app.apply_settings(saved)
	check(not app.flat_screen, "A glasses session ignores Flat view chosen for this screen")
	app.set_flat_screen(true)
	app.set_flat_screen(false)
	var from_glasses: ConfigFile = app.capture_settings()
	check(from_glasses.get_value("display", "flat_screen") == true and from_glasses.get_value("display", "flat_screen_glasses") == false, "Changing it in the glasses keeps this screen's choice")
	app.sbs_startup = false
	app.apply_settings(from_glasses)
	check(app.flat_screen, "This screen still starts in Flat view")
	# First-run setup asks for the screen's shape; the TV models only in TV's shape.
	var setup_ids: Array = app.menu.welcome.view_items().map(func(item): return str(item.get("id", "")))
	check("welcome.view.flat_shape" in setup_ids and not "welcome.tv.games" in setup_ids, "Setup in Flat view asks for the screen, not the TV: %s" % [setup_ids])
	app.flat_shape = 1
	setup_ids = app.menu.welcome.view_items().map(func(item): return str(item.get("id", "")))
	check("welcome.tv.games" in setup_ids, "In TV's shape, setup also asks for the TV")
	app.flat_shape = 0
	# The Deck's own screen starts in Flat view for anyone not yet asked, once.
	app.set_flat_screen(false)
	app.flat_view_offered = false
	app.start_flat_on_deck_screen(false)
	check(not app.flat_screen, "Off the Deck's screen nothing changes on its own")
	app.start_flat_on_deck_screen(true)
	check(app.flat_screen and app.flat_view_offered and app.capture_settings().get_value("display", "flat_screen") == true, "The Deck's screen starts in Flat view and remembers it")
	app.set_flat_screen(false)
	app.start_flat_on_deck_screen(true)
	check(not app.flat_screen, "Once turned off there, it stays off")
	app.set_flat_screen(true)
	await settle()

	# --flat applies for the launch without changing the saved choice.
	app.set_flat_screen(false)
	app.flat_screen_launch = true
	app.apply_settings(app.capture_settings())
	check(app.flat_screen and app.capture_settings().get_value("display", "flat_screen") == false, "A --flat launch is not saved as the choice")
	app.set_flat_screen(false)
	await settle()
	check(not app.flat_screen and not app.flat.layers[0].visible and app.views[0].render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Turning it off brings the room back")
	check(app.flat.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "The flat picture stops drawing when off")
	app.toggle_settings()
	await settle()
	check(app.tv_menu.active, "The menu goes back on the TV")
	check(app.world.widescreen or app.menu_view.size == Vector2i(960, 720), "The standard TV gets its 4:3 menu back")
	app.set_flat_screen(true)
	app.reset_all_options()
	check(not app.flat_screen and app.capture_settings().get_value("display", "flat_screen") == false, "Reset all settings turns flat screen off")
	# Flat view beside Exit: Down past the last row, Left, then A toggles it.
	if not app.settings_panel.visible: app.toggle_settings()
	app.menu.open_pause()
	await settle()
	var m = app.menu
	check(m.flat_footer.visible and m.exit_footer.visible and m.flat_footer.get_index() < m.exit_footer.get_index(), "Flat view sits beside Exit")
	m.notification_time = 0.0 # the earlier reset's notice would cover the help
	m.select(m.rows[-1].item.id, false)
	m.navigate(Vector2i.DOWN)
	check(m.exit_selected and not m.footer_flat, "Down past the last row reaches Exit")
	m.navigate(Vector2i.LEFT)
	check(m.exit_selected and m.footer_flat and m.help_label.text.contains("full-screen"), "Left moves to Flat view, and its help says what it does")
	m.activate()
	await settle()
	check(app.flat_screen and m.exit_selected and m.footer_flat and m.flat_footer.text.ends_with("On"), "A turns flat view on and keeps the button selected")
	m.activate()
	await settle()
	check(not app.flat_screen and m.footer_flat and not m.flat_footer.text.ends_with("On"), "A again turns it off")
	m.navigate(Vector2i.RIGHT)
	check(m.exit_selected and not m.footer_flat, "Right goes back to Exit")
	m.navigate(Vector2i.UP)
	check(not m.exit_selected and m.selected_row() != null, "Up returns to the menu")
	m.flat_footer.pressed.emit()
	await settle()
	check(app.flat_screen, "Clicking Flat view toggles it too")
	app.set_flat_screen(false)
	print("FLAT SCREEN CHECKS: ", "failed " + str(failures) if failures else "all passed")
	quit(1 if failures else 0)

## Every menu row's place on the canvas, by id.
func row_rects(app) -> Dictionary:
	var out := {}
	for row in app.menu.rows: out[str(row.item.id)] = row.get_global_rect()
	return out

## The flat menu canvas for the Deck's 16:10, a 16:9 and an ultrawide display:
## no bars in any of them, and the 16:10 page gains the extra height as rows.
func flat_menu_shapes(app) -> void:
	var original: Vector2i = root.size
	var standard_rows: float = app.menu.scroll.size.y
	for case in [[Vector2i(1280, 800), Vector2i(1280, 800)], [Vector2i(1920, 1080), Vector2i(1280, 720)], [Vector2i(2560, 1080), Vector2i(1706, 720)]]:
		root.size = case[0]
		await settle()
		check(app.menu_view.size == case[1], "Flat menu canvas for a %s display is %s: %s" % [case[0], case[1], app.menu_view.size])
		if case[1].y == 800:
			check(app.menu.reading_frame.size.y >= 744.0 and app.menu.scroll.size.y >= standard_rows + 79.0, "On 16:10 the page grows by 80 lines for more rows: %s" % app.menu.scroll.size.y)
	root.size = original
	await settle()

## The flat shader and the TV's surface, given the same values, draw the same
## pixels: a quad filling an orthographic view against a rectangle of the same size.
func shader_matches_tv() -> void:
	var size := Vector2i(320, 240)
	var image := Image.create(32, 24, false, Image.FORMAT_RGBA8)
	for y in range(24):
		for x in range(32):
			image.set_pixel(x, y, Color(float(x) / 31.0, float(y) / 23.0, 0.3 + 0.4 * float((x + y) % 2)))
	var source := ImageTexture.create_from_image(image)
	var values := {"signal_texture": source, "signal_size": Vector2(32, 24), "picture_rect": Vector4(0.05, 0.04, 0.9, 0.92),
		"scanlines": 0.3, "mask_strength": 0.2, "glow_strength": 0.15, "gamma": 2.4, "brightness": 1.1, "vignette": 0.08}
	var tv := SubViewport.new(); tv.size = size; tv.own_world_3d = true
	tv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(tv)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0; camera.position.z = 2.0
	tv.add_child(camera); camera.current = true
	var quad := MeshInstance3D.new(); quad.mesh = QuadMesh.new(); quad.mesh.size = Vector2(4.0 / 3.0, 1.0)
	var surface := ShaderMaterial.new(); surface.shader = load("res://shaders/crt.gdshader")
	quad.material_override = surface
	tv.add_child(quad)
	var flat := SubViewport.new(); flat.size = size; flat.disable_3d = true
	flat.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(flat)
	var rect := ColorRect.new(); rect.size = Vector2(size)
	var canvas := ShaderMaterial.new(); canvas.shader = load("res://shaders/crt_flat.gdshader")
	rect.material = canvas
	flat.add_child(rect)
	for key in values:
		surface.set_shader_parameter(key, values[key])
		canvas.set_shader_parameter(key, values[key])
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var a := tv.get_texture().get_image()
	var b := flat.get_texture().get_image()
	var worst := 0.0
	var total := 0.0
	var samples := 0
	var lit := 0
	for y in range(8, size.y - 8, 7):
		for x in range(8, size.x - 8, 7):
			var p := a.get_pixel(x, y); var q := b.get_pixel(x, y)
			var difference := maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b)))
			worst = maxf(worst, difference)
			total += difference
			samples += 1
			if q.get_luminance() > 0.05: lit += 1
	var mean := total / maxf(samples, 1)
	print("Flat against TV surface: mean channel difference ", mean, ", worst ", worst, ", lit samples ", lit)
	check(lit > 100, "The flat shader draws the picture")
	# Colour or gamma mismatches show as large mean differences; sub-pixel mask
	# phase between a 3D quad and a canvas rectangle leaves only a few levels.
	check(mean < 0.01 and worst < 0.05, "The flat shader matches the TV's surface")
	tv.queue_free(); flat.queue_free()
