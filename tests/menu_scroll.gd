extends SceneTree
## Moving through a long page keeps the selected row in view: into a grid of
## console cards, along it and out of it, one step at a time, as a controller
## moves. A row selected but scrolled out of view looks like nothing is.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func settle(frames := 4) -> void:
	for i in range(frames): await process_frame

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle(10)
	if not app.settings_panel.visible: app.toggle_settings()
	var m = app.menu
	m.games.open_library(); m.rom_index.cancel()
	var games := {}
	for system in ["snes", "nes", "megadrive", "mastersystem", "gamegear", "gb", "gba", "pcengine", "psx", "n64"]:
		games[system] = [{"path": "/fixture/%s.rom" % system, "label": "A %s game" % system}]
	m.rom_index.games = games
	m.render(); await settle()
	m.select(m.rows[0].item.id, false); await settle()
	var hidden := []
	for step in range(m.rows.size() + 2):
		m.navigate(Vector2i(0, 1)); await settle()
		var row = m.selected_row()
		var view: Rect2 = m.scroll.get_global_rect().grow(0.5)
		if row != null and not view.encloses(row.get_global_rect()): hidden.append(str(row.item.id))
	check(m.scroll.get_v_scroll_bar().max_value > m.scroll.size.y, "The library page is long enough to scroll")
	check(hidden.is_empty(), "Every row stays fully in view as the selection moves down: hidden %s" % [hidden])
	hidden.clear()
	for step in range(m.rows.size() + 2):
		m.navigate(Vector2i(0, -1)); await settle()
		var row = m.selected_row()
		if row != null and not m.scroll.get_global_rect().grow(0.5).encloses(row.get_global_rect()): hidden.append(str(row.item.id))
	check(hidden.is_empty(), "Every row stays fully in view as the selection moves up: hidden %s" % [hidden])
	app.free()
	print("MENU SCROLL CHECKS: ", "PASS" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)
