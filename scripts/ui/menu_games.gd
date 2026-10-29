extends RefCounted
## Game pages: the library and its locations, the folder browser, console,
## recent and favourite lists, jump to letter, and choosing a game to play.
const RomIndex = preload("res://scripts/content/rom_index.gd")
const VideoSession = preload("res://scripts/video/video_session.gd")
const FfmpegInstaller = preload("res://scripts/video/ffmpeg_installer.gd")
var host: Node
var menu: Control
## Lists this long or longer offer Jump to letter.
const JUMP_MINIMUM := 20
const GAMES_PER_PAGE := 50
var launch_path := ""
var launch_origin: Dictionary = {}
var library_system := "snes"
var game_page := 0
var system_pages: Dictionary = {}
var alphabet_origin := "games"
var folder_path_origin: Dictionary = {}
var folder_path_music := false

func open_library() -> void:
	menu.remember(); menu.clear_input(); menu.mode="library"; menu.preview=false
	menu.search_query=""; menu.search_field.text=""
	menu.scan_preferred_id=""
	menu.library.default_dir = host.default_rom_dir
	menu.rom_index.start(host.default_rom_dir)
	menu.render()

func open_library_tools() -> void:
	menu.remember(); menu.clear_input(); menu.mode="library_tools"; menu.render()

func library_items() -> Array:
	var h=host
	if menu.rom_index.total()==0:
		var setup: Array = [menu.card(menu.catalog.action("library.setup","Set up your ROM library" if h.default_rom_dir.is_empty() else "Choose a ROM folder",open_library_tools,"Choose your main ROM folder or SD card. Supported games appear here automatically; your files stay where they are."),"CHOOSE A FOLDER TO GET STARTED","locations",menu.MenuSkin.AMBER,"LIBRARY SETUP")]
		if menu.videos.videos_shown(): setup.append(menu.videos.videos_card("LIBRARY SETUP"))
		var resumable: Array=host.video_library.continue_watching(5) if menu.videos.videos_shown() else []
		if not resumable.is_empty(): setup.append(menu.videos.continue_card(resumable.size(),"LIBRARY SETUP"))
		return setup
	var result: Array = []
	# Quick-access shelves appear once they hold something.
	if not h.play_history.recent.is_empty(): result.append(
		menu.card(menu.catalog.action("library.recent","Recently played",func(): open_history("recent"),"Return to your latest games. Unplugged-card entries are kept.",h.play_history.recent.is_empty(),"%d game%s" % [h.play_history.recent.size(),"" if h.play_history.recent.size()==1 else "s"]),"PICK UP & PLAY","recent",menu.MenuSkin.AMBER,"QUICK ACCESS"))
	if not h.play_history.favourites.is_empty(): result.append(
		menu.card(menu.catalog.action("library.favourites","Favourites",func(): open_history("favourites"),"Your favourites across every supported console. Press X on a game to add it.",h.play_history.favourites.is_empty(),"%d game%s" % [h.play_history.favourites.size(),"" if h.play_history.favourites.size()==1 else "s"]),"YOUR PERSONAL SHELF","favourites",Color("dfb984"),"QUICK ACCESS"))
	var watching: Array=host.video_library.continue_watching(5) if menu.videos.videos_shown() else []
	if not watching.is_empty(): result.append(menu.videos.continue_card(watching.size(),"QUICK ACCESS"))
	var identity := {"snes":["NINTENDO · 16-BIT","ba9fdb"],"nes":["NINTENDO · 8-BIT","dc9b8e"],"megadrive":["SEGA · 16-BIT","8ebfdc"],"mastersystem":["SEGA · 8-BIT","9ac4ab"],"gamegear":["SEGA · HANDHELD","d4bb7d"],"gameboy":["NINTENDO · HANDHELD","b7bfa8"],"gba":["NINTENDO · 32-BIT HANDHELD","b0a6e8"],"pcengine":["NEC · 16-BIT","e0908a"],"segacd":["SEGA · CD ADD-ON","7fb6dd"],"atari2600":["ATARI · 8-BIT","e0a75f"],"atarilynx":["ATARI · HANDHELD","cf8560"],"ngpc":["SNK · HANDHELD","c4a8d8"],"vectrex":["GCE · VECTOR","8fc4c9"],"psx":["SONY · 32-BIT CD","a9b6cf"],"n64":["NINTENDO · 64-BIT","8fcf9a"]}
	for system in menu.library.Registry.SYSTEMS:
		var id: String=system
		var count: int=menu.rom_index.games.get(id,[]).size()
		if count==0: continue
		result.append(menu.card(menu.catalog.action("library.system."+id,menu.library.Registry.SYSTEMS[id].get("short",menu.library.Registry.SYSTEMS[id].name),func(): open_system(id),"Open all %s cartridges in your library. Folders for other consoles stay out of this view." % menu.library.Registry.SYSTEMS[id].name,false,"%d game%s" % [count,"" if count==1 else "s"]),identity[id][0],id,Color(identity[id][1]),"YOUR CONSOLES"))
	if menu.videos.videos_shown(): result.append(menu.videos.videos_card("YOUR CONSOLES"))
	if h.default_rom_dir.is_empty():
		result.push_front(menu.card(menu.catalog.action("library.setup","Set up your ROM library",open_library_tools,"Choose the folder containing snes, nes, megadrive and your other systems. Subfolders are included automatically."),"START HERE","locations",menu.MenuSkin.AMBER,"LIBRARY SETUP"))
	var detail := "Choose your main ROM folder" if h.default_rom_dir.is_empty() else "Folders · SD cards · Refresh"
	result.append(menu.card(menu.catalog.action("library.locations","Library locations",open_library_tools,"Set the main roms folder once. CRT XR finds supported consoles and leaves the files where they are.",false,detail),"MAKE YOURSELF AT HOME","locations",Color("aeb6bf"),"YOUR CONSOLES" if menu.rom_index.total()>0 else "LIBRARY"))
	return result

