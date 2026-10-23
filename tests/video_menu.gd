extends SceneTree
## Videos in the game library, playback controls and resume points.
## Needs FFmpeg (the system copy, or CRT_XR_FFMPEG_DIR) and the clips from
## tests/make_video_fixtures.py. Restores the video folder, library folder and
## video picture profile it changes.
var failures := 0
const LIBRARY := "res://build/video-fixtures/library"
const RESUME_TEST := "user://video_resume_test.cfg"
const PROFILE := "user://games/video.cfg"
var app
var menu

func _initialize(): call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func ids() -> Array:
	return menu.items.map(func(item): return item.id)

func item(id: String) -> Dictionary:
	for entry in menu.items:
		if entry.id == id: return entry
	return {}

func activate(id: String) -> void:
	menu.select(id, false)
	menu.activate()

func press(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	app._input(event)
	var release: InputEventJoypadButton = event.duplicate()
	release.pressed = false
	app._input(release)

## SettingsStore recovers from a .bak copy, so scratch files go with theirs.
func remove_with_backup(path: String) -> void:
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

## Needs FFmpeg (the system copy, or CRT_XR_FFMPEG_DIR) and the clips from
## tests/make_video_fixtures.py; without either the suite skips and says why.
func skip_reason() -> String:
	var Session := preload("res://scripts/video/video_session.gd")
	if not Session.available(): return "no FFmpeg: " + Session.unavailable_reason()
	if not FileAccess.file_exists(ProjectSettings.globalize_path("res://build/video-fixtures/library/long_43_25.mp4")):
		return "no clips: run python tests/make_video_fixtures.py <ffmpeg>"
	return ""

func run() -> void:
	var reason := skip_reason()
	if not reason.is_empty():
		print("CHECKS SKIPPED: " + reason)
		quit(0)
		return
	remove_with_backup(RESUME_TEST)
	var Library := preload("res://scripts/video/video_library.gd")
	var folder := ProjectSettings.globalize_path(LIBRARY)
	var long := folder.path_join("long_43_25.mp4")
	var season := folder.path_join("Season 1")

	# Listing and resume rules, on a scratch resume file.
	var store = Library.new(RESUME_TEST)
	var listed: Array = store.list(folder).map(func(entry): return entry.label)
	check(listed == ["Season 1", "Episode 2", "Episode 10", "long_43_25"], "Folders first, then videos in natural order; other files ignored: %s" % [listed])
	check(store.count(folder) == 4, "Videos in subfolders are counted")
	check(absf(store.duration(long) - 60.0) < 0.2, "Lengths come from the file header (%.2f s)" % store.duration(long))
	store.remember(long, 5.0, 60.0, 1)
	check(store.position(long) == 0.0 and store.style(long) == 1, "An early position is not kept; the picture shape is")
	store.remember(long, 25.0, 60.0, 2)
	check(is_equal_approx(store.position(long), 25.0) and store.style(long) == 2, "A mid-video position is kept with its shape")
	store.remember(long, 45.0, 60.0, 2)
	check(store.position(long) == 0.0, "Near the end, the video starts over next time")
	check(Library.clock(3725) == "1:02:05" and Library.clock(65) == "1:05", "Times read as h:mm:ss or m:ss")
	var Bar := preload("res://scripts/ui/location_bar.gd")
	var sd := "/run/media/deck/b0a23cb2"
	check(Bar.segments(sd + "/Videos/TV", "/home/deck", [sd]) == PackedStringArray(["SD card", "Videos", "TV"]), "The location bar names the SD card")
	check(Bar.segments("/home/deck/Music", "/home/deck", [sd]) == PackedStringArray(["Home", "Music"]), "The location bar names the home folder")
	check(Bar.segments("D:/ROMtest", "C:/Users/me", []) == PackedStringArray(["D:", "ROMtest"]) and Bar.segments("//haruna/Elements/Videos", "", []) == PackedStringArray(["Network", "haruna", "Elements", "Videos"]),
		"Drives and network shares read as their own roots")
	remove_with_backup(RESUME_TEST)

	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(4): await process_frame
	menu = app.menu
	var saved_video_dir: String = app.video_dir
	var saved_rom_dir: String = app.default_rom_dir
	var saved_profile: Dictionary = {}
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(PROFILE + suffix): saved_profile[suffix] = FileAccess.get_file_as_string(PROFILE + suffix)
	remove_with_backup(PROFILE)
	app.video_library = Library.new(RESUME_TEST)
	app.video_dir = ""
	app.default_rom_dir = ""
	# Per-game picture off (the default) must still keep the video picture apart.
	var saved_remember: bool = app.remember_game_picture
	app.remember_game_picture = false
	if not app.settings_panel.visible: app.toggle_settings()

	menu.open_library()
	check(not "library.videos" in ids(), "No Videos card until a folder is chosen")
	menu.open_library_tools()
	check("library.video_folder" in ids() and not "library.video_clear" in ids() and item("library.video_folder").section == "VIDEOS · OPTIONAL", "Library locations offers an optional video folder in its own section")
	menu.open_video_folder_picker(folder)
	check(ids()[0] == "video_folder.use" and item("video_folder.use").emphasis == "primary" and ("video_folder.open:" + season) in ids() and str(item("video_folder.use").detail).begins_with("3 videos here"),
		"The folder picker leads with its action, counts the videos here and lists subfolders")
	check(menu.location_bar.visible and not menu.subtitle.visible and item("video_folder.open:" + season).section == menu.SECTION_INSIDE and item("video_folder.open:" + season).row_icon == "folder",
		"The path shows in the location bar and folders sit under Contents with a folder icon")
	activate("video_folder.use")
	check(app.video_dir == folder and menu.mode == "library", "Choosing the folder saves it and returns to the library")
	check(ids() == ["library.setup", "library.videos"], "With no ROMs yet, Videos sits beside the setup card: %s" % [ids()])
	# With games, Videos follows the last console and precedes Library locations.
	menu.rom_index.games["snes"] = [{"path": "C:/roms/snes/Test.sfc", "label": "Test"}]
	menu.render()
	var cards := ids()
	var at := cards.find("library.videos")
	check(at > 0 and str(cards[at - 1]).begins_with("library.system.") and cards[at + 1] == "library.locations", "Videos follows the consoles: %s" % [cards])
	check(item("library.videos").value == "4 videos" and item("library.videos").glyph == "videos", "The card counts the videos")
	var pages: Array = menu.catalog.pages(1)
	var video_page: Array = pages.filter(func(page): return page.title == "Video")
	var video_rows: Array = video_page[0].rows.map(func(row): return row.id) if video_page.size() == 1 else []
	check(["video.default_style", "video.lines", "video.interlace", "video.subtitles_default", "video.osd", "video.hardware", "video.own_picture", "video.reset_picture"].all(func(id): return id in video_rows) and not "video.picture_note" in video_rows,
		"Picture settings gain a Video page with shape, lines, interlacing, subtitles, decoding and the video picture: %s" % [video_rows])
	if OS.get_name() == "Windows":
		var setup: Array = menu.video_setup_items("VIDEOS · OPTIONAL")
		check(setup.size() == 1 and setup[0].id == "library.ffmpeg_setup" and setup[0].emphasis == "primary" and str(setup[0].detail).contains("MB"),
			"Without FFmpeg, Windows offers to set up video playback and says how big it is")

	activate("library.videos")
	var labels: Array = menu.items.filter(func(entry): return entry.get("section", "") == menu.SECTION_INSIDE).map(func(entry): return entry.label)
	check(menu.mode == "videos" and labels == ["Season 1", "Episode 2", "Episode 10", "long_43_25"] and "videos.search" in ids(), "The video list, with search: %s" % [labels])
	var thumbnail_row = null
	for i in range(400):
		for row in menu.rows:
			if row.item.get("thumbnail_path", "") == long and row.thumbnail != null and row.thumbnail.texture != null: thumbnail_row = row
		if thumbnail_row != null: break
		await process_frame
	check(thumbnail_row != null and thumbnail_row.thumbnail.texture.get_size() == Vector2(128, 96), "Thumbnails appear in the list as they are made")
	menu.open_video_search()
	menu.rename_field.text = "episode"
	menu.run_video_search()
	check(menu.mode == "videos" and ("video:" + folder.path_join("Episode 2.mkv")) in ids() and ("video:" + folder.path_join("Episode 10.mkv")) in ids() and not ("video:" + long) in ids(),
		"Searching finds matching videos: %s" % [ids()])
	menu.open_video_search()
	menu.rename_field.text = "PILOT"
	menu.run_video_search()
	check(str(item("video:" + season.path_join("Pilot.mp4")).get("detail", "")).contains("Season 1"), "Search reaches subfolders and says where each video is")
	activate("videos.clear_search")
	check(menu.search_query.is_empty() and "videos.search" in ids(), "Clearing the search returns to the folder")
	check(item("video:" + long).detail == "1:00", "Each video shows its length (%s)" % item("video:" + long).get("detail"))
	activate("videos.folder:" + season)
	check(ids() == ["videos.up", "video:" + season.path_join("Pilot.mp4")], "Subfolders open in place with a way back up")
	menu.back()
	check(menu.mode == "videos" and menu.video_view_dir == folder, "Back steps up to the video folder")
	menu.back()
	check(menu.mode == "library", "Back again returns to the library")

	var global_mode: int = app.world.picture.mode
	activate("library.videos")
	activate("video:" + long)
	check(app.video.loaded and not app.settings_panel.visible and app.video.path == long, "Choosing a video plays it with the menu closed (loaded %s, menu %s, mode %s, path %s, error %s)" % [app.video.loaded, app.settings_panel.visible, menu.mode, app.video.path, menu.error_label.text])
	check(app.world.picture.mode == 3 and app.active_game_key == app.VIDEO_PROFILE, "Videos start with the auto composite picture")

	press(JOY_BUTTON_DPAD_RIGHT)
	check(absf(app.video.clock - 10.0) < 0.2, "D-pad right skips forward 10 seconds (%.2f)" % app.video.clock)
	press(JOY_BUTTON_DPAD_UP)
	check(absf(app.video.clock - 59.5) < 0.2, "D-pad up skips a minute, stopping short of the end")
	press(JOY_BUTTON_DPAD_DOWN)
	press(JOY_BUTTON_DPAD_LEFT)
	check(app.video.clock < 0.2, "D-pad down and left skip back, stopping at the start")
	press(JOY_BUTTON_Y)
	check(app.video.style == 1 and app.video.decoder.get_style() == 1, "Y changes the picture shape")
	press(JOY_BUTTON_A)
	check(app.video.paused, "A pauses")
	press(JOY_BUTTON_A)
	check(not app.video.paused, "A plays again")

	# Holding the D-pad scrubs: one step, then repeats after a short delay.
	app.video.seek_to(5.0)
	var held := InputEventJoypadButton.new()
	held.button_index = JOY_BUTTON_DPAD_RIGHT
	held.pressed = true
	app._input(held)
	for i in range(60): app._process(1.0 / 60.0)
	var release: InputEventJoypadButton = held.duplicate()
	release.pressed = false
	app._input(release)
	var scrubbed: float = app.video.clock
	for i in range(30): app._process(1.0 / 60.0)
	check(scrubbed > 35.0 and absf(app.video.clock - scrubbed) < 1.0, "Holding right scrubs forward and stops on release (%.1f s)" % scrubbed)
	check(app.video_bars.all(func(bar): return bar.visible) and app.video_bars[0].title == "long_43_25", "The on-screen bar shows while seeking")
	press(JOY_BUTTON_A)
	for i in range(300): app._process(1.0 / 60.0)
	check(app.video_bars[0].visible and app.video_bars[0].paused, "The bar stays up while paused")
	press(JOY_BUTTON_A)
	for i in range(300): app._process(1.0 / 60.0)
	check(not app.video_bars[0].visible, "And hides a few seconds after playing again")

	app.video.seek_to(25.0)
	press(JOY_BUTTON_B)
	app._process(1.0 / 60.0)
	check(not app.video_bars[0].visible, "The bar gives way to the menu")
	check(app.settings_panel.visible and menu.mode == "pause" and app.video.paused, "B opens the menu and pauses the video")
	check(menu.selected_id == "resume" and ids().slice(0, 2) == ["resume", "video.seek"] and "video.style" in ids() and "video.stop" in ids(),
		"The menu opens on Resume above a timeline, with picture shape and Stop: %s" % [ids()])
	check(str(item("video.seek").progress.call()) == "0:25 / 1:00", "The timeline shows where you are")
	check(is_equal_approx(app.video_library.position(long), 25.0) and app.video_library.style(long) == 1, "Opening the menu saves the place and shape")
	menu.select("video.seek", false)
	menu.adjust(1)
	check(absf(app.video.clock - 35.0) < 0.2 and app.video.paused, "Right on the timeline scrubs forward 10 seconds, still paused")
	for i in range(30): await process_frame
	check(absf(app.video.decoder.frame_time() - 35.0) < 0.1, "The paused TV shows the scrubbed frame (%.2f s)" % app.video.decoder.frame_time())
	menu.adjust(-1)
	check(absf(app.video.clock - 25.0) < 0.2, "Left scrubs back")
	menu.select("video.style", false)
	menu.adjust(1)
	check(app.video.style == 2 and app.video_library.style(long) == 2, "Left/right changes the picture shape from the menu and remembers it")
	menu.adjust(-1)
	# Picture pages say plainly which picture they change.
	menu.category = 1; menu.subsection = 0; menu.open_settings()
	check(menu.subtitle.text.begins_with("Editing the video picture · all videos"), "Picture settings say they are editing the video picture (%s)" % menu.subtitle.text)
	# Same as games: the video switches to the global picture at once, and back.
	app.set_video_own_picture(false)
	check(app.active_game_key == "" and app.world.picture.mode == global_mode, "Same as games puts videos on the global picture")
	menu.open_settings()
	check(menu.subtitle.text.begins_with("Editing the global picture · games, videos and test signal"), "And the Picture pages say so")
	app.set_video_own_picture(true)
	check(app.active_game_key == app.VIDEO_PROFILE and app.world.picture.mode == 3, "Own settings brings the video picture back")
	menu.open_pause()
	# Choosing the same picture as the global one must still be remembered for videos.
	app.world.picture.mode = global_mode
	activate("video.stop")
	check(not app.video.loaded and app.pattern.visible and menu.mode == "pause", "Stop returns the TV to the test signal")
	check(app.world.picture.mode == global_mode and FileAccess.file_exists(PROFILE), "The video picture is kept even when it matches the global one (mode %d, global %d, profile %s, games dir %s)" % [app.world.picture.mode, global_mode, FileAccess.file_exists(PROFILE), DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://games"))])

	menu.open_videos()
	check(item("video:" + long).detail == "1:00 · Resume at 0:25", "The list shows where you stopped")
	check(ids()[0] == "video.continue:" + long and item("video.continue:" + long).section == "CONTINUE WATCHING", "Continue watching leads the list")
	menu.open_library()
	check("library.continue" in ids(), "The library offers Continue watching")
	menu.open_videos()
	activate("video:" + long)
	check(menu.mode == "video_launch" and ids() == ["video_launch.continue", "video_launch.fresh", "video_launch.cancel"], "A saved place offers Continue or Start from the beginning")
	activate("video_launch.continue")
	check(app.video.loaded and absf(app.video.clock - 25.0) < 0.2 and app.video.style == 1, "Continue resumes at the saved place in the saved shape")
	check(app.world.picture.mode == global_mode, "The remembered video picture applies")
	app.reset_video_picture()
	check(app.world.picture.mode == 3 and app.active_game_key == app.VIDEO_PROFILE, "Reset video picture starts again from Auto composite")
	app.toggle_settings()
	activate("video.restart")
	check(not app.settings_panel.visible and app.video.clock < 0.2, "Start from the beginning plays from the start")
	app.stop_video()

	# Subtitles from the pause menu, remembered for the video.
	var episode := folder.path_join("Episode 2.mkv")
	check(app.play_video(episode) and app.video.subtitle_choice == -1, "Subtitles start off by default")
	app.toggle_settings()
	check("video.subtitles" in ids(), "The pause menu offers subtitles when a video has them")
	menu.select("video.subtitles", false)
	menu.adjust(1)
	check(app.video.subtitle_choice == 0 and app.video_library.subtitle(episode) == "File · Episode 2.en.srt", "Choosing subtitles turns them on and remembers the choice")
	app.close_settings()
	app.stop_video()
	check(app.play_video(episode) and app.video.subtitle_choice == 0, "The video opens with its remembered subtitles")
	app.stop_video()

	app.toggle_settings()
	menu.open_library_tools()
	activate("library.video_clear")
	check(app.video_dir.is_empty(), "Removing the video folder forgets it")
	menu.open_library()
	check(not "library.videos" in ids(), "And the Videos card goes away")

	app.remember_game_picture = saved_remember
	app.video_dir = saved_video_dir
	app.default_rom_dir = saved_rom_dir
	app.save_library()
	remove_with_backup(PROFILE)
	for suffix in saved_profile:
		var restore := FileAccess.open(PROFILE + suffix, FileAccess.WRITE)
		restore.store_string(saved_profile[suffix])
		restore.close()
	remove_with_backup(RESUME_TEST)
	app.free()
	print("VIDEO MENU CHECKS COMPLETE: %d failures" % failures)
	quit(1 if failures else 0)
