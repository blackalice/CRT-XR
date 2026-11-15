extends RefCounted
## Game pages: the library and its locations, the folder browser, console,
## recent, most played and favourite lists, jump to letter, and choosing a game to play.
const RomIndex = preload("res://scripts/content/rom_index.gd")
const History = preload("res://scripts/content/play_history.gd")
const GameTitle = preload("res://scripts/content/game_title.gd")
const VideoSession = preload("res://scripts/video/video_session.gd")
const FfmpegInstaller = preload("res://scripts/video/ffmpeg_installer.gd")
var host: Node
var menu: Control
## Lists this long or longer offer Jump to letter.
const JUMP_MINIMUM := 20
const GAMES_PER_PAGE := 50
var launch_path := ""
var launch_origin: Dictionary = {}
## A newer choice supersedes any launch still waiting for the channel animation.
var launch_generation := 0
var library_system := "snes"
var game_page := 0
var system_pages: Dictionary = {}
var alphabet_origin := "games"
var folder_path_origin: Dictionary = {}
var folder_path_music := false
## Titles that more than one game in a console's list shares, so those rows name
## their region or revision: [index revision, system, {title: true}].
var shared_titles_cache: Array = [-1, "", {}]
## The versions of the game on the launch page, when it has more than one.
var launch_versions: Array = []
## A console's list after grouping and hiding: [key, entries].
var console_cache: Array = ["", []]
## Tags that "Hide betas, demos & hacks" leaves out. Translations stay.
const EXTRAS := ["Beta","Prototype","Demo","Sample","Kiosk","Debug","Promo","Hack","Bad dump","Overdump","Bad checksum","BIOS"]
## Regions each console collection plays first when a game has several versions.
const REGION_PREFERENCE := {"pal":["Europe","UK","Australia","Germany","France","Spain","Italy","Netherlands","Sweden","Scandinavia","PAL"],
	"ntsc":["USA","Canada","NTSC"],"japan":["Japan"]}

func open_library() -> void:
	menu.remember(); menu.clear_input(); menu.mode="library"; menu.preview=false
	menu.search_query=""; menu.search_field.text=""
	menu.scan_preferred_id=""
	menu.library.default_dir = host.default_rom_dir
	menu.rom_index.start(host.default_rom_dir)
	menu.render()
	if host.library_box_art_auto: auto_box_art.call_deferred()

## With automatic box art on: once a session, after the scan, fetch what's missing.
var auto_box_art_done := false
func auto_box_art() -> void:
	if auto_box_art_done or not host.library_box_art_auto: return
	while menu.rom_index.scanning:
		await menu.get_tree().create_timer(1.0).timeout
	if auto_box_art_done or box_art_fetcher().running: return
	auto_box_art_done = true
	if missing_box_art() > 0: download_box_art(true)

## Library games without art that the collection could match (cached per scan).
var missing_cache := [-1, 0]
func missing_box_art() -> int:
	if missing_cache[0] == menu.rom_index.revision and not box_art_fetcher().running: return missing_cache[1]
	var count := box_art_candidates().size()
	missing_cache = [menu.rom_index.revision, count]
	return count

func open_library_tools() -> void:
	menu.remember(); menu.clear_input(); menu.mode="library_tools"; menu.render()

