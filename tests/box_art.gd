extends SceneTree
## Box art from local scrapes, the header's time and battery, and the glasses guide.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func picture(path: String, size: Vector2i) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(Color("c0392b"))
	image.save_png(path)

func run() -> void:
	# An EmuDeck-style tree: Emulation/roms and Emulation/tools/downloaded_media.
	var base := ProjectSettings.globalize_path("user://box-art-test/Emulation")
	var roms := base.path_join("roms")
	var probe := FileAccess.get_file_as_bytes("res://build/crt-xr-probe.sfc")
	for game in ["snes/Super Soup World.sfc", "snes/Plain Game.sfc", "snes/RPGs/Deep Quest.sfc", "megadrive/Sonic the Hedge.md"]:
		DirAccess.make_dir_recursive_absolute(roms.path_join(game).get_base_dir())
		var file := FileAccess.open(roms.path_join(game), FileAccess.WRITE); file.store_buffer(probe); file.close()
	picture(base.path_join("tools/downloaded_media/snes/covers/Super Soup World.png"), Vector2i(300, 420))
	picture(base.path_join("tools/downloaded_media/snes/covers/RPGs/Deep Quest.png"), Vector2i(300, 420))
	picture(roms.path_join("megadrive/media/box2dfront/Sonic the Hedge.png"), Vector2i(280, 400))

	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(6): await process_frame
	var art = app.box_art
	art.set_root(roms)
	check(art.find(roms.path_join("snes/Super Soup World.sfc")).ends_with("downloaded_media/snes/covers/Super Soup World.png"), "Finds EmuDeck / ES-DE covers by the game's file name")
	check(art.find(roms.path_join("snes/RPGs/Deep Quest.sfc")).ends_with("covers/RPGs/Deep Quest.png"), "Follows ROM subfolders, as ES-DE mirrors them")
	check(art.find(roms.path_join("megadrive/Sonic the Hedge.md")).ends_with("media/box2dfront/Sonic the Hedge.png"), "Finds art beside the ROMs too")
	check(art.find(roms.path_join("snes/Plain Game.sfc")).is_empty(), "A game without art has none")
	var soup := roms.path_join("snes/Super Soup World.sfc")
	check(art.texture(soup) == null, "Art loads in the background rather than holding up the menu")
	var arrived: Array = []
	art.art_ready.connect(func(path, texture): arrived.append([path, texture]))
	for i in range(200):
		if not arrived.is_empty(): break
		await process_frame
	check(not arrived.is_empty() and arrived[0][0] == soup and arrived[0][1] != null and arrived[0][1].get_height() <= art.MAX_HEIGHT, "Loaded art arrives shrunk to fit a row")

	app.default_rom_dir = roms
	if not app.settings_panel.visible: app.toggle_settings()
	var menu = app.menu
	var row: Dictionary = menu.games.game_item(soup, "Super Soup World")
	check(row.get("thumbnail_path", "") == soup and row.get("thumbnail") != null, "Game rows carry their box art")
	check(not menu.games.game_item(roms.path_join("snes/Plain Game.sfc"), "Plain Game").has("thumbnail_path"), "Rows without art keep their plain layout")

	# The header: time, and the battery where there is one.
	var status = menu.status_line
	check(status.label.text.contains(":"), "The menu header shows the time: %s" % status.label.text)
	check(status.icon.visible == not status.battery_folder.is_empty(), "The battery shows only where the system has one")

	# Glasses help.
	var about: Array = menu.catalog.pages(6)[0].rows.map(func(item): return item.id)
	check("system.glasses" in about and menu.play.glasses_guide().contains("SBS"), "About & Help explains using glasses")
	print("BOX ART CHECKS COMPLETE: %d failures" % failures)
	quit(1 if failures else 0)
