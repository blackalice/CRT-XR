extends SceneTree
const Index = preload("res://scripts/content/rom_index.gd")
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func settle():
	for i in range(4): await process_frame
func press(menu, button: int):
	var event := InputEventJoypadButton.new(); event.device=7; event.button_index=button; event.pressed=true; menu.handle(event)
	event.pressed=false; menu.handle(event); await settle()
func run():
	var path := ProjectSettings.globalize_path("user://many-consoles")
	for folder in ["snes/Europe","snes/Ports","Nintendo Entertainment System","Genesis","Master System","Game Gear","PS2/deep","n64/collection","saturn","arcade","Handpicked classics"]:
		DirAccess.make_dir_recursive_absolute(path.path_join(folder))
	for file in ["snes/Europe/Adventure.sfc","snes/Ports/Legitimate folder.sfc","Nintendo Entertainment System/Quest.nes","Master System/Runner.sms","Game Gear/Pocket.gg","Handpicked classics/Custom.sfc","PS2/deep/Unrelated.sfc","n64/collection/Unrelated.nes","saturn/Unrelated.sfc","arcade/Unrelated.sms"]:
		var handle := FileAccess.open(path.path_join(file),FileAccess.WRITE); handle.store_8(0); handle.close()
	var handle := FileAccess.open(path.path_join("Genesis/Adventure.md"),FileAccess.WRITE)
	var bytes := PackedByteArray(); bytes.resize(0x110); bytes.encode_u32(0x100,0x41474553); handle.store_buffer(bytes); handle.close()
	var index := Index.new(); index.start(path)
	while index.scanning: index.step()
	check(index.total()==7 and index.ignored_system_folders==4,"Other-console trees are skipped even if they contain supported-looking file names")
	check(not index.visited.has(index.canonical(path.path_join("PS2"))),"Unsupported trees are never opened by the scanner")
	check(index.games.snes.size()==3,"Custom collections and subfolders inside supported systems are retained")
	check(index.games.megadrive.size()==1 and index.games.gamegear.size()==1,"Friendly console aliases resolve through actual ROM detection")
	index.start(path.path_join("PS2"))
	check(not index.scanning and index.message.contains("not supported"),"An unsupported console root offers recovery instead of scanning it")
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); app.use_tracking(false)
	app.default_rom_dir=path; app.choose_rom(); var menu=app.menu
	while menu.rom_index.scanning: await process_frame
	await settle()
	check(menu.items.size()==6 and menu.items.all(func(item): return item.get("layout")=="card") and not menu.items.any(func(item): return item.id in ["library.recent","library.favourites"]),"Home shows five system cards and one locations card; empty shortcuts stay hidden")
	check(not menu.items.any(func(item): return item.id in ["library.drives","library.sd","library.browse"]),"Folder management stays out of the game shelf")
	menu.select("library.system.snes"); await press(menu,JOY_BUTTON_DPAD_UP)
	check(menu.selected_id=="library.system.snes","Grid navigation skips empty quick-access cards and stops at the edge")
	await press(menu,JOY_BUTTON_DPAD_RIGHT)
	check(menu.selected_id=="library.system.nes","Right moves across console cards")
	await press(menu,JOY_BUTTON_DPAD_DOWN)
	check(menu.selected_id=="library.system.mastersystem","Down keeps the same grid column")
	await press(menu,JOY_BUTTON_DPAD_LEFT)
	check(menu.selected_id=="library.system.megadrive","Left selects the adjacent console")
	await press(menu,JOY_BUTTON_A)
	check(menu.mode=="games" and menu.items.size()==1 and menu.rows[0].item.get("layout")=="game","A opens only that console's games with descriptive rows; a short list skips Jump to letter")
	await press(menu,JOY_BUTTON_B)
	check(menu.selected_id=="library.system.megadrive","Back restores the exact console card")
	menu.select("library.locations"); await press(menu,JOY_BUTTON_A)
	check(menu.mode=="library_tools" and menu.items.any(func(item): return item.id=="library.sd"),"Library locations retains SD-card and folder tools")
	await press(menu,JOY_BUTTON_B)
	check(menu.mode=="library" and menu.selected_id=="library.locations","Back restores the locations card")
	menu.select("library.system.snes"); menu.games.refresh_library()
	for i in range(100):
		await process_frame
		if not menu.rom_index.scanning: break
	check(menu.selected_id=="library.system.snes","Rescan restores focus once cards reappear")
	app.free()
	print("LIBRARY CARD CHECKS COMPLETE: ",failures," failures")
	quit(1 if failures else 0)