func library_items() -> Array:
	var h=host
	if menu.rom_index.total()==0:
		var setup: Array = [menu.card(menu.catalog.action("library.setup","Set up your ROM library" if h.default_rom_dir.is_empty() else "Choose a ROM folder",open_library_tools,"Choose your ROM folder or SD card. Supported games are found automatically."),"CHOOSE A FOLDER TO GET STARTED","locations",menu.MenuSkin.AMBER,"LIBRARY SETUP")]
		# Free demo games, until your own library has some: separate from your ROMs.
		var DemoShelf = preload("res://scripts/content/demo_shelf.gd")
		if not menu.rom_index.scanning:
			for game in DemoShelf.games():
				var path: String = game.path
				var spec: Dictionary = menu.library.Registry.SYSTEMS[game.system]
				setup.append(menu.card(menu.catalog.action("library.demo:"+path,str(game.title),func(): select_file(path),
					"A free game included with CRT XR to try the TV with. " + DemoShelf.credit(game) + ". It goes away once your own games are set up.",false,str(spec.get("short",spec.name))),
					"TRY A DEMO",spec.get("icon",game.system),Color("9fd3c7"),"TRY THE TV"))
		return setup
	var result: Array = []
	# Quick-access shelves appear once they hold something.
	if not h.play_history.recent.is_empty(): result.append(
		menu.card(menu.catalog.action("library.recent","Recently played",func(): open_history("recent"),"Return to your latest games. Unplugged-card entries are kept.",h.play_history.recent.is_empty(),"%d game%s" % [h.play_history.recent.size(),"" if h.play_history.recent.size()==1 else "s"]),"PICK UP & PLAY","recent",menu.MenuSkin.AMBER,"QUICK ACCESS"))
	var most: Array[String] = h.play_history.most_played()
	if not most.is_empty(): result.append(
		menu.card(menu.catalog.action("library.most_played","Most played",func(): open_history("most_played"),"The games you've spent longest with. Only time spent playing counts, not menus or pauses.",false,"%d game%s" % [most.size(),"" if most.size()==1 else "s"]),"YOUR ALL-TIME TOP","most_played",menu.MenuSkin.AMBER,"QUICK ACCESS"))
	if not h.play_history.favourites.is_empty(): result.append(
		menu.card(menu.catalog.action("library.favourites","Favourites",func(): open_history("favourites"),"Your favourites across every supported console. Press {X} on a game to add it.",h.play_history.favourites.is_empty(),"%d game%s" % [h.play_history.favourites.size(),"" if h.play_history.favourites.size()==1 else "s"]),"YOUR PERSONAL SHELF","favourites",Color("dfb984"),"QUICK ACCESS"))
	var identity := {"snes":["NINTENDO · 16-BIT","ba9fdb"],"nes":["NINTENDO · 8-BIT","dc9b8e"],"megadrive":["SEGA · 16-BIT","8ebfdc"],"mastersystem":["SEGA · 8-BIT","9ac4ab"],"gamegear":["SEGA · HANDHELD","d4bb7d"],"gameboy":["NINTENDO · HANDHELD","b7bfa8"],"gba":["NINTENDO · 32-BIT HANDHELD","b0a6e8"],"pcengine":["NEC · 16-BIT","e0908a"],"segacd":["SEGA · CD ADD-ON","7fb6dd"],"atari2600":["ATARI · 8-BIT","e0a75f"],"atarilynx":["ATARI · HANDHELD","cf8560"],"ngpc":["SNK · HANDHELD","c4a8d8"],"vectrex":["GCE · VECTOR","8fc4c9"],"psx":["SONY · 32-BIT CD","a9b6cf"],"n64":["NINTENDO · 64-BIT","8fcf9a"],"dreamcast":["SEGA · 128-BIT","c3cbd9"],"gamecube":["NINTENDO · GAMECUBE","b0a6e8"],"wii":["NINTENDO · WII","c9d3dc"],"ps2":["SONY · 128-BIT DVD","8fa3d6"],"psp":["SONY · HANDHELD","b4b8c4"]}
	for system in menu.library.Registry.SYSTEMS:
		var id: String=system
		var count: int=console_games(id).size()
		if count==0: continue
		result.append(menu.card(menu.catalog.action("library.system."+id,menu.library.Registry.SYSTEMS[id].name,func(): open_system(id),"",false,"%d game%s" % [count,"" if count==1 else "s"]),identity.get(id,["CONSOLE","c3cbd9"])[0],menu.library.Registry.SYSTEMS[id].get("icon",id),Color(identity.get(id,["CONSOLE","c3cbd9"])[1]),"YOUR CONSOLES"))
	if h.default_rom_dir.is_empty():
		result.push_front(menu.card(menu.catalog.action("library.setup","Set up your ROM library",open_library_tools,"Choose the folder containing snes, nes, megadrive and your other systems. Subfolders are included automatically."),"START HERE","locations",menu.MenuSkin.AMBER,"LIBRARY SETUP"))
	var detail := "Choose your main ROM folder" if h.default_rom_dir.is_empty() else "Folders · SD cards · Refresh"
	result.append(menu.card(menu.catalog.action("library.locations","Library locations",open_library_tools,"Choose your main ROM folder.",false,detail),"MAKE YOURSELF AT HOME","locations",Color("aeb6bf"),"YOUR CONSOLES" if menu.rom_index.total()>0 else "LIBRARY"))
	# Box art: one press to fill in covers for games your scrapes don't cover.
	if menu.rom_index.total() > 0 and not menu.rom_index.scanning:
		var fetch = box_art_fetcher()
		var missing: int = missing_box_art()
		if fetch.running or missing > 0:
			result.append(menu.card(menu.catalog.action("library.get_boxart","Stop box art download" if fetch.running else "Get box art",
				(func(): fetch.cancel(); menu.refresh()) if fetch.running else func(): download_box_art(),
				"Downloads front covers from the free libretro-thumbnails collection for games without art. Kept in CRT XR's own folder; your ROM folders aren't touched.",false,
				("%d of %d" % [fetch.done, fetch.total]) if fetch.running else ("%d without art" % missing)),"COVERS FOR YOUR SHELF","search",Color("dfb984"),"YOUR CONSOLES"))
	# A random pick, like flicking through the shelf, beside Library locations.
	if menu.rom_index.total() > 1: result.append(
		menu.card(menu.catalog.action("library.random","Surprise me",surprise,"Picks a game at random from your whole library.",false,"›"),"CAN'T DECIDE?","refresh",Color("9fd3c7"),"YOUR CONSOLES"))
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
	if menu.rom_index.total() > 0:
		var art := "BOX ART"
		var fetch = box_art_fetcher()
		var busy: bool = fetch.running
		result.append(menu.entry(menu.catalog.action("library.boxart","Stop downloading box art" if busy else "Download missing box art",(func(): fetch.cancel(); menu.refresh()) if busy else download_box_art,
			"For games your own scrapes don't cover, fetches front covers from the free libretro-thumbnails collection, matched by game name. They're kept in CRT XR's own folder; your ROM folders aren't touched. Needs an internet connection.",false,
			("%d of %d" % [fetch.done, fetch.total]) if busy else ""),art,"search"))
		result.append(menu.entry(menu.catalog.action("library.boxart_settings","Box art and list settings",func(): menu.open_settings_section(10, "Library"),
			"Show or hide box art, download it automatically, choose list columns and which games are listed.",false,"›"),art,"gear"))
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
		var for_setup: bool = menu.welcome.choosing=="library"
		if not set_default(here): return
		if for_setup: menu.welcome.library_chosen()
		elif host.default_rom_dir==here: open_library(),"Every supported console in this folder and its subfolders becomes your library. Choose the parent ROM folder, not one console's folder.",false,""),menu.SECTION_HERE,"check","primary","Finds games for every console in here and its subfolders")]
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

## A random game from the whole library (versions grouped as the lists show them).
func surprise() -> void:
	var pool: Array = []
	for system in menu.library.Registry.SYSTEMS:
		pool.append_array(console_games(system))
	if pool.is_empty(): return
	var game: Dictionary = pool[randi() % pool.size()]
	menu.notify("Tonight's pick: " + str(game.get("label", str(game.path).get_file())))
	select_file(str(game.path), game.get("versions", []))