func library_tool_items() -> Array:
	var h=host
	var result: Array=[]
	var rom := "ROM LIBRARY"
	if h.default_rom_dir.is_empty():
		result.append(menu.entry(menu.catalog.action("library.default","Choose your ROM folder",browse_folders,"Browse to the main roms folder (the one containing snes, nes, megadrive and so on), then choose Use this folder.",false,"›"),rom,"folder","primary","Pick it once; every supported console inside is found for you."))
	else:
		var games: int=menu.rom_index.total()
		result.append(menu.entry(menu.catalog.action("library.default","Change ROM folder",browse_folders,"Pick a different main ROM folder. Your files stay where they are.",false,"›"),rom,"folder","",menu.short_path(h.default_rom_dir)+(" · "+menu.count_caption(games,"game") if games>0 else "")))
		result.append(menu.entry(menu.catalog.action("library.refresh","Refresh library",refresh_library,"Rescans the ROM folder for added or removed games.",false,""),rom,"refresh"))
		result.append(menu.entry(menu.catalog.action("library.clear","Forget ROM folder",func(): set_default(""),"Forget the folder without changing any files.",false,""),rom,"clear","danger"))
	var videos := "VIDEOS · OPTIONAL"
	if not VideoSession.available(): result.append_array(menu.videos.video_setup_items(videos))
	else:
		if h.video_dir.is_empty():
			result.append(menu.entry(menu.catalog.action("library.video_folder","Choose a video folder",menu.videos.open_video_folder_picker,"Optional. Pick a folder of MP4 or MKV files to watch on the TV; they appear after your consoles.",false,"›"),videos,"video","","MP4 and MKV files, shown after your consoles"))
		else:
			var count: int=h.video_library.count(h.video_dir)
			result.append(menu.entry(menu.catalog.action("library.video_folder","Change video folder",menu.videos.open_video_folder_picker,"Pick a different video folder. Your files stay where they are.",false,"›"),videos,"video","",menu.short_path(h.video_dir)+" · "+menu.count_caption(count,"video")))
			result.append(menu.entry(menu.catalog.action("library.video_clear","Remove video folder",func(): menu.videos.set_video_folder(""),"Hides Videos from the library. Your files are not changed.",false,""),videos,"clear","danger"))
		if FfmpegInstaller.installed():
			result.append(menu.entry(menu.catalog.action("library.ffmpeg_remove","Remove downloaded video libraries",func():
				menu.ask("Remove the video libraries?","Videos stop playing until you set them up again. The files go when CRT XR next starts.",func(): FfmpegInstaller.remove(); menu.notify("Video libraries will be removed when CRT XR restarts.")),
				"Frees the FFmpeg libraries CRT XR downloaded. Your videos are not touched.",false,""),videos,"clear","danger","",true))
	var find := "FIND A FOLDER"
	for candidate in menu.library.Locations.library_candidates(menu.library.home_folder(),menu.library.Locations.sd_cards()):
		var path: String=candidate
		result.append(menu.entry(menu.catalog.action("library.detected:"+path,"Found a ROM folder",func(): open_folder(path),"Open this detected library, then choose Use this folder for my library.",false,"›"),find,"search","",path))
	result.append(menu.entry(menu.catalog.action("library.browse","Browse this computer",browse_folders,"Start from your ROM folder, or your home folder.",false,""),find,"folder","","",true))
	result.append(menu.entry(menu.catalog.action("library.sd","SD card",open_cards,"Browse a mounted Steam Deck SD card.",false,""),find,"sd","","",true))
	if OS.get_name()=="Windows": result.append(menu.entry(menu.catalog.action("library.drives","Computer drives",open_drives,"Choose a drive, then browse to your ROM folder.",false,""),find,"drive","","",true))
	result.append(menu.entry(menu.catalog.action("library.path","Type a folder or network path…",enter_folder_path,"Enter a drive folder or a network share path; Windows handles sign-in.",false,""),find,"network","","",true))
	return result

