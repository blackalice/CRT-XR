extends SceneTree
## A game's page: cover, details from the gamelist, and a description that is
## looked up online only when asked.
const Info = preload("res://scripts/content/game_info.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func settle(frames := 6) -> void:
	for i in range(frames): await process_frame
func run():
	# Choosing the article: a game, preferably on this console.
	var pages := [{"key": "F-Zero", "description": "Video game series"}, {"key": "F-Zero_(film)", "description": "2001 film"},
		{"key": "F-Zero_(video_game)", "description": "1990 video game for the Super Nintendo Entertainment System"}]
	check(Info.pick(pages, ["Super Nintendo"]).key == "F-Zero_(video_game)", "The article naming the console is chosen")
	check(Info.pick([{"key": "F-Zero_(film)", "description": "2001 film"}], ["SNES"]).is_empty(), "A film is never taken for the game")
	# The gamelist's description and details, read for one game.
	var roms := ProjectSettings.globalize_path("user://info-roms")
	DirAccess.make_dir_recursive_absolute(roms.path_join("snes"))
	var rom := roms.path_join("snes/Super Metroid (Japan, USA) (En,Ja).sfc")
	var f := FileAccess.open(rom, FileAccess.WRITE); f.store_string("x"); f.close()
	f = FileAccess.open(roms.path_join("snes/gamelist.xml"), FileAccess.WRITE)
	f.store_string("<gameList><game><path>./Super Metroid (Japan, USA) (En,Ja).sfc</path><name>Super Metroid</name><desc>Samus returns to Zebes.</desc><releasedate>19940319T000000</releasedate><genre>Action</genre><players>1</players><developer>Nintendo R&amp;D1</developer></game></gameList>")
	f.close()
	var local := Info.from_gamelist(rom, roms)
	check(local.get("description") == "Samus returns to Zebes." and local.get("year") == "1994" and local.get("developer") == "Nintendo R&D1", "The gamelist gives the description and details: %s" % [local])
	# The page.
	var app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await settle(10)
	app.apply_settings(ConfigFile.new()); app.use_tracking(false)
	var m = app.menu
	if not app.settings_panel.visible: app.toggle_settings()
	app.default_rom_dir = roms
	m.games.library_system = "snes"; m.mode = "games"; m.rom_index.games["snes"] = [{"path": rom, "label": "Super Metroid", "sort": "super metroid"}]
	m.render(); await settle()
	m.select("game:" + rom, false)
	check(m.hints.text.contains("Y Details"), "The footer offers Y Details")
	m.games.game_title_action(); await settle()
	check(m.mode == "game_info" and m.heading.text == "Super Metroid", "Y opens the game's page")
	var text := ""
	for node in m.column.find_children("*", "Label", true, false): text += node.text + "\n"
	check(text.contains("Samus returns to Zebes.") and text.contains("From your gamelist") and text.contains("1994"), "The page shows the description, its source and the year")
	var ids: Array = m.items.map(func(item): return item.id)
	check(ids.has("game_info.play") and ids.has("game_info.favourite") and not ids.has("game_info.lookup"), "With a description already, it doesn't offer to look one up: %s" % [ids])
	m.select("game_info.play", false); m.navigate(Vector2i.RIGHT)
	check(m.selected_id == "game_info.favourite", "Play and Favourite sit side by side")
	check(not app.library_info_online, "Online look-ups are off unless turned on")
	m.back(); await settle()
	check(m.mode == "games" and m.selected_id == "game:" + rom, "Back returns to the same game")
	app.free(); await settle()
	print("GAME INFO: %d failures" % failures)
	quit(1 if failures else 0)