func box_art_fetcher():
	if not host.has_node("BoxArtFetch"):
		var fetch = preload("res://scripts/content/box_art_fetch.gd").new()
		fetch.name = "BoxArtFetch"
		host.add_child(fetch)
		fetch.progress.connect(func(done: int, total: int, _found: int):
			if done % 10 == 0 and menu.mode == "library_tools": menu.refresh())
		fetch.finished.connect(func(found: int, missing: int):
			host.box_art.refresh()
			missing_cache = [-1, 0]
			var tail := ""
			match str(fetch.stopped):
				"limit": tail = " · more next time (the download is spread over a few sessions)"
				"busy": tail = " · the server is busy, so the rest will wait: try again later"
				_: tail = (" · %d not in the collection" % missing) if missing > 0 else ""
			host.show_notice("Box art: %d downloaded%s" % [found, tail])
			if menu.visible: menu.refresh())
	return host.get_node("BoxArtFetch")

## Every library game without art whose name the collection can match:
## [system, path, name, console folder].
func box_art_candidates(include_missing := false) -> Array:
	var games: Array = []
	for system in menu.library.Registry.SYSTEMS:
		for game in menu.rom_index.games.get(system, []):
			var path := str(game.path)
			if not host.box_art.find(path).is_empty(): continue
			if not include_missing and box_art_fetcher().known_missing(path): continue
			var identified: String = menu.rom_index.identity.name_for(system, path) if game.get("identified", false) else ""
			var names: Array = box_art_fetcher().names_for(path.get_file(), identified)
			# A name with no region is unlikely to be in the collection.
			names = names.filter(func(name): return str(name).contains("("))
			if names.is_empty(): continue
			games.append([system, path, names, host.box_art.console_folder(path)])
	return games

func download_box_art(quiet := false, retry := false) -> void:
	var queued: int = box_art_fetcher().start(box_art_candidates(retry), retry)
	missing_cache = [-1, 0]
	if quiet and queued == 0: return
	menu.notify(("Downloading box art for %s…" % menu.count_caption(queued, "game")) if queued > 0 else "Every game the collection can match already has box art.")
	menu.refresh()

func refresh_library() -> void:
	var previous: String = menu.selected_id
	menu.remember(); menu.clear_input(); menu.error_label.hide()
	menu.rom_index.start(host.default_rom_dir)
	menu.scan_preferred_id=previous if menu.mode=="library" else ""
	menu.render()

func open_system(system: String) -> void:
	menu.remember(); menu.clear_input(); menu.search_query=""; menu.search_field.text=""
	library_system=system; game_page=int(system_pages.get(system,0))
	console_cache=["",[]] # The version last played may have changed since.
	var count: int = console_games(system).size()
	game_page=clampi(game_page,0,maxi(0,(count-1)/GAMES_PER_PAGE))
	menu.mode="games"; menu.render()

func change_game_page(delta: int) -> void:
	var count: int = game_entries().size()
	var next := clampi(game_page+delta,0,maxi(0,(count-1)/GAMES_PER_PAGE))
	if next==game_page: return
	menu.remember(); menu.clear_input(); game_page=next; system_pages[library_system]=game_page
	menu.render()
	menu.play_navigation_click()

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
	if host.default_rom_dir.is_empty(): menu.show_error("No default folder yet. Browse to your ROM folder and press {R1}.")
	else: open_folder(host.default_rom_dir)

func open_cards() -> void:
	var paths: Array = menu.library.cards()
	if paths.is_empty(): menu.show_error("No SD card is mounted. Insert the card, then try again.")
	elif paths.size()==1: open_folder(paths[0])
	else: menu.remember(); menu.clear_input(); menu.mode="volumes"; menu.render()

func set_default(path: String) -> bool:
	if not path.is_empty() and DirAccess.open(path)==null:
		menu.show_error("Open an available folder before setting a default."); return false
	var previous: String = host.default_rom_dir
	host.default_rom_dir = path
	if host.save_library()!=OK:
		host.default_rom_dir = previous
		menu.show_error("Default folder could not be saved. Check that user storage is writable.")
		return false
	menu.library.default_dir = path
	menu.rom_index.start(path)
	menu.notify("ROM library folder saved. Choose game shows systems after scanning." if not path.is_empty() else "Default folder cleared; your ROMs are unchanged")
	return true

## Plays a game, or first offers Continue and, for a game with several versions,
## which one to play.
func select_file(path: String, versions: Array = []) -> void:
	if not FileAccess.file_exists(path): menu.show_error("Game unavailable. Reconnect its SD card and try again."); return
	launch_versions = versions if versions.size()>1 else []
	var automatic: String = host.emulator.auto_path_for(path)
	if FileAccess.file_exists(automatic) or not launch_versions.is_empty():
		menu.remember(); launch_origin=menu.snapshot(); launch_path=path
		menu.clear_input(); menu.mode="launch"; menu.memory["launch"]={"id":"launch.continue" if FileAccess.file_exists(automatic) else "launch.play","scroll":0}; menu.render()
	else: launch_game(path,false)