func browser_items() -> Array:
	var here: String = menu.library.current_dir
	var result: Array=[menu.entry(menu.catalog.action("folder.remember","Use this folder for my library",func():
		set_default(here)
		if host.default_rom_dir==here: open_library(),"Every supported console in this folder and its subfolders becomes your library. Choose the parent ROM folder, not one console's folder.",false,""),menu.SECTION_HERE,"check","primary","Finds games for every console in here and its subfolders")]
	result.append_array(menu.up_entry("folder.up",here,open_folder))
	for item in menu.library.entries:
		var path: String=item.path
		if item.folder:
			var console: String=str(item.system)
			result.append(menu.entry(menu.catalog.action("file:"+path,item.label,func(): open_folder(path),path,false,console if not console.is_empty() else "›"),menu.SECTION_INSIDE,"folder"))
		else:
			result.append(menu.entry(menu.catalog.action("file:"+path,item.label,func(): select_file(path),path,false,str(item.get("system","Game"))),menu.SECTION_INSIDE,"cartridge"))
	if menu.library.entries.is_empty():
		result.append(menu.entry(menu.catalog.unavailable(menu.catalog.action("folder.empty","No folders or games here",func(): pass,"",true),"Go up, or pick another place below."),menu.SECTION_INSIDE))
	return result+menu.place_entries("folder",open_folder,enter_folder_path)

func refresh_library() -> void:
	var previous: String = menu.selected_id
	menu.remember(); menu.clear_input(); menu.error_label.hide()
	menu.rom_index.start(host.default_rom_dir)
	menu.scan_preferred_id=previous if menu.mode=="library" else ""
	menu.render()

func open_system(system: String) -> void:
	menu.remember(); menu.clear_input(); menu.search_query=""; menu.search_field.text=""
	library_system=system; game_page=int(system_pages.get(system,0))
	var count: int = menu.rom_index.games.get(system,[]).size()
	game_page=clampi(game_page,0,maxi(0,(count-1)/GAMES_PER_PAGE))
	menu.mode="games"; menu.render()

func change_game_page(delta: int) -> void:
	var count: int = game_entries().size()
	var next := clampi(game_page+delta,0,maxi(0,(count-1)/GAMES_PER_PAGE))
	if next==game_page: return
	menu.remember(); menu.clear_input(); game_page=next; system_pages[library_system]=game_page
	menu.render()

func open_folder(path: String) -> void:
	menu.remember(); menu.clear_input()
	if not menu.library.show_folder(path): menu.show_error(menu.library.message); return
	menu.error_label.hide()
	menu.mode="browser"; menu.render()

