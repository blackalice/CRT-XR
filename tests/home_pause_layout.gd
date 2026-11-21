extends SceneTree
## Home and Pause (menu_play.gd): the shared Media, Quick settings and pinned Actions groups, the
## Continue and current-game cards, Favourite, and the Pause cache.
## Geometry is the brief's: a reading area of x = 54..906 on 960 px and 214..1066 on 1280, three
## 278 px columns, Actions from y = 525, help at 588, shortcuts at 638.
const PlayHistory = preload("res://scripts/content/play_history.gd")
var app
var m
var failures := 0
var game := ""

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func settle(frames := 8) -> void:
	for i in range(frames): await process_frame

func rect(id: String) -> Rect2:
	for row in m.rows:
		if row.item.id == id: return row.get_global_rect()
	return Rect2(-1, -1, -1, -1)

func row(id: String):
	for candidate in m.rows:
		if candidate.item.id == id: return candidate
	return null

func near(a: float, b: float, tolerance := 0.6) -> bool:
	return absf(a - b) <= tolerance

func frame_image(width: int, height: int, tint: Color) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(tint)
	return image

func reopen() -> void:
	m.open_pause()
	await settle()

func home(recent: bool) -> void:
	app.emulator.loaded = false
	app.last_game_path = game if recent else ""
	app.default_rom_dir = ""
	await reopen()