func launch_game(path: String, continuing: bool) -> void:
	launch_generation += 1
	var generation := launch_generation
	# A zipped disc is hundreds of megabytes: unpack it in the background while
	# the room keeps tracking, then start it.
	if host.emulator.needs_unpacking(path): unpack_then_launch(path, continuing); return
	# Draw one loading card before the background save/unload/boot sequence.
	# The same card owns the complete transition to the selected game.
	if host.shows_loading_card(path):
		# Card first, drawn, and only then the old game's resume save and stop (a
		# disc game's state is large): the playing game stays paused behind the menu.
		host.show_loading(path, 0.0)
		host.was_paused_before_menu = true
		host.video_was_paused_before_menu = true
		if not host.close_settings(): host.end_loading(); return
		for i in range(3): await host.get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		# Keep the short channel cue before changing consoles; the work below
		# runs in the background while the room continues to update.
		await host.get_tree().create_timer(0.55).timeout
		if generation != launch_generation or host.loading_path != path: return
		while host.loading_game or host.emulator.get("transition_busy") == true: await host.get_tree().process_frame
		if generation != launch_generation or host.loading_path != path: return
		var stopped: bool = await host.stop_for_disc(path, true)
		if generation != launch_generation: return
		if not stopped:
			host.end_loading()
			if not menu.visible: host.toggle_settings()
			menu.show_error(host.emulator.status); return
	while host.loading_game or host.emulator.get("transition_busy") == true: await host.get_tree().process_frame
	if generation != launch_generation: return
	var opened: bool = await host.load_game_async(path, host.shows_loading_card(path))
	if generation != launch_generation: return
	if not opened: menu.show_error(host.startup_message); return
	if continuing:
		host.loading_game = true
		var resumed: bool = await host.emulator.load_auto_async()
		host.loading_game = false
		if generation != launch_generation: return
		if not resumed:
			host.end_loading()
			if not menu.visible: host.toggle_settings()
			menu.show_error(host.emulator.status + " Choose Start from a fresh boot to play without this resume point.")
			return
		host.resume_ready(path)
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
	host.show_loading(path, 0.0)
	host.was_paused_before_menu = true
	if not host.close_settings(): host.end_loading(); return
	if not await host.stop_for_disc(path, true): menu.show_error(emulator.status); return
	if host.loading_path != path: return
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
			menu.show_error("Could not unpack %s: %s" % [GameTitle.of(path), error]); return
		launch_game(path, continuing),
		CONNECT_ONE_SHOT)
	host.was_paused_before_menu = false
	host.close_settings()

func show_unpack_progress(path: String, done: int, total: int) -> void:
	host.update_loading(path, float(done) / maxi(total, 1))

func open_history(which: String) -> void:
	menu.remember(); menu.clear_input(); menu.search_query=""; menu.search_field.text=""; menu.mode=which; menu.render()

## One game's row. `shared` lists titles other games in this list also use: those
## rows add their region or revision ("Europe · Rev 1") so they can be told apart.
func game_item(path: String, label: String, shared: Dictionary = {}, versions: Array = []) -> Dictionary:
	var favourite: bool = path in host.play_history.favourites
	var item: Dictionary = menu.catalog.action("game:"+path,label,func(): select_file(path,versions),"Open this cartridge or mark it as a favourite.",false,"" if favourite else "›")
	if favourite: item["value_icon"]="heart"
	item["rom_path"]=path
	item["layout"]="game"
	var folder := path.get_base_dir().get_file()
	var parts: Array[String]=[]
	# A console's own list already names the console; mixed lists need it.
	if menu.mode!="games":
		var system: String=menu.library.Registry.identify(path)
		if system.is_empty(): system=RomIndex.Folders.system(folder)
		parts.append(menu.library.Registry.SYSTEMS[system].name if not system.is_empty() else "Game")
	var named: Dictionary = GameTitle.info(path)
	if versions.size()>1: parts.append("%d versions" % versions.size())
	elif shared.has(title_key(label,path)) and not str(named.variant).is_empty(): parts.append(str(named.variant))
	parts.append_array(named.tags)
	if not FileAccess.file_exists(path): parts.append("Storage unavailable")
	elif RomIndex.Folders.system(folder).is_empty(): parts.append(folder)
	var total := play_label(path)
	if not total.is_empty(): parts.append(total)
	var played: int=host.play_history.last_played(path)
	if played>0: parts.append(("last " if not total.is_empty() else "Played ")+menu.ago(played))
	elif total.is_empty():
		# Not played yet: what its gamelist or TOSEC name says about it.
		if str(named.get("year","")).is_valid_int(): parts.append(str(named.year))
		var kind := str(named.get("genre",named.get("publisher","")))
		if not kind.is_empty(): parts.append(kind)
	item["detail"]=" · ".join(parts)
	# Covers get a fixed, generous slot sized to the list's columns; a game
	# without art keeps the slot, showing its console, so titles line up.
	var cover_size: Vector2 = {1: Vector2(112, 84), 2: Vector2(92, 84), 3: Vector2(64, 72)}.get(clampi(host.game_list_columns, 1, 3), Vector2(92, 84))
	with_box_art(item, path, cover_size)
	item["help"]="{A} plays it, {Y} shows its cover and details, {X} makes it a favourite."
	return item

## A game's total play time, "3h 20m played", or empty under a minute.
func play_label(path: String) -> String:
	var total := History.duration(host.play_history.play_time(path))
	return "" if total.is_empty() else total + " played"

## Shows a game's box art in its row, when the player's scrapes have some.
## A row's cover: the same recessed slot everywhere (game lists, Continue,
## Recent), holding the box art, or the console when there is none.
func with_box_art(item: Dictionary, rom_path: String, size := Vector2(72,64)) -> Dictionary:
	if not host.library_box_art: return item
	host.box_art.set_root(host.default_rom_dir)
	item["thumbnail_path"]=rom_path; item["thumbnail_size"]=size; item["thumbnail_well"]=true
	item["thumbnail_console"]=console_icon(rom_path)
	item["thumbnail"]=host.box_art.texture(rom_path) if not host.box_art.find(rom_path).is_empty() else null
	return item