func open_drives() -> void:
	menu.remember(); menu.clear_input(); menu.mode="drives"; menu.render()

func enter_folder_path(for_music := false) -> void:
	menu.remember(); folder_path_origin=menu.snapshot(); folder_path_music=for_music
	menu.clear_input(); menu.mode="folder_path"; menu.render()
	menu.rename_field.text=menu.music.music_dir if for_music else menu.library.current_dir
	menu.keys.focus_entry(); menu.rename_field.select_all()

func submit_folder_path() -> void:
	var path: String = menu.library.Locations.normalize_windows_path(menu.rename_field.text) if OS.get_name()=="Windows" else menu.rename_field.text.strip_edges()
	if path.is_empty(): menu.show_error("Enter a folder path, such as D:/roms or //server/share/roms."); return
	if DirAccess.open(path)==null:
		menu.show_error("Cannot open this folder. Check the path, drive or network connection. For a network share, connect and sign in through Windows File Explorer first.")
		return
	if folder_path_music:
		var origin: Dictionary = menu.music.music_origin.duplicate()
		menu.music.open_music_browser(path)
		menu.music.music_origin=origin
	else: open_folder(path)

func browse_folders() -> void:
	var candidates := [menu.library.current_dir,host.default_rom_dir,host.last_game_path.get_base_dir(),menu.library.home_folder()]
	for path in candidates:
		if not str(path).is_empty() and DirAccess.open(path)!=null:
			open_folder(path); return
	menu.show_error("No available folder could be opened.")

func open_default() -> void:
	if host.default_rom_dir.is_empty(): menu.show_error("No default folder yet. Browse to your ROM folder and press R1.")
	else: open_folder(host.default_rom_dir)

func open_cards() -> void:
	var paths: Array = menu.library.cards()
	if paths.is_empty(): menu.show_error("No SD card is mounted. Insert the card, then try again.")
	elif paths.size()==1: open_folder(paths[0])
	else: menu.remember(); menu.clear_input(); menu.mode="volumes"; menu.render()

func set_default(path: String) -> void:
	if not path.is_empty() and DirAccess.open(path)==null:
		menu.show_error("Open an available folder before setting a default."); return
	var previous: String = host.default_rom_dir
	host.default_rom_dir = path
	if host.save_library()!=OK:
		host.default_rom_dir = previous
		menu.show_error("Default folder could not be saved. Check that user storage is writable.")
		return
	menu.library.default_dir = path
	menu.rom_index.start(path)
	menu.notify("ROM library folder saved. Choose game shows systems after scanning." if not path.is_empty() else "Default folder cleared; your ROMs are unchanged")

func select_file(path: String) -> void:
	if not FileAccess.file_exists(path): menu.show_error("Game unavailable. Reconnect its SD card and try again."); return
	var automatic: String = host.emulator.auto_path_for(path)
	if FileAccess.file_exists(automatic):
		menu.remember(); launch_origin=menu.snapshot(); launch_path=path
		menu.clear_input(); menu.mode="launch"; menu.render()
	else: launch_game(path,false)

func launch_game(path: String, continuing: bool) -> void:
	# A zipped disc is hundreds of megabytes: unpack it in the background while
	# the room keeps tracking, then start it.
	if host.emulator.needs_unpacking(path): unpack_then_launch(path, continuing); return
	if not host.load_game(path): menu.show_error(host.startup_message); return
	if continuing and not host.emulator.load_auto():
		if not menu.visible: host.toggle_settings() # after an unpack the menu is closed
		menu.show_error(host.emulator.status+" Select Start fresh to play without this save.")
		return
	var feedback: String = host.emulator.status
	host.was_paused_before_menu=false
	host.close_settings()
	if continuing: host.show_notice(feedback)

