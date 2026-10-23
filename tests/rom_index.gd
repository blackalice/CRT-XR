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
	menu.back();menu.games.refresh_library()
	while menu.rom_index.scanning: await process_frame
	await settle()
	check(menu.rom_index.total()==67,"Refresh discovers current library contents")
	app.distance_save_delay=-1;app.free()
	await process_frame
	print("ROM index checks complete: ",failures," failures")
	quit(1 if failures else 0)