## The console icon for a game, for covers that have no art.
func console_icon(rom_path: String) -> String:
	var system: String = menu.library.Registry.identify(rom_path)
	if system.is_empty(): system = RomIndex.Folders.system(rom_path.get_base_dir().get_file())
	if system.is_empty(): system = library_system
	return str(menu.library.Registry.SYSTEMS.get(system, {}).get("icon", system))

## A large cover for a page (game info, starting a game): the large front
## cover when there is one, else the list art, else the console.
func cover_panel(rom_path: String, size: Vector2) -> Control:
	var well := Panel.new(); well.custom_minimum_size=size; well.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	well.add_theme_stylebox_override("panel",menu.MenuSkin.box(Color(0.02,0.04,0.12,0.8),Color(0.45,0.55,0.85,0.45),2,0))
	well.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var glyph = preload("res://scripts/ui/console_glyph.gd").new()
	glyph.kind=console_icon(rom_path); glyph.size=Vector2(96,96); glyph.position=(size-Vector2(96,96))*0.5
	glyph.modulate=Color(1,1,1,0.5); glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE; well.add_child(glyph)
	var picture := TextureRect.new(); picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; picture.position=Vector2(6,6); picture.size=size-Vector2(12,12)
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE; well.add_child(picture)
	var show := func(texture: Texture2D):
		if texture == null or not is_instance_valid(picture): return
		picture.texture=texture; glyph.visible=false
	if host.library_box_art:
		host.box_art.set_root(host.default_rom_dir)
		var big: Texture2D = host.box_art.cover(rom_path)
		if big != null: show.call(big)
		else:
			var small: Texture2D = host.box_art.texture(rom_path) if not host.box_art.find(rom_path).is_empty() else null
			if small != null: show.call(small)
			var arrived := func(path: String, texture: Texture2D, large: bool):
				if path == rom_path and (large or picture.texture == null): show.call(texture)
			var on_cover := func(path, texture): arrived.call(path, texture, true)
			var on_art := func(path, texture): arrived.call(path, texture, false)
			host.box_art.cover_ready.connect(on_cover)
			host.box_art.art_ready.connect(on_art)
			# The page is rebuilt often: stop listening when this cover goes.
			well.tree_exiting.connect(func():
				if host.box_art.cover_ready.is_connected(on_cover): host.box_art.cover_ready.disconnect(on_cover)
				if host.box_art.art_ready.is_connected(on_art): host.box_art.art_ready.disconnect(on_art))
	return well

func toggle_favourite() -> void:
	var row = menu.selected_row()
	if row==null or not row.item.has("rom_path"): return
	if not host.play_history.toggle(row.item.rom_path):
		menu.show_error("Favourite could not be saved. Check user-folder permissions."); return
	menu.refresh(); menu.notify("Favourites updated")

func game_entries() -> Array:
	var games: Array=console_games(library_system)
	if menu.search_query.is_empty(): return games
	return games.filter(func(game): return GameTitle.matches(menu.search_query,str(game.path),str(game.label)))

## The paths of a quick-access list: "recent", "favourites" or "most_played".
func shelf(which: String) -> Array:
	match which:
		"recent": return host.play_history.recent
		"most_played": return host.play_history.most_played()
	return host.play_history.favourites

func history_paths() -> Array:
	var paths: Array=shelf(menu.mode)
	if menu.search_query.is_empty(): return paths
	return paths.filter(func(path): return GameTitle.matches(menu.search_query,str(path)))

func open_alphabet() -> void:
	if menu.mode not in ["games","recent","favourites","most_played"]: return
	menu.remember(); menu.clear_input(); alphabet_origin=menu.mode; menu.mode="alphabet"; menu.render()

func alphabet_entries() -> Array:
	if alphabet_origin=="games": return game_entries()
	var paths: Array=shelf(alphabet_origin)
	var result: Array=[]
	for path in paths:
		if GameTitle.matches(menu.search_query,str(path)): result.append({"path":path,"label":GameTitle.of(path),"sort":GameTitle.info(path).sort})
	return result

## A game's Jump to letter heading: "The Legend of Zelda" is under L.
func letter_for(game: Dictionary) -> String:
	return GameTitle.letter(str(game.get("sort",GameTitle.sort_key(str(game.label)))))

## A title with its tags: a bad dump or Disc 2 is already told apart by its tag.
func title_key(label: String, path: String) -> String:
	return label+"|"+",".join(GameTitle.info(path).tags)

## Titles (with tags) used by more than one of these games.
func shared_titles(entries: Array) -> Dictionary:
	var seen: Dictionary={}
	var shared: Dictionary={}
	for game in entries:
		var title: String=title_key(str(game.label),str(game.path))
		if seen.has(title): shared[title]=true
		seen[title]=true
	return shared

func jump_to_letter(letter: String) -> void:
	var entries:=alphabet_entries()
	for i in range(entries.size()):
		if letter_for(entries[i])!=letter: continue
		menu.remember(); menu.clear_input(); menu.mode=alphabet_origin
		if menu.mode=="games": game_page=i/GAMES_PER_PAGE; system_pages[library_system]=game_page
		menu.selected_id="game:"+str(entries[i].path)
		menu.memory[menu.state_key()]={"id":menu.selected_id}
		menu.render(); return

func game_title_action() -> void:
	if not menu.search_query.is_empty():
		menu.search_field.text=""; menu.update_search(""); return
	var row=menu.selected_row()
	if row!=null and row.item.has("rom_path"): open_info(str(row.item.rom_path), row.item.get("versions", []), str(row.item.label))

# ── A game's page: its cover, details and description (Y on a game) ─────────