## Back to the room while the disc unpacks: the TV shows the loading card and its
## progress, then the game boots behind it.
func unpack_then_launch(path: String, continuing: bool) -> void:
	var emulator: Node = host.emulator
	if not emulator.unpacking.is_empty() and emulator.unpacking != path:
		menu.show_error("Another disc is still being unpacked. Try again when it is ready."); return
	if not host.stop_for_disc(path): menu.show_error(emulator.status); return
	emulator.unpack_disc(path)
	if not emulator.unpack_progress.is_connected(show_unpack_progress): emulator.unpack_progress.connect(show_unpack_progress)
	# One launch per unpack: a second choice of the same game replaces the first.
	for connection in emulator.unpack_finished.get_connections(): emulator.unpack_finished.disconnect(connection.callable)
	emulator.unpack_finished.connect(func(finished: String, error: String):
		# Something else was chosen meanwhile: the disc is ready for next time.
		if finished != path or host.loading_path != path: return
		if not error.is_empty():
			host.end_loading()
			if not menu.visible: host.toggle_settings()
			menu.show_error("Could not unpack %s: %s" % [path.get_file().get_basename(), error]); return
		launch_game(path, continuing),
		CONNECT_ONE_SHOT)
	host.was_paused_before_menu = false
	host.close_settings()

func show_unpack_progress(path: String, done: int, total: int) -> void:
	host.update_loading(path, float(done) / maxi(total, 1))

func open_history(which: String) -> void:
	menu.remember(); menu.clear_input(); menu.search_query=""; menu.search_field.text=""; menu.mode=which; menu.render()

func game_item(path: String, label: String) -> Dictionary:
	var item: Dictionary = menu.catalog.action("game:"+path,label,func(): select_file(path),"Open this cartridge or mark it as a favourite.",false,"★" if path in host.play_history.favourites else "›")
	item["rom_path"]=path
	item["layout"]="game"
	var folder := path.get_base_dir().get_file()
	var parts: Array[String]=[]
	# A console's own list already names the console; mixed lists need it.
	if menu.mode!="games":
		var system: String=menu.library.Registry.identify(path)
		if system.is_empty(): system=RomIndex.Folders.system(folder)
		parts.append(menu.library.Registry.SYSTEMS[system].name if not system.is_empty() else "Game")
	if not FileAccess.file_exists(path): parts.append("Storage unavailable")
	elif RomIndex.Folders.system(folder).is_empty(): parts.append(folder)
	var played: int=host.play_history.last_played(path)
	if played>0: parts.append("Played "+menu.ago(played))
	item["detail"]=" · ".join(parts)
	with_box_art(item,path)
	return item

## Shows a game's box art in its row, when the player's scrapes have some.
func with_box_art(item: Dictionary, rom_path: String) -> Dictionary:
	host.box_art.set_root(host.default_rom_dir)
	if host.box_art.find(rom_path).is_empty(): return item
	item["thumbnail_path"]=rom_path; item["thumbnail"]=host.box_art.texture(rom_path)
	item["thumbnail_icon"]="cartridge"; item["thumbnail_size"]=Vector2(56,64)
	return item

func toggle_favourite() -> void:
	var row = menu.selected_row()
	if row==null or not row.item.has("rom_path"): return
	if not host.play_history.toggle(row.item.rom_path):
		menu.show_error("Favourite could not be saved. Check user-folder permissions."); return
	menu.refresh(); menu.notify("Favourites updated")

func game_entries() -> Array:
	var games: Array=menu.rom_index.games.get(library_system,[])
	if menu.search_query.is_empty(): return games
	return games.filter(func(game): return str(game.label).to_lower().contains(menu.search_query.to_lower()))

func history_paths() -> Array:
	var paths: Array=host.play_history.recent if menu.mode=="recent" else host.play_history.favourites
	if menu.search_query.is_empty(): return paths
	return paths.filter(func(path): return str(path).get_file().get_basename().to_lower().contains(menu.search_query.to_lower()))

func open_alphabet() -> void:
	if menu.mode not in ["games","recent","favourites"]: return
	menu.remember(); menu.clear_input(); alphabet_origin=menu.mode; menu.mode="alphabet"; menu.render()

func alphabet_entries() -> Array:
	if alphabet_origin=="games": return game_entries()
	var paths: Array=host.play_history.recent if alphabet_origin=="recent" else host.play_history.favourites
	var result: Array=[]
	for path in paths:
		var label: String=str(path).get_file().get_basename()
		if label.to_lower().contains(menu.search_query.to_lower()): result.append({"path":path,"label":label})
	return result