func pause(shape := Vector2i(256, 192), aspect := 4.0 / 3.0, tint := Color.RED) -> void:
	app.emulator.loaded = true; app.emulator.rom_path = game; app.emulator.system_id = "snes"
	app.emulator.last_frame = frame_image(shape.x, shape.y, tint); app.emulator.display_aspect = aspect
	await reopen()

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	if is_instance_valid(app.menu.boot): app.menu.boot.finish()
	app.menu_boot_pending = false
	app.menu_reduced_motion = true
	m = app.menu
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://home-pause"))
	game = "user://home-pause/Starline Circuit.sfc"
	var file := FileAccess.open(game, FileAccess.WRITE); file.store_string("rom"); file.close()
	await settle(10)
	if not app.settings_panel.visible: app.toggle_settings()
	# A pretend game has no core to run: stop the session ticking.
	app.emulator.set_process(false)
	app.emulator.rom_hash = "homepause"
	DirAccess.make_dir_recursive_absolute(app.emulator.save_directory)

	for wide in [false, true]:
		var left := 214.0 if wide else 54.0
		var right := 1066.0 if wide else 906.0
		var label := "16:9" if wide else "4:3"
		app.set_widescreen(wide)
		await settle()

		# Home with nothing to continue.
		await home(false)
		check(m.selected_id == "home.library", "%s: Games has the initial focus with no recent game" % label)
		check(m.items.all(func(item): return item.id != "home.continue"), "%s: no Continue card without a recent game" % label)
		var media: Array = ["home.library", "home.videos", "media.music"]
		check(media.all(func(id): return near(rect(id).size.y, 112.0)), "%s: Media tiles are 112 px tall without a recent game: %s" % [label, media.map(func(id): return rect(id).size)])
		check(near(rect("home.library").position.x, left) and near(rect("media.music").end.x, right), "%s: Media spans x = %d..%d: %s .. %s" % [label, left, right, rect("home.library").position.x, rect("media.music").end.x])
		check(media.all(func(id): return near(rect(id).size.x, 278.0)) and near(rect("home.videos").position.x - rect("home.library").end.x, 9.0), "%s: three equal 278 px columns, 9 px apart" % label)
		check(row("home.library").title_label.text == "Games" and row("home.videos").title_label.text == "Videos" and row("media.music").title_label.text == "Music", "%s: Media tiles are Games, Videos and Music" % label)
		var quick: Array = ["pause.preset", "pause.room", "pause.tv", "pause.view.distance", "pause.fit", "pause.game_volume"]
		check(near(rect("pause.preset").position.x, left) and near(rect("pause.tv").end.x, right) and near(rect("pause.game_volume").end.x, right), "%s: Quick settings span x = %d..%d" % [label, left, right])
		check(quick.all(func(id): return near(rect(id).size.x, 278.0) and near(rect(id).size.y, 44.0)), "%s: Quick settings are 278 x 44 px tiles" % label)
		check(near(rect("pause.view.distance").position.y - rect("pause.preset").end.y, 6.0), "%s: Quick settings rows are 6 px apart" % label)
		check(near(rect("pause.preset").position.y, 284.0) and near(rect("pause.view.distance").position.y, 334.0), "%s: Quick settings rows start at y = 284 and 334 without a recent game: %s" % [label, rect("pause.preset").position.y])
		check(near(rect("home.library").position.y, 131.0), "%s: Media tiles start at y = 131 without a recent game" % label)
		check(m.items.filter(func(item): return item.get("group", "") == "actions").map(func(item): return item.id) == ["home.settings", "home.glasses"], "%s: first-run Actions are Settings and Using glasses" % label)
		check(near(rect("home.settings").position.x, left) and near(rect("home.settings").position.y, 525.0) and near(rect("home.settings").size.y, 44.0), "%s: Actions start at y = 525, 44 px tall" % label)
		check(near(rect("home.settings").size.x, 206.0, 1.0) and near(rect("home.glasses").position.x - rect("home.settings").end.x, 9.0, 1.0) and rect("home.glasses").end.x < left + 2 * 206.25 + 9.0 + 1.0, "%s: Actions use 206.25 px slots 9 px apart (two filled, none stretched): %s %s" % [label, rect("home.settings"), rect("home.glasses")])
		check(near(m.help_frame.get_global_rect().position.y, 588.0) and near(m.hints.get_global_rect().position.y, 638.0), "%s: help at y = 588, shortcuts at y = 638: %s / %s" % [label, m.help_frame.get_global_rect().position.y, m.hints.get_global_rect().position.y])
		check(near(m.exit_footer.get_global_rect().end.x, right) and near(m.exit_footer.get_global_rect().position.y, 639.0, 2.0), "%s: Exit sits at the right of the shortcut row: %s" % [label, m.exit_footer.get_global_rect()])
		check(row("home.glasses").get_parent().get_parent() == m.pinned, "%s: Actions are pinned, outside the scrolling page" % label)

		# Home with Continue.
		app.play_history.played_at[game] = int(Time.get_unix_time_from_system()) - 86400
		app.play_history.play_seconds[game] = 1800
		await home(true)
		check(m.selected_id == "home.continue", "%s: Continue has the initial focus" % label)
		var continue_rect := rect("home.continue")
		check(near(continue_rect.position.x, left) and near(continue_rect.end.x, right) and near(continue_rect.position.y, 102.0) and near(continue_rect.size.y, 84.0), "%s: the Continue card is 84 px tall across the reading area from y = 102: %s" % [label, continue_rect])
		check(media.all(func(id): return near(rect(id).size.y, 84.0)) and near(rect("home.library").position.y, 223.0), "%s: Media tiles are 84 px tall from y = 223 with Continue" % label)
		check(near(rect("pause.preset").position.y, 348.0) and near(rect("pause.view.distance").position.y, 398.0), "%s: Quick settings rows start at y = 348 and 398 with Continue" % label)
		var actions: Array = m.items.filter(func(item): return item.get("group", "") == "actions").map(func(item): return item.id)
		check(actions == ["home.settings", "home.recenter", "home.glasses", "favourite"], "%s: Continue's Actions are Settings, Recentre view, Using glasses, Favourite: %s" % [label, actions])
		check(near(rect("home.settings").position.x, left) and near(rect("favourite").end.x, right, 1.0) and near(rect("favourite").position.y, 525.0), "%s: four Actions fill x = %d..%d from y = 525: %s" % [label, left, right, rect("favourite")])
		check(row("home.continue").detail_label.text.begins_with("SNES") and row("home.continue").detail_label.text.contains("Last played"), "%s: the Continue card names the console and when it was played: %s" % [label, row("home.continue").detail_label.text])
		check(row("home.continue").trailing_label.text == "Continue ›" and near(row("home.continue").trailing_label.get_global_rect().end.x, right - 14.0, 1.0), "%s: Continue › sits at the card's right edge" % label)
		var trailing: Rect2 = row("home.continue").trailing_label.get_global_rect()
		check(near(trailing.get_center().y, continue_rect.get_center().y, 1.5), "%s: Continue › is vertically centred" % label)
		m.notification_time = 0.0; m.refresh_labels()
		check(m.help_label.text.begins_with("Open your last cartridge"), "%s: the help window explains Continue" % label)

		# A long title changes nothing about the layout.
		var long_name := "user://home-pause/" + "Starline Circuit Deluxe Turbo Championship Edition ".repeat(2) + ".sfc"
		var long_file := FileAccess.open(long_name, FileAccess.WRITE); long_file.store_string("rom"); long_file.close()
		var before_media := rect("home.library")
		app.last_game_path = long_name
		await reopen()
		check(near(rect("home.continue").size.x, 852.0) and near(rect("home.continue").size.y, 84.0) and near(rect("home.library").size.x, before_media.size.x) and near(rect("home.library").position.y, before_media.position.y), "%s: a long title does not widen or lengthen the Continue card or move Media" % label)
		check(row("home.continue").title_label.get_combined_minimum_size().x < 400.0 and row("home.continue").title_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "%s: a long title is trimmed with an ellipsis" % label)
		DirAccess.remove_absolute(long_name)
		app.last_game_path = game

		# Favourite on Home's Continue game.
		app.play_history.favourites.clear()
		await reopen()
		check(row("favourite").title_label.text == "Favourite" and row("favourite").item.row_icon == "heart_outline", "%s: Favourite shows an outline heart" % label)
		m.select("favourite", false)
		m.activate()
		check(game in app.play_history.favourites, "%s: Favourite adds the Continue game to the play history" % label)
		check(row("favourite") != null and row("favourite").title_label.text == "Favourited" and row("favourite").item.row_icon == "heart" and row("favourite").item.emphasis == "primary", "%s: the tile reads Favourited with a filled amber heart at once" % label)
		await settle(3)
		check(m.selected_id == "favourite" and near(rect("favourite").position.y, 525.0), "%s: toggling keeps the focus and the place: %s %s" % [label, m.selected_id, rect("favourite")])
		var reloaded := PlayHistory.new(); reloaded.path = app.play_history.path; reloaded.read()
		check(game in reloaded.favourites, "%s: the favourite is saved and survives a reload" % label)
		m.activate()
		check(game not in app.play_history.favourites and row("favourite").title_label.text == "Favourite", "%s: a second press takes it off again" % label)

	# Pause, on the standard canvas.
	app.set_widescreen(false)
	await settle()
	await pause()
	check(m.selected_id == "resume", "Pause starts on the current-game card")
	var card := rect("resume")
	check(near(card.size.x, 549.0) and near(card.size.y, 84.0) and near(card.position.x, 54.0) and near(card.position.y, 102.0), "The current-game card is 549 x 84 px at (54, 102): %s" % [card])
	var small: Array = ["save_state", "load_state", "reset_game"]
	check(small.all(func(id): return near(rect(id).size.x, 92.0) and near(rect(id).size.y, 84.0)), "Save, Load and Reset are 92 px tiles 84 px tall")
	check(near(rect("save_state").position.x - card.end.x, 9.0) and near(rect("load_state").position.x - rect("save_state").end.x, 9.0) and near(rect("reset_game").end.x, 906.0), "The top row is separated by 9 px and ends at x = 906")
	check(row("save_state").title_label.text == "Save" and row("load_state").title_label.text == "Load" and row("reset_game").title_label.text == "Reset", "The small tiles read Save, Load and Reset")
	check(near(rect("games").position.y, 223.0) and near(rect("games").size.y, 44.0) and near(rect("pause.preset").position.y, 308.0) and near(rect("pause.view.distance").position.y, 358.0), "Compact Media row is 44 px at y = 223; Quick settings rows at y = 308 and 358")
	check(m.heading.text == "CRT XR", "Pause heading is CRT XR: %s" % m.heading.text)
	var pause_actions: Array = m.items.filter(func(item): return item.get("group", "") == "actions").map(func(item): return item.id)
	check(pause_actions == ["settings", "screenshot", "recenter", "favourite"], "Pause Actions are Settings, Screenshot, Recentre view, Favourite: %s" % [pause_actions])
	check(near(rect("settings").position.y, 525.0) and near(rect("favourite").end.x, 906.0, 1.0), "Pause Actions start at y = 525 and fill the row")
	check(row("resume").title_label.text == "Starline Circuit" and row("resume").detail_label.text == "SNES · Current session: just started", "The card shows the title and console and session: %s" % row("resume").detail_label.text)
	check(row("resume").trailing_label.text == "›", "The card ends in a chevron")
	app.session_seconds = 5400.0
	await reopen()
	check(row("resume").detail_label.text == "SNES · Current session: 1h 30m", "The session reads 1h 30m after 5400 s: %s" % row("resume").detail_label.text)
	app.session_seconds = 0.0

	# The preview takes the shape of the game's screen.
	var thumb: Rect2 = row("resume").thumbnail.get_global_rect()
	check(near(row("resume").slot.get_global_rect().size.x, 96.0) and near(row("resume").slot.get_global_rect().size.y, 72.0) and row("resume").thumbnail.visible, "A 4:3 game previews at 96 x 72: %s" % [row("resume").slot.get_global_rect()])
	check(row("resume").thumbnail.texture.get_image().get_pixel(5, 5).is_equal_approx(Color.RED), "The preview is the frame the game paused on")
	await pause(Vector2i(320, 180), 16.0 / 9.0, Color.BLUE)
	check(near(row("resume").slot.get_global_rect().size.x, 128.0) and near(row("resume").slot.get_global_rect().size.y, 72.0), "A 16:9 game previews at 128 x 72: %s" % [row("resume").slot.get_global_rect()])
	check(near(rect("resume").size.x, 549.0), "The card keeps its width whatever the picture's shape")
	check(row("resume").thumbnail.texture.get_image().get_pixel(5, 5).is_equal_approx(Color.BLUE), "A later pause shows the new frame, not the cached one")
	var first_texture = row("resume").thumbnail.texture
	await pause(Vector2i(320, 180), 16.0 / 9.0, Color.GREEN)
	check(row("resume").thumbnail.texture != first_texture and row("resume").thumbnail.texture.get_image().get_pixel(5, 5).is_equal_approx(Color.GREEN), "The same page reopened takes the newest frame: the reused card is updated")
	var cached_rows: Array = m.rows.duplicate()
	m.render()
	check(m.rows.size() == cached_rows.size() and m.rows[0] == cached_rows[0], "Rendering again reuses the cached rows")

	# Missing preview.
	app.emulator.last_frame = null
	await reopen()
	check(not row("resume").thumbnail.visible and row("resume").slot.get_children().any(func(child): return child.get_script() != null and child.visible and "kind" in child and str(child.kind) == "snes"), "Without a frame the card shows the console's icon in its slot")
	check(near(row("resume").slot.get_global_rect().size.x, 128.0) and near(rect("resume").size.x, 549.0), "A missing picture leaves the card and its slot as they were")

	# Favourite on Pause targets the loaded game and the cache shows it the next time.
	app.play_history.favourites.clear()
	await pause()
	m.select("favourite", false)
	m.activate()
	check(game in app.play_history.favourites and row("favourite").title_label.text == "Favourited" and row("favourite").item.row_icon == "heart", "Pause Favourite adds the loaded game and shows Favourited at once")
	m.open_settings(); await settle()
	m.back(); await settle()
	check(m.mode == "pause" and row("favourite") != null and row("favourite").get_parent().get_parent() == m.pinned and near(rect("favourite").position.y, 525.0), "After Settings and Back the Actions are still pinned at y = 525")
	check(row("favourite").title_label.text == "Favourited", "…and still read Favourited")
	app.play_history.favourites.clear()
	await reopen()
	check(row("favourite").title_label.text == "Favourite" and row("favourite").item.row_icon == "heart_outline", "A game unfavourited elsewhere reads Favourite on the next pause (no stale state)")

	# The card resumes, Save and Load open the slots, Reset asks first.
	m.select("save_state", false); m.activate(); await settle()
	check(m.mode == "states" and m.play.states_saving, "Save opens the save slots")
	m.back(); await settle()
	check(m.mode == "pause" and near(rect("settings").position.y, 525.0) and row("settings").get_parent().get_parent() == m.pinned, "Back from the slots keeps the Actions pinned")
	check(row("load_state").disabled, "Load is unavailable until the game has a save")
	var slot_file := FileAccess.open(app.emulator.state_path(1), FileAccess.WRITE); slot_file.store_buffer(var_to_bytes({"version": 1})); slot_file.close()
	await reopen()
	m.select("load_state", false); m.activate(); await settle()
	check(m.mode == "states" and not m.play.states_saving, "Load opens the slots for loading")
	m.back(); await settle()
	DirAccess.remove_absolute(app.emulator.state_path(1))
	m.select("reset_game", false); m.activate(); await settle()
	check(m.mode == "confirm" and m.confirmation.title == "Reset the game?", "Reset asks before restarting")
	m.back(); await settle()
	check(m.mode == "pause" and app.emulator.loaded, "Cancelling Reset leaves the game as it was")
	m.select("resume", false); m.activate(); await settle()
	check(not app.settings_panel.visible, "Activating the card resumes play")
	app.toggle_settings(); await settle()

	# A long title on Pause.
	var long_name := "user://home-pause/" + "Starline Circuit Deluxe Turbo Championship Edition ".repeat(2) + ".sfc"
	var long_file := FileAccess.open(long_name, FileAccess.WRITE); long_file.store_string("rom"); long_file.close()
	app.emulator.rom_path = long_name
	await reopen()
	check(near(rect("resume").size.x, 549.0) and near(rect("save_state").position.x, 612.0) and near(rect("games").position.y, 223.0), "A long title does not widen the card or push the small tiles")
	app.emulator.rom_path = game
	DirAccess.remove_absolute(long_name)

	# A game on several discs gives the card 101 px for a fourth tile.
	app.emulator.disc_snapshot = {"count": 2, "index": 0, "labels": PackedStringArray(["Disc 1", "Disc 2"])}
	await reopen()
	check(near(rect("resume").size.x, 448.0) and near(rect("change_disc").size.x, 92.0) and near(rect("change_disc").end.x, 906.0) and near(rect("reset_game").end.x + 9.0, rect("change_disc").position.x), "A multi-disc game puts Change disc beside Reset and narrows the card to 448 px")
	app.emulator.disc_snapshot = {"count": 0, "index": 0, "labels": PackedStringArray()}
	await reopen()

	# The controller visits the visible rows in order.
	m.select("resume", false)
	var path: Array = [m.selected_id]
	for step in range(3):
		m.navigate(Vector2i(0, 1)); path.append(m.selected_id)
	check(path == ["resume", "games", "pause.preset", "pause.view.distance"], "Down walks the card, Media, then each Quick settings row: %s" % [path])
	m.navigate(Vector2i(0, 1))
	check(m.selected_id == "settings", "…and then the pinned Actions: %s" % m.selected_id)
	m.navigate(Vector2i(1, 0)); m.navigate(Vector2i(1, 0)); m.navigate(Vector2i(1, 0))
	check(m.selected_id == "favourite", "Right moves along the Actions")
	m.navigate(Vector2i(0, -1))
	check(m.selected_id == "pause.game_volume", "Up from an Action returns to the quick tile above it: %s" % m.selected_id)
	m.select("resume", false)
	m.navigate(Vector2i(1, 0))
	check(m.selected_id == "save_state", "Right on the card moves to Save")

	# Media destinations.
	await home(false)
	m.select("home.library", false); m.activate()
	check(m.mode == "library", "Games opens the library")
	m.back(); await settle()
	m.select("home.videos", false); m.activate()
	check(m.mode == "videos", "Videos opens the video library")
	m.back(); await settle()
	m.select("media.music", false); m.activate(); await settle()
	check(m.mode == "pause" and m.items.any(func(i): return i.id == "transport.choose" and i.get("caption", "") == "Browse Music"), "Music opens the mini player, with Browse Music")
	m.select("transport.choose", false); m.activate()
	check(m.mode == "music_browser", "Browse Music opens the music browser")
	m.back(); await settle()
	m.select("media.music", false); m.activate(); await settle()
	check(not m.items.any(func(i): return i.id == "transport.choose"), "Music again puts the mini player away")
	check(m.mode == "pause" and near(rect("home.settings").position.y, 525.0) and row("home.settings").get_parent().get_parent() == m.pinned, "Home survives a visit to a media page with its Actions pinned")

	# Session time counts only unpaused play.
	app.emulator.loaded = true; app.emulator.paused = false
	app.play_clock_game = app.emulator.rom_path
	app.session_seconds = 0.0
	app.track_play_time(2.0)
	app.emulator.paused = true
	app.track_play_time(5.0)
	check(near(app.session_seconds, 2.0), "The session counts unpaused play only: %s" % app.session_seconds)
	app.emulator.loaded = false
	app.play_clock_game = ""

	app.free()
	await process_frame
	print("HOME PAUSE LAYOUT COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
