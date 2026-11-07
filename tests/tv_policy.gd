extends SceneTree
var failures := 0
var app
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1
func settle():
	for i in range(10): await process_frame
func run():
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await settle()
	var prefs = app.display_settings
	for console in ["snes", "ps2", "gamecube", "psp", "future-console"]:
		check(prefs.preferred_screen("game", console, "") == "standard", "New consoles start on 4:3: " + console)
	prefs.set_tv_policy("wide")
	check(prefs.preferred_screen("game", "future-console", "") == "wide", "Global policy includes future consoles")
	prefs.set_tv_policy("console")
	check(prefs.preferred_screen("game", "psp", "") == "wide" and prefs.preferred_screen("game", "snes", "") == "standard", "Curated policy chooses TVs by console")
	check(app.world.picture.keep_aspect and app.world.picture.fit_mode == 0, "Curated choices fit without stretching")
	prefs.set_platform_screen("snes", 2)
	prefs.set_preference("games", "my-game", "standard")
	prefs.data.pictures["game.standard.content.my-game"] = {"picture.width":0.8}
	prefs.set_tv_policy("standard")
	check(prefs.preferred_screen("game", "snes", "") == "wide", "Deliberate console override survives policy change")
	check(prefs.preferred_screen("game", "snes", "my-game") == "standard" and prefs.data.pictures["game.standard.content.my-game"]["picture.width"] == 0.8, "Per-game TV and picture survive policy change")
	var snapshot: ConfigFile = app.capture_settings()
	var persisted: Dictionary = snapshot.get_value("display_profiles", "data")
	persisted.platform_defaults_version = 99
	snapshot.set_value("display_profiles", "data", persisted)
	prefs.read(snapshot)
	check(prefs.data.game_tv_policy == "standard" and prefs.preferred_screen("game", "snes", "") == "wide", "Reload and version changes do not re-seed console defaults")
	# Old releases have no policy field and seed wide/stretch for PSP.
	var legacy: Dictionary = persisted.duplicate(true)
	legacy.erase("game_tv_policy"); legacy.erase("legacy_tv_seeds")
	legacy.platforms = {"psp":{"screen":"wide"}, "snes":{"screen":"wide"}}
	legacy.pictures["game.wide.platform.psp"] = {"picture.keep_aspect":false, "picture.fit_mode":0, "picture.gamma":1.9}
	snapshot.set_value("display_profiles", "data", legacy)
	prefs.read(snapshot)
	check(prefs.preferred_screen("game", "psp", "") == "wide" and prefs.data.pictures["game.wide.platform.psp"]["picture.keep_aspect"] == false, "Loading legacy settings preserves their current appearance")
	prefs.set_tv_policy("standard")
	check(prefs.preferred_screen("game", "psp", "") == "standard", "Explicit policy replaces obsolete generated console TV choices")
	check(prefs.data.pictures["game.wide.platform.psp"].get("picture.gamma") == 1.9 and not prefs.data.pictures["game.wide.platform.psp"].has("picture.keep_aspect"), "Seeded stretch is removed without losing custom picture fields")
	check(prefs.preferred_screen("game", "snes", "") == "wide", "Legacy console exceptions differing from seeds are preserved")
	app.welcome_done = true
	app.menu.welcome.open("view")
	await settle()
	var row: Dictionary = app.menu.items.filter(func(item): return item.id == "welcome.tv.games")[0]
	check(row.choices[0] == "Keep current" and row.getter.call() == 0, "Rerunning setup starts with Keep current preferences")
	var saved_data: Dictionary = prefs.data.duplicate(true)
	row.setter.call(0)
	check(prefs.data == saved_data, "Keeping preferences makes no changes")
	row.setter.call(2)
	check(prefs.data.game_tv_policy == "wide" and not app.menu.welcome.keep_display_preferences, "Setup selector applies the chosen policy")
	var frame: Rect2 = app.menu.get_global_rect()
	var canvas: Vector2i = app.menu_view.size
	for large in [false, true]:
		app.menu_large_text = large; app.menu.refresh(); await settle()
		var heading: Rect2 = app.menu.heading.get_global_rect()
		var video_row = app.menu.rows.filter(func(item): return item.item.id == "welcome.tv.videos")[0]
		var row_position: Vector2 = video_row.position
		for policy in ["wide", "standard", "console"]:
			prefs.set_tv_policy(policy); app.menu.refresh(); await settle()
			check(not app.tv_menu.active and app.menu.get_global_rect() == frame and app.menu.heading.get_global_rect() == heading and app.menu_view.size == canvas, "TV previews keep the menu frame stationary: %s large=%s" % [policy, large])
			video_row = app.menu.rows.filter(func(item): return item.item.id == "welcome.tv.videos")[0]
			check(video_row.position == row_position, "TV choices do not shift adjacent controls: " + policy)
	app.menu.select("welcome.tv.help", false); app.menu.activate(); await settle()
	check(app.menu.mode == "help" and not app.tv_menu.active and app.menu_view.size == canvas, "Fitting guide stays floating during TV setup")
	check(app.menu.help_copy.contains("A 4:3 game on the wide TV") and app.menu.help_copy.contains("PS2 and GameCube depend on the game"), "Guide explains mixed ratios and console-specific rendering")
	app.menu.back(); await settle()
	check(app.menu.mode == "welcome" and app.menu.selected_id == "welcome.tv.help", "Fitting guide returns to the same setup control")
	prefs.video_tv_row("test.video").setter.call(1)
	check(prefs.data.defaults.video == "standard" and prefs.data.game_tv_policy == "console", "Video TV choice is independent of games")
	app.free(); await process_frame
	print("TV POLICY COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
