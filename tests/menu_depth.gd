extends SceneTree
## Menu depth: per-eye shifts, lifted selection, room dim, preview and settings.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func settle(frames := 20) -> void:
	for i in range(frames): await process_frame

func shift(app, eye: int, key: String) -> float:
	return float(app.menu_depth_view.materials[eye].get_shader_parameter(key))

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle(10)
	app.menu_reduced_motion = true # settle animations at once for measurement
	app.set_stereo(true)
	await settle(3)
	if not app.settings_panel.visible: app.toggle_settings()
	app.menu.open_settings(); app.menu.category = 1; app.menu.subsection = 1; app.menu.render()
	await settle()
	var layout: Dictionary = app.menu.depth_layout()
	check(layout.page.size.x > 0 and layout.lift.size.x > 0 and not layout.has("side"), "The menu reports its page and lifted row; the sidebar stays flat: %s" % [layout])
	check(app.menu.selected_row().get_global_rect().intersection(layout.page).is_equal_approx(layout.lift), "The lifted row is the selected row, clipped to the page")
	var left := shift(app, 0, "base_shift")
	var right := shift(app, 1, "base_shift")
	check(left > 0.0 and is_equal_approx(left, -right), "In stereo the menu floats in front: the left eye shifts right, the right eye left (%.1f, %.1f px)" % [left, right])
	var near: float = app.menu_depth_view.menu_distance()
	check(near < float(app.distance), "The menu sits in front of the TV (%.2f m vs %.2f m)" % [near, app.distance])
	var lift := shift(app, 0, "lift_shift")
	check(lift > 0.0 and is_equal_approx(lift, -shift(app, 1, "lift_shift")), "The selected row lifts further towards you (%.1f px)" % lift)
	check(shift(app, 0, "shadow") == 0.0, "No shadow in stereo; the depth carries the lift")
	check(app.menu_depth_view.dim_nodes[0].visible, "The room dims behind the open menu")

	check(shift(app, 0, "curve_shift") == 0.0 and shift(app, 0, "curve_height") == 0.0, "The menu is flat unless Curved menu is on")
	app.menu_curve = true
	await settle(3)
	check(shift(app, 0, "curve_shift") > 0.0 and is_equal_approx(shift(app, 0, "curve_shift"), -shift(app, 1, "curve_shift")) and shift(app, 0, "curve_height") > 0.0,
		"Curved menu brings the side edges closer in both eyes and makes them a touch taller (%.1f px, %.3f)" % [shift(app, 0, "curve_shift"), shift(app, 0, "curve_height")])
	app.menu_curve = false
	app.menu.toggle_preview()
	await settle()
	check(app.menu.preview and not app.menu_depth_view.dim_nodes[0].visible, "The compact preview leaves the room undimmed")
	check(shift(app, 0, "base_shift") > 0.0, "The preview strip still floats in front")
	check(app.menu.depth_layout().lift.size == Vector2.ZERO, "Nothing lifts in the preview strip")
	app.menu.toggle_preview()
	await settle()

	app.menu_depth = false
	await settle(3)
	check(shift(app, 0, "base_shift") == 0.0 and not app.menu_depth_view.dim_nodes[0].visible, "Menu depth off gives a flat menu over an undimmed room")
	app.menu_depth = true

	app.close_settings()
	app.set_stereo(false)
	await settle(3)
	app.toggle_settings()
	app.menu.open_settings()
	await settle()
	check(shift(app, 0, "base_shift") == 0.0, "Mono has no shift")
	check(float(app.menu_depth_view.materials[0].get_shader_parameter("lift_scale")) > 1.0 and shift(app, 0, "shadow") > 0.0, "Mono lifts with a slight scale-up and a shadow")

	# Library cards lift as a whole, icons and all, on one plane.
	app.menu.open_library()
	await settle()
	var cards: Dictionary = app.menu.depth_layout()
	check(cards.lift.size.x > 0 and not cards.has("pop"), "A selected library card lifts as one piece: %s" % [cards])

	app.menu_haptics = true
	app.menu_vibrate(0.1, 0.02)
	check(true, "Vibration with no controller connected is harmless")
	var saved: ConfigFile = app.capture_settings()
	check(saved.get_value("accessibility", "menu_depth") == true and saved.get_value("accessibility", "menu_haptics") == true and saved.get_value("accessibility", "menu_curve") == false, "Menu depth, curve and controller vibration are saved")
	var rows: Array = []
	for page in app.menu.catalog.pages(6): rows.append_array(page.rows.map(func(row): return row.id))
	check("access.depth" in rows and "access.curve" in rows and "access.haptics" in rows and "access.haptic_strength" in rows, "Accessibility offers Menu depth, Curved menu, Controller vibration and its strength")
	check(is_equal_approx(float(saved.get_value("accessibility", "haptic_strength")), 0.8), "Vibration strength is saved (80% by default)")
	print("MENU DEPTH CHECKS COMPLETE: %d failures" % failures)
	quit(1 if failures else 0)
