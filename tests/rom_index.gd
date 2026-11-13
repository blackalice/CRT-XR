extends SceneTree
const Index = preload("res://scripts/content/rom_index.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ",text)
	if not ok: failures+=1
func _initialize(): call_deferred("run")
func settle():
	for i in range(4): await process_frame
func press(code: int):
	var event := InputEventJoypadButton.new()
	event.device=7; event.button_index=code; event.pressed=true
	Input.parse_input_event(event); Input.flush_buffered_events(); await settle()
	event.pressed=false; Input.parse_input_event(event); Input.flush_buffered_events(); await settle()
func run():
	var folder := ProjectSettings.globalize_path("user://indexed-roms")
	for sub in ["snes/Europe","megadrive","NES/Translations","images","bios"]:
		DirAccess.make_dir_recursive_absolute(folder.path_join(sub))
	for path in ["snes/Game 10.sfc","snes/Game 2.sfc","snes/Europe/Game 1.sfc","NES/Translations/Translated.NES","images/ignored.sfc","bios/ignored.sfc","notes.md"]:
		var file := FileAccess.open(folder.path_join(path),FileAccess.WRITE); file.store_string("fixture, not executed"); file.close()
	var file := FileAccess.open(folder.path_join("megadrive/Genesis.md"),FileAccess.WRITE)
	var data := PackedByteArray(); data.resize(0x110); data.encode_u32(0x100,0x41474553); file.store_buffer(data); file.close()
	var index := Index.new(); index.start(folder)
	check(index.scanning,"Scan starts incrementally")
	index.step(100000,1)
	check(index.scanning and index.examined<=1,"Entry budget yields before completing scan")
	while index.scanning: index.step()
	check(index.total()==5,"Recurses into system/subfolders and ignores metadata")
	check(index.games.nes.size()==1 and index.games.megadrive.size()==1,"Uppercase extensions and Sega header detection")
	check(index.games.snes.map(func(game): return game.label)==["Game 1","Game 2","Game 10"],"Natural alphabetical ordering, no file extensions")
	# Clean titles: numbered release lists, articles and region clashes.
	var named := ProjectSettings.globalize_path("user://named-roms")
	DirAccess.make_dir_recursive_absolute(named.path_join("gba"))
	DirAccess.make_dir_recursive_absolute(named.path_join("snes"))
	var gba_names := ["1001 - Metroid Fusion (U).gba","1002 - Advance Wars (U).gba","1003 - Golden Sun (U).gba","1004 - Mother 3 (J).gba","1005 - Kirby (E).gba"]
	var snes_names := ["Legend of Zelda, The (USA).sfc","Legend of Zelda, The (Europe).sfc","Aladdin (U) [!].smc","Aladdin (U) [b1].smc","1943 - The Battle of Midway (1988)(Capcom)(US).sfc"]
	for name in gba_names: FileAccess.open(named.path_join("gba/"+name),FileAccess.WRITE).store_8(0)
	for name in snes_names: FileAccess.open(named.path_join("snes/"+name),FileAccess.WRITE).store_8(0)
	# The player's own gamelist names a game; unscraped entries only repeat the file name.
	var listing := FileAccess.open(named.path_join("snes/gamelist.xml"),FileAccess.WRITE)
	listing.store_string("<?xml version=\"1.0\"?>\n<gameList>\n<game id=\"1\"><path>./1943 - The Battle of Midway (1988)(Capcom)(US).sfc</path><name>1943: The Battle of Midway</name><desc>Long <b>text</b> &amp; more</desc><releasedate>19880601T000000</releasedate><genre>Shooter</genre><players>1-2</players></game>\n<game><path>./Aladdin (U) [!].smc</path><name>Aladdin (U) [!]</name></game>\n<game><path>./Missing.sfc</path><name>Not here</name></game>\n</gameList>\n")
	listing.close()
	var titled := Index.new(); titled.start(named)
	while titled.scanning: titled.step()
	check(titled.games.gba.map(func(game): return game.label)==["Advance Wars","Golden Sun","Kirby","Metroid Fusion","Mother 3"],"Numbered release lists lose their numbers and sort by name")
	check(titled.games.snes.map(func(game): return game.label)==["1943: The Battle of Midway","Aladdin","Aladdin","The Legend of Zelda","The Legend of Zelda"],"Titles drop tags, restore The, sort under the main word, and use the gamelist's names")
	var midway: Dictionary = Index.GameTitle.info(titled.games.snes[0].path)
	check(midway.year=="1988" and midway.genre=="Shooter" and midway.players=="1-2" and midway.variant=="USA","The gamelist adds year, genre and players; the file keeps its region")
	index.start(folder.path_join("missing"))
	check(not index.scanning and index.total()==0 and index.message.contains("Reconnect"),"Missing storage clears stale games and offers recovery")
	index.start(folder); index.cancel()
	check(not index.scanning and index.directory==null,"Cancelled scan releases directory handle")
	for i in range(62):
		file=FileAccess.open(folder.path_join("snes/Collection %02d.sfc" % i),FileAccess.WRITE); file.store_8(0); file.close()
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	app.use_tracking(false)
	app.default_rom_dir=folder
	app.choose_rom()
	var menu=app.menu
	while menu.rom_index.scanning: await process_frame
	await settle()
	check(menu.items.any(func(item): return item.id=="library.system.snes") and menu.items.any(func(item): return item.id=="library.system.megadrive"),"System selector appears after scan")
	check(not menu.items.any(func(item): return item.id=="library.system.gamegear"),"Empty systems stay hidden")
	menu.select("library.system.snes");await press(JOY_BUTTON_A)
	check(menu.mode=="games" and menu.items.size()==53,"Game list is paged rather than building thousands of rows")
	var visible_in_list := func() -> bool:
		var row = menu.selected_row()
		var view: Rect2 = menu.scroll.get_global_rect()
		return row != null and row.get_global_rect().position.y >= view.position.y - 1 and row.get_global_rect().end.y <= view.end.y + 1
	menu.select(menu.items[1].id); await settle()
	for jump in range(3): await press(JOY_BUTTON_DPAD_RIGHT)
	check(menu.games.game_page==0 and menu.selected_id==menu.items[31].id and visible_in_list.call(),"Right jumps ten games and the list scrolls with the selection")
	for jump in range(2): await press(JOY_BUTTON_DPAD_RIGHT)
	check(menu.games.game_page==1 and visible_in_list.call(),"Jumping onto the next page keeps the selection in view")
	await press(JOY_BUTTON_DPAD_LEFT)
	check(menu.games.game_page==0 and visible_in_list.call(),"Left jumps back across the page and stays in view")
	menu.games.game_page=0;menu.render();await settle()
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(menu.games.game_page==1 and menu.subtitle.text.contains("Page 2 of 2"),"Controller page navigation shows position")
	var selected: String = menu.rows[2].item.id;menu.select(selected);await settle()
	var offset: int = menu.scroll.scroll_vertical
	await press(JOY_BUTTON_B)
	check(menu.mode=="library" and menu.selected_id=="library.system.snes","Back restores originating system selection")
	await press(JOY_BUTTON_A)
	check(menu.mode=="games" and menu.games.game_page==1 and menu.selected_id==selected and menu.scroll.scroll_vertical==offset,"Returning restores game/page/scroll")
	app.apply_console_region("pal"); menu.rom_index.games.snes=titled.games.snes.duplicate(); menu.games.game_page=0; menu.games.shared_titles_cache=[-1,"",{}]; menu.render(); await settle()
	var zelda: Array=menu.items.filter(func(item): return str(item.get("label",""))=="The Legend of Zelda")
	check(zelda.size()==1 and str(zelda[0].detail).begins_with("2 versions"),"Versions of one game share a row")
	check(zelda[0].rom_path.contains("(Europe)"),"A PAL collection plays the European version first")
	var aladdin: Array=menu.items.filter(func(item): return str(item.get("label",""))=="Aladdin")
	check(aladdin.size()==2 and aladdin.any(func(item): return str(item.detail).contains("Bad dump")),"A bad dump stays its own row and says so")
	var midway_row: Array=menu.items.filter(func(item): return str(item.get("label","")).begins_with("1943"))
	check(midway_row.size()==1 and str(midway_row[0].detail).contains("1988 · Shooter"),"Unplayed games show their year and genre")
	# Gran Turismo 2's Arcade and Simulation discs are two games; their revisions are versions.
	var gt2: Array=[]
	for name in ["Gran Turismo 2 (USA) (Arcade Mode) (v1.0).zip","Gran Turismo 2 (USA) (Arcade Mode) (v1.1).zip","Gran Turismo 2 (USA) (Simulation Mode) (v1.0).zip","Gran Turismo 2 (USA) (Simulation Mode) (v1.2).zip"]:
		gt2.append({"path":"/psx/"+name,"label":"Gran Turismo 2"})
	var gt2_rows: Array=menu.games.group_versions(gt2)
	check(gt2_rows.size()==2 and gt2_rows.all(func(row): return row.versions.size()==2),"Arcade and Simulation discs stay separate; each merges its revisions")
	app.library_hide_extras=true; menu.games.list_changed(); await settle()
	check(menu.items.filter(func(item): return str(item.get("label",""))=="Aladdin").size()==1,"Hide betas, demos & hacks leaves out the bad dump")
	app.library_hide_extras=false; app.library_group_versions=false; menu.games.list_changed(); await settle()
	zelda=menu.items.filter(func(item): return str(item.get("label",""))=="The Legend of Zelda")
	check(zelda.size()==2 and zelda.any(func(item): return str(item.detail).begins_with("USA")) and zelda.any(func(item): return str(item.detail).begins_with("Europe")),"Ungrouped, games sharing a title name their region")
	app.library_group_versions=true; menu.games.list_changed(); await settle()
	var grouped: Dictionary=menu.games.game_entries().filter(func(game): return game.label=="The Legend of Zelda")[0]
	menu.games.select_file(grouped.path,grouped.versions); await settle()
	check(menu.mode=="launch" and menu.selected_id=="launch.play" and menu.heading.text=="Choose a version","A game with versions opens the launch page on Play")
	var version_row: Array=menu.items.filter(func(item): return item.id=="launch.version")
	check(version_row.size()==1 and version_row[0].choices==["Europe","USA"],"The version choice names each region")
	menu.games.choose_version(1); await settle()
	check(menu.games.launch_path.contains("(USA)") and menu.selected_id=="launch.version","Choosing a version changes what Play starts")
	menu.back(); await settle()
	menu.search_query="zelda"; check(menu.games.game_entries().size()==1,"Search finds games by clean title")
	menu.search_query="battle midway"; check(menu.games.game_entries().size()==1,"Search matches words in any order")
	menu.search_query=""
	check(menu.games.letter_for(titled.games.snes[3])=="L","The Legend of Zelda jumps under L")
	menu.back();menu.games.refresh_library()
	while menu.rom_index.scanning: await process_frame
	await settle()
	check(menu.rom_index.total()==67,"Refresh discovers current library contents")
	app.distance_save_delay=-1;app.free()
	await process_frame
	print("ROM index checks complete: ",failures," failures")
	quit(1 if failures else 0)
