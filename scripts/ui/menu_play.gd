extends RefCounted
## While a game is loaded: save-state slots, loading, and the reset button.
const Platform = preload("res://scripts/platform/platform.gd")
var host: Node
var menu: Control
## Save-state slots per game.
const STATE_SLOTS := 4
## The save-state page: choosing a slot saves (true) or loads (false).
var states_saving := true

func open_states(saving: bool) -> void:
	if not host.emulator.loaded: return
	menu.remember(); menu.clear_input(); states_saving=saving; menu.mode="states"; menu.render()

## The save-state slots, each with its picture and when it was saved.
func state_items() -> Array:
	var result: Array=[]
	for i in range(STATE_SLOTS):
		var slot: int=i
		var path: String=host.emulator.state_path(slot)
		var saved: bool=FileAccess.file_exists(path)
		var help: String=("Replaces this save with the game as it is now." if saved else "Saves the game as it is now.") if states_saving else ("Returns to this point. Progress since then is lost." if saved else "Nothing is saved here yet.")
		var item: Dictionary=menu.entry(menu.catalog.action("state.%d" % slot,"Slot %d" % (slot+1),func(): choose_state(slot),help,not states_saving and not saved,""),"","","","Saved "+menu.ago(host.emulator.state_stamp(path)) if saved else "Empty")
		item["thumbnail_path"]=path; item["thumbnail_icon"]="save"; item["thumbnail_size"]=Vector2(64,48); item["thumbnail"]=state_picture(path)
		result.append(item)
	return result

static func state_picture(path: String) -> Texture2D:
	var details: Dictionary=preload("res://scripts/emulation/emulation_session.gd").state_details(path)
	if not details.get("thumbnail") is PackedByteArray: return null
	var image := Image.new()
	return ImageTexture.create_from_image(image) if image.load_png_from_buffer(details.thumbnail)==OK else null

func choose_state(slot: int) -> void:
	var path: String=host.emulator.state_path(slot)
	var game: String=host.emulator.rom_path.get_file().get_basename()
	if states_saving:
		if FileAccess.file_exists(path): menu.ask("Overwrite slot %d?" % (slot+1),"Replace the save for %s from %s?" % [game,menu.ago(host.emulator.state_stamp(path))],func(): perform_state_action(true,slot),path)
		else: perform_state_action(true,slot)
	elif FileAccess.file_exists(path):
		menu.ask("Load slot %d?" % (slot+1),"Return to %s as saved %s. Progress since then is lost." % [game,menu.ago(host.emulator.state_stamp(path))],func(): perform_state_action(false,slot),path)

## Step-by-step help for glasses on this platform, in the help page markup
## (scripts/ui/help_article.gd).
func glasses_guide() -> String:
	if Platform.is_windows():
		return "\n".join([
			"## Starting in 3D",
			"1. Switch the glasses to their side-by-side (SBS) mode before starting CRT XR.",
			"2. On your normal monitor, choose the glasses' display and select Open glasses view.",
			"## Head tracking",
			"- VITURE: put the VITURE Windows SDK in a folder named sdk beside CRT-XR.exe.",
			"- Other glasses: use a tool that sends OpenTrack, such as opentrack, PhoenixHeadTracker (XREAL) or VertoXR (Rokid, RayNeo), then choose Controls & XR → Tracking source → OpenTrack.",
			"## While playing",
			"R3 | R :: Recentre the view",
			"> Turning the wrong way? Invert that axis in Controls & XR.",
			"!! Fixed view",
			"There's no tracking yet, so the TV stays still. It's also how CRT XR plays on a normal screen."])
	return "\n".join([
		"## Before you start",
		"Install Decky Loader and its XR Gaming plugin, and check XR Gaming recognises your glasses. CRT XR uses its head tracking.",
		"## Starting in 3D",
		"1. Connect the glasses in 2D and start CRT XR from Gaming Mode.",
		"2. Put them on and press their SBS button. Nothing else to press.",
		"3. The view goes dark as they switch, and your room appears by itself.",
		"> Glasses the XR driver can switch go into SBS by themselves, and back to 2D when you leave.",
		"## Leaving",
		"1. Choose Exit. The TV switches off.",
		"2. Press the glasses' SBS button to go back to 2D. CRT XR closes when they do.",
		"## While playing",
		"R3 :: Recentre the view",
		"> Turning the wrong way? Invert that axis in Controls & XR.",
		"## Your glasses",
		"CRT XR recognises VITURE, XREAL, Rokid and RayNeo displays. Only the VITURE Pro 2 has been tested.",
		"!! Fixed view",
		"There's no tracking yet, so the TV stays still. Check XR Gaming sees the glasses, then use Controls & XR → Connect glasses."])

func state_action(saving: bool) -> void:
	if not saving:
		if not FileAccess.file_exists(host.emulator.state_path()):
			menu.show_error("No manual save yet. Choose Save state first."); return
		menu.ask("Load manual save?","Current progress will be replaced. %s • Slot 1 • saved %s" % [host.emulator.rom_path.get_file().get_basename(),menu.ago(host.emulator.state_stamp(host.emulator.state_path()))],func(): perform_state_action(false),host.emulator.state_path())
		return
	if FileAccess.file_exists(host.emulator.state_path()):
		menu.ask("Overwrite manual save?", "Replace the save for %s from %s?" % [host.emulator.rom_path.get_file().get_basename(),menu.ago(host.emulator.state_stamp(host.emulator.state_path()))],func(): perform_state_action(true),host.emulator.state_path())
	else: perform_state_action(true)