var info_path := ""
var info_versions: Array = []
## The name the list showed (gamelist or identified name), used as the page's title.
var info_label := ""
var info_origin: Dictionary = {}
var info_online: Dictionary = {}
var info_status := ""

func info_source():
	if not host.has_node("GameInfo"):
		var source = preload("res://scripts/content/game_info.gd").new()
		source.name = "GameInfo"
		host.add_child(source)
		source.looked_up.connect(func(path: String, result: Dictionary):
			if path != info_path: return
			info_online = result if not result.has("error") else {}
			info_status = str(result.get("error", ""))
			if menu.mode == "game_info": menu.render())
	return host.get_node("GameInfo")

func open_info(path: String, versions: Array = [], label := "") -> void:
	menu.remember(); info_origin = menu.snapshot()
	info_path = path; info_versions = versions; info_status = ""
	info_label = label if not label.is_empty() else GameTitle.of(path)
	info_online = preload("res://scripts/content/game_info.gd").cached(path)
	menu.clear_input(); menu.mode = "game_info"; menu.render()
	if info_online.is_empty() and host.library_info_online and local_info().get("description", "").is_empty(): look_up_info()

var local_cache := ["", {}]
func local_info() -> Dictionary:
	if local_cache[0] != info_path:
		local_cache = [info_path, preload("res://scripts/content/game_info.gd").from_gamelist(info_path, host.default_rom_dir)]
	return local_cache[1]

## Words that tell same-named articles apart: the console's names.
func console_words(path: String) -> Array:
	var system: String = menu.library.Registry.identify(path)
	if system.is_empty(): system = RomIndex.Folders.system(path.get_base_dir().get_file())
	var spec: Dictionary = menu.library.Registry.SYSTEMS.get(system, {})
	var words: Array = [str(spec.get("name", "")), str(spec.get("short", ""))]
	words.append_array({"snes": ["Super Nintendo", "Super NES"], "nes": ["Nintendo Entertainment System"], "megadrive": ["Mega Drive", "Genesis"],
		"psx": ["PlayStation"], "n64": ["Nintendo 64"], "gameboy": ["Game Boy"], "gba": ["Game Boy Advance"], "pcengine": ["TurboGrafx", "PC Engine"],
		"mastersystem": ["Master System"], "gamegear": ["Game Gear"], "segacd": ["Sega CD", "Mega-CD"]}.get(system, []))
	return words.filter(func(word): return not str(word).is_empty())

func look_up_info() -> void:
	info_status = "Looking it up on Wikipedia…"
	info_source().look_up(info_path, str(GameTitle.parse(info_label + ".x").title) if not info_label.is_empty() else GameTitle.of(info_path), console_words(info_path))
	if menu.mode == "game_info": menu.render()

func info_items() -> Array:
	var c = menu.catalog
	var path := info_path
	var result: Array = []
	# Side by side under the facts, so the description below stays in view.
	var play: Dictionary = menu.tile(c.action("game_info.play", "Play", func(): select_file(path, info_versions), "", not FileAccess.file_exists(path), ""), "play", "primary", "info", 3)
	result.append(play)
	var favourite: bool = path in host.play_history.favourites
	result.append(menu.tile(c.action("game_info.favourite", "Unfavourite" if favourite else "Favourite", func():
		if not host.play_history.toggle(path): menu.show_error("Favourite could not be saved. Check user-folder permissions."); return
		menu.render(), "", false, ""), "heart", "", "info", 3))
	var has_text: bool = not str(local_info().get("description", "")).is_empty() or not info_online.is_empty()
	if not has_text:
		result.append(menu.tile(c.action("game_info.lookup", "Describe it", look_up_info,
			"Finds this game's Wikipedia article and keeps a short summary here. Only the game's name is sent. Turn on automatic look-ups in Games › Library.", info_source().busy == path, ""), "search", "", "info", 3))
	return result

## Up to `limit` characters, ending at a sentence where one fits, else a word, with "…".
static func short_text(text: String, limit: int) -> String:
	var clean := text.strip_edges().replace("\n", " ")
	if clean.length() <= limit: return clean
	var cut := clean.left(limit)
	var stop := cut.rfind(". ")
	if stop > limit / 2: return cut.left(stop + 1)
	var space := cut.rfind(" ")
	return cut.left(space if space > 0 else limit).strip_edges() + "…"

func info_heading() -> String:
	return info_label

func info_subtitle() -> String:
	var system: String = menu.library.Registry.identify(info_path)
	if system.is_empty(): system = RomIndex.Folders.system(info_path.get_base_dir().get_file())
	return str(menu.library.Registry.SYSTEMS.get(system, {}).get("name", "Game"))

