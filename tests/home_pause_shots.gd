extends SceneTree
## Renders the Home and Pause menus into build/home-pause-shots/ for comparison with the
## design exports, and prints where each group sits. Not a regression test and not in
## test-beta.py (the runner is headless, which draws nothing): run it in a window, with
## isolated user data, as  build/shots.sh home_pause_shots
const OUT := "res://build/home-pause-shots/"
const UI = preload("res://tests/menu_test_helpers.gd")
var app

func settle(frames := 10) -> void:
	for i in range(frames): await process_frame

func frame_image(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var sky := Color(0.35 + 0.3 * float(y) / height, 0.2, 0.55)
			if y > height * 0.55: sky = Color(0.15, 0.17 + 0.2 * float(x) / width, 0.2)
			image.set_pixel(x, y, sky)
	return image

func capture(name: String) -> void:
	await settle(8)
	await RenderingServer.frame_post_draw
	app.menu_view.get_texture().get_image().save_png(OUT + name + ".png")
	report(name)

func report(name: String) -> void:
	var m = app.menu
	var parts: Array = []
	for row in m.rows:
		var rect: Rect2 = row.get_global_rect()
		parts.append("%s=(%d,%d %dx%d)" % [row.item.id, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	print("SHOT ", name, " help_y=", int(m.help_frame.get_global_rect().position.y), " hints_y=", int(m.hints.get_global_rect().position.y), " exit=", m.exit_footer.get_global_rect())
	print("  ", " ".join(parts))
	for child in m.column.get_children():
		if child is Label: print("  heading ", child.text, " y=", int(child.get_global_rect().position.y), " h=", int(child.size.y))
	for child in m.pinned.get_children():
		if child is Label: print("  pinned heading ", child.text, " y=", int(child.get_global_rect().position.y), " h=", int(child.size.y))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	if is_instance_valid(app.menu.boot): app.menu.boot.finish()
	app.menu_boot_pending = false
	app.menu_reduced_motion = true
	var game := "user://shots/Starline Circuit.sfc"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var file := FileAccess.open(game, FileAccess.WRITE); file.store_string("rom"); file.close()
	await settle()
	var m = app.menu
	for wide in [false, true]:
		var suffix := "16x9" if wide else "4x3"
		app.set_widescreen(wide)
		# Home without a recent game
		app.last_game_path = ""
		app.default_rom_dir = ""
		app.toggle_settings() if not app.settings_panel.visible else null
		m.open_pause(); await capture("home-no-recent-" + suffix)
		# Home with Continue
		app.last_game_path = game
		app.play_history.played_at[game] = int(Time.get_unix_time_from_system()) - 86400
		app.play_history.play_seconds[game] = 1800
		m.open_pause(); await capture("home-continue-" + suffix)
		app.play_history.favourites.assign([game])
		m.open_pause(); await capture("home-continue-favourite-" + suffix)
		app.play_history.favourites.clear()
	app.set_widescreen(false)
	# Pause with a 4:3 and a 16:9 frame
	app.emulator.set_process(false) # a pretend game has no core to run
	app.emulator.loaded = true; app.emulator.rom_path = game; app.emulator.system_id = "snes"
	app.last_game_path = game
	for shape in [[256, 192, 4.0 / 3.0, "pause-4x3"], [320, 180, 16.0 / 9.0, "pause-16x9"]]:
		app.emulator.last_frame = frame_image(shape[0], shape[1]); app.emulator.display_aspect = shape[2]
		m.open_pause(); await capture(shape[3])
	app.play_history.favourites.assign([game])
	m.open_pause(); await capture("pause-favourited")
	app.play_history.favourites.clear()
	app.emulator.loaded = false
	# Home with music playing: the transport deck stays under Media and the page scrolls if it must.
	app.last_game_path = game
	var album := ProjectSettings.globalize_path("res://build/album-fixture")
	if DirAccess.dir_exists_absolute(album) and app.music.play_album(album):
		m.music.panel_hidden = false
		for wide in [false, true]:
			app.set_widescreen(wide)
			m.open_pause(); await capture("home-music-" + ("16x9" if wide else "4x3"))
		app.set_widescreen(false)
		app.music.stop()
	# The mini player opened from the Music tile before anything has played: Browse Music leads.
	var played_kind = app.music.kind
	app.music.kind = ""
	m.music.panel_hidden = false
	m.open_pause(); await capture("home-music-idle-4x3")
	app.music.kind = played_kind
	m.music.panel_hidden = true
	# A video pause: its card, Start over and Stop, the Position row, then the shared groups.
	app.video.loaded = true; app.video.path = "user://shots/Holiday film.mp4"
	app.video.info = {"duration": 3725.0, "display_aspect": 16.0 / 9.0, "codec": "h264"}
	app.video.clock = 612.0
	app.video.last_frame = frame_image(320, 180)
	app.video.set_process(false)
	m.open_pause(); await capture("pause-video")
	app.video.loaded = false
	app.free()
	quit()

func _initialize() -> void: call_deferred("run")