func reset_game() -> void:
	menu.ask("Reset the game?","Restarts %s as if you pressed the console's reset button. Progress since your last save is lost; battery saves and save states are kept." % host.emulator.rom_path.get_file().get_basename(),func():
		if host.emulator.reset_game(): host.close_settings(); host.show_notice(host.emulator.status)
		else: menu.show_error(host.emulator.status))

func perform_state_action(saving: bool, slot := 0) -> void:
	var succeeded: bool = host.emulator.save_state(slot) if saving else host.emulator.load_state(slot)
	if succeeded:
		host.show_notice(host.emulator.status)
		# A loaded save is where you want to be: back to the game.
		if not saving and menu.mode=="states": host.close_settings(); return
		menu.notify(host.emulator.status)
	else: menu.show_error(host.emulator.status+". Check the save folder and available storage.")
	menu.refresh()

## The home menu, before a game is loaded: your last game, the library and music.
func home_items() -> Array:
	var h=host
	var home: Array = []
	var tiles: Array = [
		menu.tile(menu.catalog.action("home.quick","Quick settings",func(): menu.category=7; menu.subsection=0; menu.open_settings(),"TV position, recenter, picture preset and volumes."),"sliders"),
		menu.tile(menu.catalog.action("home.settings","Settings",menu.open_settings,"Adjust the view, picture, audio and room."),"gear"),
		menu.tile(menu.catalog.action("home.exit","Exit",func(): menu.ask("Exit CRT XR?","Your settings will be saved.",h.request_exit),"Close CRT XR."),"exit","danger")]
	var library_row: Dictionary = menu.catalog.action("home.library","Set up library" if h.default_rom_dir.is_empty() else "Game library",menu.games.open_library,"Choose your main ROM folder or SD card. Your supported games appear automatically." if h.default_rom_dir.is_empty() else "Recent, Favourites and supported consoles.",false,"›")
	if not h.last_game_path.is_empty() and FileAccess.file_exists(h.last_game_path):
		# The last game leads, with what it is and when it was played.
		var parts: Array[String] = ["Continue"]
		var system: String = menu.library.Registry.identify(h.last_game_path)
		if not system.is_empty(): parts.append(menu.library.Registry.SYSTEMS[system].name)
		var played: int = h.play_history.last_played(h.last_game_path)
		if played > 0: parts.append("played " + menu.ago(played))
		home.append(menu.games.with_box_art(menu.entry(menu.catalog.action("home.continue",h.last_game_path.get_file().get_basename(),func(): menu.games.select_file(h.last_game_path),"Open your last cartridge and its automatic resume point, when available.",false,"›"),"","play","primary"," · ".join(parts)),h.last_game_path))
		tiles.insert(0,menu.tile(library_row,"cartridge"))
	else:
		home.append(menu.entry(library_row,"","folder" if h.default_rom_dir.is_empty() else "cartridge","primary" if h.default_rom_dir.is_empty() else ""))
		if h.default_rom_dir.is_empty(): tiles.insert(0,menu.tile(menu.catalog.action("home.glasses","Using glasses",func(): menu.open_help("Using glasses",glasses_guide()),"How to connect glasses, start in side-by-side 3D and recentre."),"glasses"))
	return home+menu.music.music_actions()+[menu.room_choice("pause.room")]+tiles

## The pause menu while a game is loaded: Resume leads, actions sit in tiles.
func pause_items() -> Array:
	var h=host
	var resume: Dictionary = menu.entry(menu.catalog.action("resume","Resume",h.close_settings,"Return to the game with your settings saved.",not h.emulator.loaded,""),"","play")
	resume["hero"] = true
	var result: Array = [resume]
	result.append_array(menu.music.music_actions())
	result.append(menu.room_choice("pause.room"))
	result.append_array([
		menu.tile(menu.catalog.unavailable(menu.catalog.action("save_state","Save state",func(): open_states(true),"Choose one of %d slots for this game." % STATE_SLOTS,not h.emulator.loaded),"Start a game first."),"save"),
		menu.tile(menu.catalog.unavailable(menu.catalog.action("load_state","Load state",func(): open_states(false),"Return to one of this game's saves.",not h.emulator.loaded or range(STATE_SLOTS).all(func(slot): return not FileAccess.file_exists(h.emulator.state_path(slot)))),"No saved state yet."),"load"),
		menu.tile(menu.catalog.action("reset_game","Reset game",reset_game,"Presses the console's reset button. Battery saves and save states are kept.",not h.emulator.loaded),"refresh"),
		menu.tile(menu.catalog.action("screenshot","Screenshot",h.take_screenshot,"Saves a clean single-eye image without menus or diagnostics."),"camera"),
		menu.tile(menu.catalog.action("games","Choose game",menu.games.open_library,"Open your recent game, default ROM folder or SD card."),"cartridge"),
		menu.tile(menu.catalog.action("quick","Quick settings",func(): menu.category=7; menu.subsection=0; menu.open_settings(),"Everyday picture, placement and volume controls."),"sliders"),
		menu.tile(menu.catalog.action("settings","Settings",menu.open_settings,"Adjust the view, picture, room, controls and saved setups."),"gear"),
		menu.tile(menu.catalog.action("exit","Exit CRT XR",func(): menu.ask("Exit CRT XR?","An automatic resume point, settings and cartridge SRAM will be saved.",h.request_exit),"Close the application."),"exit","danger")])
	return result