## The page around its buttons: cover and facts side by side, then the description.
func decorate_info(column: VBoxContainer) -> void:
	var path := info_path
	var named: Dictionary = GameTitle.info(path)
	var local := local_info()
	var hero := HBoxContainer.new(); hero.add_theme_constant_override("separation", 22)
	hero.add_child(cover_panel(path, Vector2(200, 228)))
	var facts := VBoxContainer.new(); facts.add_theme_constant_override("separation", 6); facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lines: Array = []
	var variant := str(named.get("variant", ""))
	if not variant.is_empty(): lines.append(["Version", variant])
	for pair in [["year", "Released"], ["genre", "Genre"], ["players", "Players"], ["developer", "Developer"], ["publisher", "Publisher"]]:
		var value := str(local.get(pair[0], named.get(pair[0], "")))
		if not value.is_empty(): lines.append([pair[1], value])
	var played := play_label(path)
	if not played.is_empty(): lines.append(["Played", played.trim_suffix(" played")])
	var last: int = host.play_history.last_played(path)
	if last > 0: lines.append(["Last played", menu.ago(last)])
	if info_versions.size() > 1: lines.append(["Versions", str(info_versions.size())])
	if lines.size() < 6: lines.append(["File", path.get_file()])
	for line in lines:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
		var key := Label.new(); key.text = line[0]; key.custom_minimum_size.x = 130
		key.add_theme_font_size_override("font_size", 17 + (2 if host.menu_large_text else 0)); key.add_theme_color_override("font_color", menu.MenuSkin.MUTED)
		var value := Label.new(); value.text = line[1]; value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# One line each, trimmed: a wrapping label beside another shrinks to nothing.
		value.autowrap_mode = TextServer.AUTOWRAP_OFF; value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; value.clip_text = true
		value.add_theme_font_size_override("font_size", 18 + (2 if host.menu_large_text else 0))
		row.add_child(key); row.add_child(value); facts.add_child(row)
	hero.add_child(facts)
	# Play, Favourite and Look up sit under the facts, beside the cover.
	var gap := Control.new(); gap.custom_minimum_size.y = 6; facts.add_child(gap)
	if not menu.rows.is_empty():
		var tiles: Control = menu.rows[0].get_parent()
		tiles.get_parent().remove_child(tiles); facts.add_child(tiles)
	var top: Array[Control] = [hero]
	# A long name is trimmed in the heading: the page spells it out in full.
	var full := info_label
	if full.length() > 26:
		var whole := Label.new(); whole.text = full; whole.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		whole.add_theme_font_size_override("font_size", 22 + (3 if host.menu_large_text else 0))
		menu.MenuSkin.weigh(whole, menu.MenuSkin.SEMIBOLD); menu.MenuSkin.shadow(whole)
		top.push_front(whole)
	# The description: from your gamelist, else from Wikipedia when looked up.
	var text := str(local.get("description", ""))
	var source := "From your gamelist" if not text.is_empty() else ""
	if text.is_empty() and not info_online.is_empty():
		text = str(info_online.get("description", ""))
		source = "From Wikipedia, “%s” · CC BY-SA" % str(info_online.get("title", ""))
	if not text.is_empty() or not info_status.is_empty():
		var about := Label.new(); about.text = text if not text.is_empty() else info_status
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Trimmed by hand at a sentence: a wrapping Label with an overrun mode
		# measured itself empty on long Wikipedia summaries.
		if not text.is_empty(): about.text = short_text(text, 300 if host.menu_large_text else 400)
		about.add_theme_font_size_override("font_size", 19 + (3 if host.menu_large_text else 0))
		about.add_theme_color_override("font_color", menu.MenuSkin.TEXT if not text.is_empty() else menu.MenuSkin.MUTED)
		var box := PanelContainer.new(); box.add_theme_stylebox_override("panel", menu.MenuSkin.box(Color("0b1a48"), Color("3858a0"), 2, 14))
		var inner := VBoxContainer.new(); inner.add_theme_constant_override("separation", 6); box.add_child(inner)
		inner.add_child(about)
		if not source.is_empty():
			var credit := Label.new(); credit.text = source; credit.add_theme_font_size_override("font_size", 14); credit.add_theme_color_override("font_color", menu.MenuSkin.MUTED)
			credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inner.add_child(credit)
		top.append(box)
	for i in range(top.size()):
		column.add_child(top[i]); column.move_child(top[i], i)

## Name the actual return destination: startup has no preceding page to go back to.
func launch_return_label() -> String:
	match launch_origin.get("mode", "pause"):
		"pause": return "Go to Home" if not host.emulator.loaded and not host.video.loaded else "Back to menu"
		"recent": return "Back to Recently played"
		"favourites": return "Back to Favourites"
		"most_played": return "Back to Most played"
		"browser": return "Back to folders"
		"games", "library": return "Back to library"
	return "Back"

func launch_items() -> Array:
	var path := launch_path
	var result: Array = []
	if has_resume(path):
		var continuing: Dictionary = menu.catalog.action("launch.continue","Continue",func(): launch_game(path,true),"",false,"")
		continuing["emphasis"] = "primary"
		continuing["row_icon"] = "play"
		continuing["min_height"] = 84
		var fresh: Dictionary = menu.catalog.action("launch.fresh","Start from a fresh boot",func(): launch_game(path,false),"In-game saves are kept.",false,"")
		fresh["detail_getter"] = func(): return "In-game saves are kept."
		result.append_array([continuing, fresh])
	else:
		var play: Dictionary = menu.catalog.action("launch.play","Play",func(): launch_game(path,false),"",false,"")
		play["emphasis"] = "primary"; play["row_icon"] = "play"; play["min_height"] = 84
		result.append(play)
	if launch_versions.size()>1:
		var names := version_names(launch_versions)
		result.append({"id":"launch.version","label":"Version","kind":"choice","choices":names,"default":0,"visual":false,
			"getter":func(): return maxi(0,launch_versions.find(launch_path)),
			"setter":func(value): choose_version(int(value)),
			"help":"Each version keeps its own saves and resume point."})
	result.append(menu.catalog.action("launch.cancel",launch_return_label(),menu.back,"",false,""))
	return result

## The launch page switches to another version of the game.
func choose_version(index: int) -> void:
	launch_path=launch_versions[clampi(index,0,launch_versions.size()-1)]
	menu.selected_id="launch.version"
	menu.refresh()

## True when the game has an automatic resume point to continue from.
func has_resume(path: String) -> bool:
	return FileAccess.file_exists(host.emulator.auto_path_for(path))