func letter_for(label: String) -> String:
	var letter:=label.left(1).to_upper()
	return letter if letter>="A" and letter<="Z" else "#"

func jump_to_letter(letter: String) -> void:
	var entries:=alphabet_entries()
	for i in range(entries.size()):
		if letter_for(str(entries[i].label))!=letter: continue
		menu.remember(); menu.clear_input(); menu.mode=alphabet_origin
		if menu.mode=="games": game_page=i/GAMES_PER_PAGE; system_pages[library_system]=game_page
		menu.selected_id="game:"+str(entries[i].path)
		menu.memory[menu.state_key()]={"id":menu.selected_id}
		menu.render(); return

func game_title_action() -> void:
	if not menu.search_query.is_empty():
		menu.search_field.text=""; menu.update_search(""); return
	var row=menu.selected_row()
	if row!=null and row.item.has("rom_path"):
		menu.open_help("Full game title",str(row.item.label))

## Continue from the automatic save, or start the game fresh.
func launch_items() -> Array:
	var path := launch_path
	return [menu.catalog.action("launch.continue","Continue",func(): launch_game(path,true),path.get_file().get_basename()+" · resume point saved "+menu.ago(host.emulator.state_stamp(host.emulator.auto_path_for(path)))),
		menu.catalog.action("launch.fresh","Start fresh",func(): launch_game(path,false),"Start from the title screen. Cartridge battery saves and manual states are kept."),
		menu.catalog.action("launch.cancel","Back",menu.back,"Return without starting this game.")]

## Recently played or favourites, with Jump to letter on long lists.
func history_items() -> Array:
	var paths: Array = history_paths()
	var result: Array = [menu.catalog.action("games.jump","Jump to letter…",open_alphabet,"Jump to a game with the controller.",paths.is_empty())] if paths.size() > JUMP_MINIMUM else []
	for path in paths: result.append(game_item(path,path.get_file().get_basename()))
	return result

## One console's games, a page at a time.
func console_items() -> Array:
	var listed: Array = game_entries()
	var result: Array = [menu.catalog.action("games.jump","Jump to letter…",open_alphabet,"Jump to a game with the controller.",listed.is_empty())] if listed.size() > JUMP_MINIMUM else []
	for game in listed.slice(game_page*GAMES_PER_PAGE,(game_page+1)*GAMES_PER_PAGE):
		var path: String = game.path
		result.append(game_item(path,game.label))
	if listed.size()>GAMES_PER_PAGE:
		result.append(menu.catalog.action("games.previous","Previous page",func(): change_game_page(-1),"Also available with L1. Left/right jumps ten games.",game_page==0))
		result.append(menu.catalog.action("games.next","Next page",func(): change_game_page(1),"Also available with R1. Left/right jumps ten games.",(game_page+1)*GAMES_PER_PAGE>=listed.size()))
	return result

## A grid of letters; those with no games are greyed out.
func letter_items() -> Array:
	var result: Array=[]
	var available: Dictionary={}
	for game in alphabet_entries(): available[letter_for(str(game.label))]=true
	for letter in ["#","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]:
		var chosen: String=letter
		var item: Dictionary=menu.catalog.action("letter."+chosen,chosen,func(): jump_to_letter(chosen),"Jump to the first matching game.",not available.has(chosen))
		item.layout="letter"; result.append(item)
	return result

func drive_items() -> Array:
	var result: Array = []
	for drive in menu.library.Locations.computer_drives():
		var path: String = drive
		result.append(menu.entry(menu.catalog.action("drive:"+path,"Drive "+path.trim_suffix("/"),func(): open_folder(path),"Browse this drive.",false,"›"),"DRIVES","drive"))
	result.append(menu.entry(menu.catalog.action("drives.path","Type a folder or network path…",enter_folder_path,"Use a network share such as //server/share/roms, or enter a drive path.",false,""),menu.SECTION_PLACES,"network","","",true))
	return result

func volume_items() -> Array:
	var result: Array = []
	for path in menu.library.cards():
		var location: String = path
		result.append(menu.entry(menu.catalog.action("volume:"+location,location.get_file(),func(): open_folder(location),location,false,"›"),"SD CARDS","sd"))
	return result
