extends SceneTree
## First-run setup (scripts/ui/menu_welcome.gd): who sees it, the boot logo's
## landing, every page and its controls, the pinned Next row, the pickers it
## borrows from the rest of the menu, and that finishing is remembered.
var app
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func settle() -> void:
	for i in range(8): await process_frame

## Saves the menu picture for review when running with a display.
func shot(title: String) -> void:
	await settle()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/welcome-review")
	app.menu_view.get_texture().get_image().save_png("res://build/welcome-review/" + title + ".png")

func row_ids() -> Array:
	return app.menu.rows.map(func(row): return str(row.item.id))

func texts(node: Node) -> String:
	var words := ""
	for label in node.find_children("*", "Label", true, false): words += label.text + "\n"
	return words

func press(button: int, down := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button; event.pressed = down
	app._input(event)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.pressed = true
	app._input(event)

func launch() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.use_tracking(false)

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg.bak"))
	await launch()
	var menu = app.menu
	var welcome = menu.welcome
	check(not app.welcome_done, "A new user, with no saved settings, has not done setup")
	check(menu.mode != "welcome", "Test scripts start without setup unless --welcome-preview asks for it")

	# Locale suggestions for the region page.
	check(welcome.suggested_region("en_GB") == "pal" and welcome.suggested_region("fr") == "pal", "Europe and bare languages suggest PAL")
	check(welcome.suggested_region("en_US") == "ntsc" and welcome.suggested_region("pt-BR") == "ntsc", "The Americas suggest NTSC")
	check(welcome.suggested_region("ja_JP") == "japan" and welcome.suggested_region("ja") == "japan", "Japanese suggests Japan")

	# Welcome: no title bar, the logo for the boot to land on, two choices.
	app.menu_reduced_motion = false; app.menu_high_contrast = false
	welcome.open()
	await shot("00-welcome")
	check(menu.mode == "welcome" and welcome.step == "welcome", "Setup opens on the Welcome page")
	check(not menu.heading.get_parent().visible and not menu.help_frame.visible, "Welcome has no title bar or help window")
	check(row_ids() == ["welcome.start", "welcome.skip"] and menu.selected_id == "welcome.start", "Welcome offers Let's get set up, then Skip setup")
	check(is_instance_valid(welcome.logo) and welcome.logo.get_child_count() == 3, "Welcome carries the boot logo with its three diamonds")

	# The boot logo glides onto the Welcome logo instead of flipping away.
	menu.begin_boot(); menu.boot.set_process(false)
	menu.boot.seek(0.7); await settle()
	check(menu.boot.landing == welcome.logo and welcome.logo.modulate.a == 0.0, "During boot the Welcome logo waits for the boot logo")
	menu.boot.seek(1.9); await settle()
	check(menu.boot.mark.modulate.a > 0.99 and is_equal_approx(float(menu.boot.material_logo.get_shader_parameter("angle")), 0.0), "The boot logo stays face-on for setup")
	menu.boot.seek(3.0); await settle()
	var target: Vector2 = welcome.logo.global_position - menu.boot.global_position
	check(menu.boot.mark.position.distance_to(target) <= 2.0 and menu.boot.mark.size.distance_to(welcome.logo.size) <= 1.0, "The boot logo lands exactly on the Welcome logo")
	menu.boot.seek(5.0); await settle()
	check(not is_instance_valid(menu.boot) and welcome.logo.modulate.a == 1.0, "After boot the Welcome logo is shown in its place")

	# Controls: the shortcut is the lesson, and Escape or the chord does not close setup.
	menu.select("welcome.start", false); menu.activate()
	await shot("01-controls")
	check(welcome.step == "controls" and menu.subtitle.text == "First-run setup · Step 1 of 6", "Controls is step 1 of 6")
	check(menu.step_marks.visible and menu.step_marks.get_child_count() == 6, "Six step marks show beside the subtitle")
	check(menu.pinned.visible and menu.pinned.get_child_count() == 1 and menu.selected_id == "welcome.next", "Continue is pinned below the page")
	check(not menu.scroll.is_ancestor_of(menu.selected_row()), "The pinned row sits outside the scrolling page")
	check(menu.hints.text.contains("X Skip setup"), "The footer offers Skip setup")
	for button in app.emulator.gamepad.MENU_BUTTONS: press(button)
	await settle()
	check(app.settings_panel.visible and welcome.shortcut_done and texts(menu.column).contains("Got it"), "The menu shortcut is recognised without closing the menu")
	for button in app.emulator.gamepad.MENU_BUTTONS: press(button, false)
	await create_timer(1.2).timeout
	await settle()
	await shot("01b-controls-pressed")
	check(welcome.step == "controls" and menu.selected_row().item.label == "Continue", "The shortcut stays on Controls and its row becomes Continue")
	menu.activate(); await settle()
	check(welcome.step == "view", "Continue moves on to Your view")

	# Your view: status, recentring, TV placement and where the menu sits.
	await shot("02-view")
	check(texts(menu.column).contains("Playing on this screen"), "Fixed view is described plainly")
	check(row_ids().has("welcome.view.connect") and row_ids().has("welcome.view.fixed"), "Without tracking, Connect glasses and Use fixed view are offered")
	key(KEY_ESCAPE); await settle()
	check(app.settings_panel.visible and menu.mode == "welcome" and menu.help_label.text.contains("skip"), "Escape outside Controls says how to leave instead of closing setup")
	var distance: float = app.distance
	for floating in [false, true]:
		app.menu_on_tv = not floating
		menu.select("welcome.view.distance", false); menu.activate(); await settle()
		check(menu.preview and not app.tv_menu.active and menu.items.size() == 2, "TV distance opens the preview with the menu " + ("floating" if floating else "on the TV"))
		menu.navigate(Vector2i.RIGHT)
		check(app.distance > distance, "Right moves the TV farther in the preview")
		menu.reset_option(); menu.back(); await settle()
		check(not menu.preview and menu.mode == "welcome" and welcome.step == "view", "B leaves the preview back on Your view")
	app.menu_on_tv = true
	menu.select("welcome.view.height_offset", false); menu.navigate(Vector2i.RIGHT); await settle()
	check(menu.preview, "Left or right on Screen height opens the preview too")
	menu.back(); await settle()
	await shot("02b-view-after-preview")
	menu.select("welcome.view.menu", false); menu.adjust(1)
	check(not app.menu_on_tv, "Menu position switches to Floating")
	menu.adjust(1)
	check(app.menu_on_tv, "Menu position switches back to On the TV")
	menu.back(); await settle()
	check(welcome.step == "controls", "B goes back a step")
	welcome.go("region"); await settle()

	# Console region: chosen live, with the consoles named for it.
	await shot("03-region")
	check(menu.subtitle.text.ends_with("Step 3 of 6"), "Region is step 3")
	menu.select("welcome.region.ntsc", false); menu.activate(); await settle()
	check(app.console_region == "ntsc" and texts(menu.column).contains("Genesis") and texts(menu.column).contains("Dreamcast"), "NTSC shows Genesis, and Dreamcast is in the preview")
	menu.select("welcome.region.japan", false); menu.activate(); await settle()
	check(texts(menu.column).contains("Super Famicom"), "Japan shows Super Famicom")
	menu.select("welcome.region.pal", false); menu.activate(); await settle()
	check(app.console_region == "pal", "PAL is chosen again")

	# Library: the folder browser returns here; choosing a folder scans it.
	welcome.go("library"); await settle()
	await shot("04-library")
	check(row_ids().has("welcome.library.browse") and row_ids().has("welcome.library.later"), "Library offers Browse folders and Not now")
	menu.select("welcome.library.browse", false); menu.activate(); await settle()
	check(menu.mode == "browser" and welcome.choosing == "library", "Browse folders opens the folder browser for setup")
	menu.back(); await settle()
	check(menu.mode == "welcome" and welcome.step == "library" and welcome.choosing == "", "Back from the browser returns to setup")
	var roms := ProjectSettings.globalize_path("user://welcome-roms")
	for folder in ["snes", "megadrive", "saturn"]: DirAccess.make_dir_recursive_absolute(roms.path_join(folder))
	for file in ["snes/One.sfc", "snes/Two.sfc", "megadrive/Three.gen", "saturn/Four.cue"]:
		var handle := FileAccess.open(roms.path_join(file), FileAccess.WRITE); handle.store_buffer(PackedByteArray([0, 0, 0, 0])); handle.close()
	menu.library.show_folder(roms); menu.mode = "browser"; welcome.choosing = "library"; menu.render(); await settle()
	menu.select("folder.remember", false); menu.activate(); await settle()
	check(menu.mode == "welcome" and welcome.step == "found" and app.default_rom_dir == roms, "Use this folder returns to setup's results")
	while menu.rom_index.scanning: menu.rom_index.step()
	menu.refresh(); await settle()
	await shot("05-found")
	var found: String = texts(menu.column)
	check(found.contains("3 games") and found.contains("across 2 consoles"), "The results count games and consoles")
	check(found.contains("SKIPPED"), "Folders for unsupported consoles are worth knowing about")
	check(menu.pinned.get_child_count() == 1 and menu.selected_id == "welcome.next", "Next stays pinned below the results")
	check(menu.hints.text.contains("Choose another folder"), "B offers another folder")

	# Videos & music: the music browser chooses a folder and returns.
	welcome.go("media"); await settle()
	await shot("06-media")
	menu.select("welcome.media.music", false); menu.activate(); await settle()
	check(menu.mode == "music_browser" and row_ids().has("music.use_folder"), "The music browser offers Use this folder for music")
	var music_here: String = menu.music.music_dir
	menu.select("music.use_folder", false); menu.activate(); await settle()
	check(menu.mode == "welcome" and welcome.step == "media" and app.music_folder == music_here, "Choosing a music folder returns to setup and is remembered")
	var recent := ConfigFile.new(); recent.load("user://recent.cfg")
	check(recent.get_value("music", "folder", "") == music_here, "The music folder is saved with the library")

	# Comfort: rows scroll; Finish stays pinned.
	welcome.go("comfort"); await settle()
	await shot("07-comfort")
	check(menu.pinned.get_child_count() == 1 and menu.pinned.get_child(0).item.label == "Finish", "Finish is pinned below the comfort options")
	menu.select("welcome.large", false); menu.activate(); await settle()
	check(app.menu_large_text, "Larger menu text turns on from setup")
	await shot("07b-comfort-large")
	check(menu.pinned.get_child(0).is_visible_in_tree(), "Finish stays on screen with larger text")
	menu.select("welcome.large", false); menu.activate(); await settle()
	menu.select("welcome.picture", false); menu.adjust(1)
	check(menu.pictures.applied_preset() == "clean", "Picture style steps to the next preset")
	menu.adjust(-1)

	# All set: finishing is remembered and saved; Run setup again is in About & Help.
	welcome.go("done"); await settle()
	await shot("08-done")
	check(texts(menu.column).contains("Menu any time") and row_ids() == ["welcome.library", "welcome.home"], "All set reminds you of the shortcut and offers the library or Home")
	menu.select("welcome.home", false); menu.activate(); await settle()
	check(app.welcome_done and menu.mode == "pause" and not welcome.active, "Go to Home finishes setup")
	var saved := ConfigFile.new(); saved.load("user://settings.cfg")
	check(saved.get_value("welcome", "done", false) == true, "Finishing is saved")
	check(menu.catalog.pages(6)[0].rows.any(func(row): return row.id == "system.setup"), "About & Help offers Run setup again")
	welcome.open("view"); await settle()
	key(KEY_X); await settle()
	check(welcome.step == "done", "X skips to All set")
	welcome.finish()
	app.reset_all_options()
	check(app.welcome_done, "Reset all settings does not bring setup back")
	app.free(); await settle()

	# Who sees it: saved settings from before setup existed count as set up.
	var older := ConfigFile.new(); older.set_value("view", "distance", 3.0); older.save("user://settings.cfg")
	await launch()
	check(app.welcome_done, "Existing settings without a welcome entry skip setup")
	app.free(); await settle()
	older.set_value("welcome", "done", false); older.save("user://settings.cfg")
	await launch()
	check(not app.welcome_done, "Setup left unfinished shows again")
	app.free()
	print("WELCOME FLOW: ", failures, " failures")
	quit(1 if failures else 0)