## How each version is told apart: its region and revision, then any tags,
## or its file name when those say nothing new.
func version_names(paths: Array) -> Array:
	var names: Array = []
	for path in paths:
		var named: Dictionary = GameTitle.info(path)
		var parts: Array = [] if str(named.variant).is_empty() else [str(named.variant)]
		parts.append_array(named.tags)
		names.append(" · ".join(parts))
	var labels: Array = names.duplicate()
	for i in range(names.size()):
		if str(names[i]).is_empty() or names.count(names[i])>1: labels[i]=str(paths[i]).get_file()
	return labels

## Recently played, most played or favourites, with Jump to letter on long lists.
func history_items() -> Array:
	var paths: Array = history_paths()
	var result: Array = [menu.catalog.action("games.jump","Jump to letter…",open_alphabet,"Jump to a game with the controller.",paths.is_empty())] if paths.size() > JUMP_MINIMUM else []
	var shared := shared_titles(paths.map(func(path): return {"label":GameTitle.of(path),"path":path}))
	for path in paths: result.append(game_item(path,GameTitle.of(path),shared))
	return result

## One console's games, a page at a time.
func console_items() -> Array:
	var listed: Array = game_entries()
	var result: Array = [menu.catalog.action("games.jump","Jump to letter…",open_alphabet,"Jump to a game with the controller.",listed.is_empty())] if listed.size() > JUMP_MINIMUM else []
	# Across the whole console, so a clash on the next page still names its region.
	if shared_titles_cache[0]!=menu.rom_index.revision or shared_titles_cache[1]!=library_system or menu.rom_index.scanning:
		shared_titles_cache=[menu.rom_index.revision,library_system,shared_titles(console_games(library_system))]
	for game in listed.slice(game_page*GAMES_PER_PAGE,(game_page+1)*GAMES_PER_PAGE):
		var path: String = game.path
		result.append(game_item(path,game.label,shared_titles_cache[2],game.get("versions",[])))
	if listed.size()>GAMES_PER_PAGE:
		result.append(menu.catalog.action("games.previous","Previous page",func(): change_game_page(-1),"Also available with {L1}. {←→} jumps ten games.",game_page==0))
		result.append(menu.catalog.action("games.next","Next page",func(): change_game_page(1),"Also available with {R1}. {←→} jumps ten games.",(game_page+1)*GAMES_PER_PAGE>=listed.size()))
	return result

## A grid of letters; those with no games are greyed out.
func letter_items() -> Array:
	var result: Array=[]
	var available: Dictionary={}
	for game in alphabet_entries(): available[letter_for(game)]=true
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

## A console's games as its list shows them: hidden extras left out, and versions
## of one game in one row that plays the preferred version.
func console_games(system: String) -> Array:
	var games: Array = menu.rom_index.games.get(system,[])
	var group: bool = host.library_group_versions
	var hide: bool = host.library_hide_extras
	if not group and not hide: return games
	# The list itself is in the key too: tests and refreshes replace it outright.
	var ends: String = "" if games.is_empty() else str(games[0].path)+str(games[-1].path)
	var key := "%d|%s|%s|%s|%s|%d|%s" % [menu.rom_index.revision,system,group,hide,host.console_region,games.size(),ends]
	if console_cache[0]==key: return console_cache[1]
	var shown: Array = games.filter(func(game): return not hide or not is_extra(str(game.path)))
	if group: shown = group_versions(shown)
	console_cache=[key,shown]
	return shown

## Betas, prototypes, demos, hacks and bad dumps.
func is_extra(path: String) -> bool:
	for tag in GameTitle.info(path).tags:
		if tag in EXTRAS or tag.get_slice(" ",0) in EXTRAS: return true
	return false

## One entry per title and tags (so Disc 2 and a hack stay their own rows),
## in list order, with its versions when there are several.
func group_versions(games: Array) -> Array:
	var groups: Dictionary = {}
	var order: Array = []
	for game in games:
		var named: Dictionary = GameTitle.info(str(game.path))
		var tags: Array = Array(named.tags).filter(func(tag): return tag!="Alternate" and tag!="Fixed")
		var key: String = str(game.label)+"|"+",".join(tags)
		if not groups.has(key):
			groups[key]=[]; order.append(key)
		groups[key].append(game)
	var result: Array = []
	for key in order:
		var members: Array = groups[key]
		if members.size()==1:
			result.append(members[0]); continue
		var paths: Array = members.map(func(game): return str(game.path))
		var entry: Dictionary = members[paths.find(preferred_version(paths))].duplicate()
		entry["versions"]=paths
		result.append(entry)
	return result

## The version you last played; otherwise your region's, then World; among
## equals the last in the list, usually the latest revision.
func preferred_version(paths: Array) -> String:
	var best := ""
	var best_played := 0
	for path in paths:
		var played: int = host.play_history.last_played(path)
		if played>best_played:
			best=path; best_played=played
	if not best.is_empty(): return best
	var wanted: Array = REGION_PREFERENCE.get(host.console_region,[])
	var best_score := -1
	for path in paths:
		var score := 0
		for region in GameTitle.info(path).get("regions",[]):
			if region in wanted: score=maxi(score,2)
			elif region=="World": score=maxi(score,1)
		if score>=best_score:
			best=path; best_score=score
	return best

## The letters a page of a console's list covers, such as "D-F".
func page_letters() -> String:
	var page := game_entries().slice(game_page*GAMES_PER_PAGE,(game_page+1)*GAMES_PER_PAGE)
	if page.is_empty(): return ""
	var first := letter_for(page[0])
	var last := letter_for(page[-1])
	return first if first==last else first+"-"+last

## A library setting changed: rebuild the lists it shapes.
func list_changed() -> void:
	console_cache=["",[]]; shared_titles_cache=[-1,"",{}]
	menu.refresh()
