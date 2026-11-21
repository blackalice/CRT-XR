extends RefCounted
## While a game is loaded: save-state slots, loading, and the reset button.
const GameTitle = preload("res://scripts/content/game_title.gd")
const PlayHistory = preload("res://scripts/content/play_history.gd")
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
		if saved: menu.state_previews.request(path)
		var help: String=("Replaces this save with the game as it is now." if saved else "Saves the game as it is now.") if states_saving else ("Returns to this point. Progress since then is lost." if saved else "Nothing is saved here yet.")
		var item: Dictionary=menu.entry(menu.catalog.action("state.%d" % slot,"Slot %d" % (slot+1),func(): choose_state(slot),help,not states_saving and not saved,""),"","","","Saved "+menu.saved_when(host.emulator.state_stamp(path)) if saved else "Empty")
		item["thumbnail_path"]=path; item["thumbnail_icon"]="save"; item["thumbnail_size"]=Vector2(64,48); item["thumbnail"]=state_picture(path)
		result.append(item)
	return result

static func state_picture(path: String) -> Texture2D:
	var details: Dictionary=preload("res://scripts/emulation/emulation_session.gd").state_metadata(path)
	if not details.get("thumbnail") is PackedByteArray: return null
	var image := Image.new()
	return ImageTexture.create_from_image(image) if image.load_png_from_buffer(details.thumbnail)==OK else null

func choose_state(slot: int) -> void:
	var path: String=host.emulator.state_path(slot)
	var game: String=GameTitle.of(host.emulator.rom_path)
	if states_saving:
		if FileAccess.file_exists(path): menu.ask("Overwrite slot %d?" % (slot+1),"Replace the save for %s from %s?" % [game,menu.saved_when(host.emulator.state_stamp(path))],func(): perform_state_action(true,slot),path)
		else: perform_state_action(true,slot)
	elif FileAccess.file_exists(path):
		menu.ask("Load slot %d?" % (slot+1),"Return to %s as saved %s. Progress since then is lost." % [game,menu.saved_when(host.emulator.state_stamp(path))],func(): perform_state_action(false,slot),path)

## Step-by-step help for glasses on this platform, in the help page markup
## (scripts/ui/help_article.gd).
func glasses_guide() -> String:
	if OS.get_name()=="Windows":
		return "\n".join([
			"## Starting in 3D",
			"1. On your normal monitor, choose the glasses' display and select Open glasses view.",
			"2. Switch the glasses to their side-by-side (SBS) mode when the view asks.",
			"## Head tracking",
			"- VITURE: download VITURE's free Windows SDK, then choose its ZIP with Set up VITURE SDK (start-up screen, or View & glasses → Tracking).",
			"- Other glasses: use a tool that sends OpenTrack, such as opentrack, PhoenixHeadTracker (XREAL) or VertoXR (Rokid, RayNeo), then choose View & glasses → Tracking → Tracking source → OpenTrack.",
			"## While playing",
			"R3 | R :: Recentre the view",
			"> Turning the wrong way? Invert that axis in View & glasses → Tracking.",
			"!! Fixed view",
			"There's no tracking yet, so the TV stays still. It's also how CRT XR plays on a normal screen.",
			"!! No glasses?",
			"Turn on View & glasses → Stereo & comfort → Flat screen (or press F3) to play full-screen without the room."])
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
		"> Turning the wrong way? Invert that axis in View & glasses → Tracking.",
		"## Your glasses",
		"CRT XR recognises VITURE, XREAL, Rokid and RayNeo displays. Only the VITURE Pro 2 has been tested.",
		"!! Fixed view",
		"There's no tracking yet, so the TV stays still. Check XR Gaming sees the glasses, then use View & glasses → Tracking → Connect glasses.",
		"!! No glasses?",
		"Turn on View & glasses → Stereo & comfort → Flat screen to play full-screen on the Deck's own screen, without the room."])

func state_action(saving: bool) -> void:
	if not saving:
		if not FileAccess.file_exists(host.emulator.state_path()):
			menu.show_error("No manual save yet. Choose Save state first."); return
		menu.ask("Load manual save?","Current progress will be replaced. %s • Slot 1 • saved %s" % [GameTitle.of(host.emulator.rom_path),menu.saved_when(host.emulator.state_stamp(host.emulator.state_path()))],func(): perform_state_action(false),host.emulator.state_path())
		return
	if FileAccess.file_exists(host.emulator.state_path()):
		menu.ask("Overwrite manual save?", "Replace the save for %s from %s?" % [GameTitle.of(host.emulator.rom_path),menu.saved_when(host.emulator.state_stamp(host.emulator.state_path()))],func(): perform_state_action(true),host.emulator.state_path())
	else: perform_state_action(true)

func reset_game() -> void:
	menu.ask("Reset the game?", "Restarts %s as if you pressed the console's reset button. Progress since your last save is lost; battery saves and save states are kept." % GameTitle.of(host.emulator.rom_path), func():
		if host.emulator.transition_busy: return
		var origin_mode: String = menu.mode
		var success: bool = await host.emulator.reset_game_async()
		if not host.loading_path.is_empty(): return
		if success:
			if menu.mode == origin_mode: host.close_settings()
			host.show_notice(host.emulator.status)
		else: menu.show_error(host.emulator.status))

## Multi-disc games (an .m3u playlist) swap to the next disc, wrapping round, as
## the game asks for it. It is a fourth small tile beside Reset, the card giving up its room.
func disc_tile(discs: Dictionary) -> Dictionary:
	var count: int = discs.count
	var next: int = (int(discs.index) + 1) % count
	return top_tile(menu.catalog.action("change_disc","Change disc",func(): change_disc(next, count),
		"Disc %d of %d is in. Opens the tray and puts in disc %d, when the game asks for it." % [int(discs.index) + 1, count, next + 1]),"disc")

func change_disc(index: int, _count: int) -> void:
	menu.ask("Insert disc %d?" % (index + 1),"Insert when the game asks for disc %d." % (index + 1),func():
		if host.emulator.change_disc(index): host.close_settings(); host.show_notice(host.emulator.status)
		else: menu.show_error(host.emulator.status))

func perform_state_action(saving: bool, slot := 0) -> void:
	call("_perform_state_action", saving, slot)

func _perform_state_action(saving: bool, slot: int) -> void:
	if host.emulator.transition_busy: return
	var succeeded: bool = await host.emulator.save_state_async(slot) if saving else await host.emulator.load_state_async(slot)
	if not host.loading_path.is_empty(): return
	if succeeded:
		host.show_notice(host.emulator.status)
		# A loaded save is where you want to be: back to the game.
		if not saving and menu.mode=="states": host.close_settings(); return
		menu.notify(host.emulator.status)
	else: menu.show_error(host.emulator.status+". Check the save folder and available storage.")
	menu.refresh()

## The width of Home and Pause's reading area, the 852 px between x = 54 and 906 on a
## 960 px menu (214 and 1066 on 1280).
const READING_WIDTH := 852
const TILE_GAP := 9
## One of the four equal Actions slots: (852 - 3 gaps) / 4 = 206.25 px.
const ACTION_WIDTH := 206
## Pixel rows cannot hold 206.25: the last slot takes the spare pixel, so the row ends on the edge.
const ACTION_LAST_WIDTH := READING_WIDTH - 3 * TILE_GAP - 3 * ACTION_WIDTH
## The small tiles beside the current game: Save, Load, Reset (and Change disc).
const SMALL_WIDTH := 92
const PREVIEW_HEIGHT := 72.0

# ── The game picture on the Pause card ───────────────────────────────────────

## The frame the game or video paused on, drawn once each time the menu opens (menu_controller
## open_pause), at twice the card's size and in the shape of the screen; null without one, as for
## cores that draw on the graphics card.
var pause_frame: Texture2D

func pause_aspect() -> float:
	return host.video.display_aspect() if host.video.loaded else float(host.emulator.display_aspect)

## 96 x 72 for a 4:3 source, 128 x 72 for 16:9, in the same proportion for any other shape.
func preview_size(aspect: float) -> Vector2:
	return Vector2(clampf(roundf(PREVIEW_HEIGHT * aspect), 48.0, 128.0), PREVIEW_HEIGHT)

func capture_pause_frame() -> void:
	pause_frame = null
	var source: Image = host.video.last_frame if host.video.loaded else (host.emulator.last_frame if host.emulator.loaded else null)
	if source == null or source.is_empty(): return
	var shown: Image = source.duplicate()
	if shown.is_compressed(): shown.decompress()
	shown.convert(Image.FORMAT_RGB8)
	var size := preview_size(pause_aspect()) * 2.0
	shown.resize(int(size.x), int(size.y), Image.INTERPOLATE_BILINEAR)
	pause_frame = ImageTexture.create_from_image(shown)

## The slot of a card's picture: the game's own frame, else its box art, else its console
## (or `icon` for a video).
func preview_fields(card: Dictionary, path: String, size: Vector2, frame: Texture2D, icon := "") -> void:
	card["thumbnail_size"] = size
	if not path.is_empty() and icon.is_empty(): card["thumbnail_console"] = menu.games.console_icon(path)
	else: card["thumbnail_icon"] = icon
	card["thumbnail_fill"] = frame != null
	var picture: Texture2D = frame
	# The frame is its own picture: box art arriving later must not replace it.
	card["thumbnail_path"] = path + "#frame" if frame != null else path
	if picture == null and host.library_box_art and not path.is_empty() and icon.is_empty():
		host.box_art.set_root(host.default_rom_dir)
		if not host.box_art.find(path).is_empty(): picture = host.box_art.texture(path)
	card["thumbnail"] = picture

## "Current session: 1h 30m", from the unpaused play since the game loaded.
func session_label() -> String:
	var length: String = PlayHistory.duration(int(host.session_seconds))
	return "Current session: " + ("just started" if length.is_empty() else length)

# ── Shared groups: Media, Quick settings and the pinned Actions ──────────────

## A small tile in the top row of Pause (Save, Load, Reset...): the icon above its name.
func top_tile(item: Dictionary, icon: String) -> Dictionary:
	menu.tile(item, icon, "", "top", 1)
	item.merge({"tile_look":"stack","flow":"row","min_width":SMALL_WIDTH,"min_height":84,"gap":TILE_GAP,"large_text":host.menu_large_text,"compact":false}, true)
	return item

## The top row's card: id "resume", Home's Continue ("home.continue") or the video's.
## It fills what the small tiles beside it leave of the row's 852 px.
func top_card(item: Dictionary, detail: String, trailing: String) -> Dictionary:
	item.merge({"layout":"tile","tile_look":"card","group":"top","flow":"row","columns":1,"fill":true,"min_width":0,"min_height":84,"gap":TILE_GAP,
		"value":"","detail":detail,"trailing":trailing,"large_text":host.menu_large_text}, true)
	return item

## The music deck's rows: the transport, while music plays. Idle, there is nothing: the Music
## Player tile is the way in.
## Media: Games, Videos and Music, three 278 px tiles; Music opens the mini player under them. A `height` of 112 or 84 stands the
## icon above the name (Home); 44 puts it beside (Pause). With nothing played yet, Games asks
## for a ROM folder. `gap` is the space above the MEDIA heading beyond the usual 5 px.
func media_tiles(height: int, games_id: String, video_id: String, video_action: Callable, music_rows: Array, first_run := false, gap := 0) -> Array:
	var fresh: bool = first_run and host.default_rom_dir.is_empty()
	var games: Dictionary = menu.catalog.action(games_id,"Games",menu.games.open_library,"Choose your main ROM folder or SD card. Your supported games appear automatically." if host.default_rom_dir.is_empty() else "Recent, Favourites and supported consoles.")
	var videos: Dictionary = menu.catalog.action(video_id,"Videos",video_action,"Browse your videos or set up video playback.")
	var music: Dictionary = menu.catalog.action("media.music","Music",menu.music.toggle_panel,
		"Closes the mini player. Music keeps playing." if not music_rows.is_empty() else "Opens the mini player: play and pause, Browse Music, the visualiser and volume.")
	var result: Array = []
	var icons: Array = ["folder" if fresh else "gamepad", "video", "music"]
	var number := 0
	for item in [games, videos, music]:
		menu.tile(item, icons[number], "primary" if fresh and number == 0 else "", "main", 3)
		item.merge({"min_width":menu.QUICK_WIDTH,"gap":TILE_GAP}, true)
		if height > 44: item.merge({"tile_look":"stack","min_height":height,"large_text":host.menu_large_text,"compact":false}, true)
		number += 1
		result.append(item)
	result[0]["section"] = "MEDIA"
	result[0]["section_extra"] = gap
	return result

## Quick settings, their heading 12 px under whatever precedes them.
func quick_grid() -> Array:
	var quick: Array = menu.quick_controls()
	quick[0]["section_extra"] = 7
	return quick

## Actions sit in four equal slots at the foot of the page, pinned there whatever scrolls above.
## Fewer than four leave their slots empty rather than stretching.
func action_slots(tiles: Array) -> Array:
	var slot := 0
	for item in tiles:
		item.merge({"pinned":true,"group":"actions","columns":4,"min_width":ACTION_LAST_WIDTH if slot == 3 else ACTION_WIDTH,"gap":TILE_GAP,"compact":true,"inline":true}, true)
		slot += 1
	tiles[0]["section"] = "ACTIONS"
	tiles[0]["below"] = 9
	return tiles

func glasses_tile() -> Dictionary:
	return menu.tile(menu.catalog.action("home.glasses","Using glasses",func(): menu.open_help("Using glasses",glasses_guide()),"How to connect glasses, start in side-by-side 3D and recentre."),"glasses","","actions",4)

## Favourite: an outline heart; once set, a filled amber heart and "Favourited".
## It is for the game on screen: Continue's on Home, the loaded one on Pause.
func favourite_tile(path: String) -> Dictionary:
	var set: bool = path in host.play_history.favourites
	return menu.tile(menu.catalog.action("favourite","Favourited" if set else "Favourite",func(): toggle_favourite(path),
		"Takes this game off your Favourites." if set else "Adds this game to your Favourites, in the library and here."),"heart" if set else "heart_outline","primary" if set else "","actions",4)

## Toggles the game in the favourite store and redraws the page at once (not on the next
## frame), so the heart and its name change as A is pressed.
func toggle_favourite(path: String) -> void:
	if not host.play_history.toggle(path):
		menu.show_error("Favourite could not be saved. Check user-folder permissions."); return
	menu.remember()
	menu.render()
	menu.notify("Added to Favourites" if path in host.play_history.favourites else "Removed from Favourites")

# ── Home ─────────────────────────────────────────────────────────────────────

## The home menu, before a game is loaded: your last game, then Media, Quick settings
## and Actions. Without a game to Continue, Media stands taller and Games has the focus.
func home_items() -> Array:
	var h=host
	var last: String = h.last_game_path
	var resumable: bool = not last.is_empty() and FileAccess.file_exists(last)
	var music: Array = menu.music.music_actions()
	var result: Array = []
	if resumable: result.append(continue_card(last))
	result.append_array(media_tiles(84 if resumable else 112,"home.library","home.videos",menu.videos.open_videos,music,not resumable,3 if resumable else 0))
	result.append_array(music)
	result.append_array(quick_grid())
	var tiles: Array = [menu.tile(menu.catalog.action("home.settings","Settings",menu.open_settings,"Adjust the view, picture, audio and room."),"gear","","actions",4)]
	# Once a ROM folder is set the view action stays; first-run Home has Settings and the glasses guide.
	if resumable or not h.default_rom_dir.is_empty(): tiles.append(view_tile("home.recenter"))
	tiles.append(glasses_tile())
	if resumable: tiles.append(favourite_tile(last))
	result.append_array(action_slots(tiles))
	return result

## The last game as a full-width card: its saved picture, title, console and play
## history, and Continue at the right edge.
func continue_card(path: String) -> Dictionary:
	var parts: Array[String] = []
	var system: String = menu.library.Registry.identify(path)
	if not system.is_empty(): parts.append(menu.library.Registry.SYSTEMS[system].name)
	var total: String = menu.games.play_label(path)
	if not total.is_empty(): parts.append(total)
	var played: int = host.play_history.last_played(path)
	if played > 0: parts.append("Last played " + menu.ago(played))
	var card: Dictionary = top_card(menu.catalog.action("home.continue",GameTitle.of(path),func(): menu.games.select_file(path),"Open your last cartridge and its automatic resume point, when available.",false,""),
		" · ".join(parts),"Continue ›")
	# Its picture is the game's resume point or latest save, whole at its own shape, else the cover.
	var saves: Array = menu.games.launch_saves(path)
	var picture: Texture2D = null
	var source := path
	if not saves.is_empty():
		var file: String = str(saves[0].path)
		menu.state_previews.request(file)
		picture = state_picture(file)
		if picture != null: source = file
	preview_fields(card, path, Vector2(96, PREVIEW_HEIGHT), picture)
	card["thumbnail_path"] = source if picture != null else path
	card["thumbnail_fill"] = false
	card["thumbnail_fit"] = "aspect"
	return card

# ── Game Pause ───────────────────────────────────────────────────────────────

func resume_game() -> void:
	if not host.close_settings(): return
	if host.emulator.loaded and host.visualizer.active:
		host.visualizer.leave()
		host.was_paused_before_menu = false
		host.emulator.set_paused(false)

## The pause menu while a game is loaded: the game's card with Save, Load and Reset beside
## it, then Media, Quick settings and Actions.
func pause_items() -> Array:
	var h=host
	var path: String = h.emulator.rom_path
	var discs: Dictionary = h.emulator.disc_info()
	var small: Array = [
		top_tile(menu.catalog.unavailable(menu.catalog.action("save_state","Save",func(): open_states(true),"Choose one of %d slots for this game." % STATE_SLOTS,not h.emulator.loaded),"Start a game first."),"save"),
		top_tile(menu.catalog.unavailable(menu.catalog.action("load_state","Load",func(): open_states(false),"Return to one of this game's saves.",not h.emulator.loaded or range(STATE_SLOTS).all(func(slot): return not FileAccess.file_exists(h.emulator.state_path(slot)))),"No saved state yet."),"load"),
		top_tile(menu.catalog.action("reset_game","Reset",reset_game,"Presses the console's reset button. Battery saves and save states are kept.",not h.emulator.loaded),"refresh")]
	# A game on several discs gets a fourth tile; the card gives up 101 px for it.
	if int(discs.get("count", 0)) > 1: small.append(disc_tile(discs))
	var system: String = menu.library.Registry.SYSTEMS.get(h.emulator.system_id, {}).get("name", "")
	var card: Dictionary = top_card(menu.catalog.action("resume",GameTitle.of(path),resume_game,"Return to the game with your settings saved.",not h.emulator.loaded,""),
		(system + " · " if not system.is_empty() else "") + session_label(),"›")
	preview_fields(card, path, preview_size(pause_aspect()), pause_frame)
	var result: Array = [card] + small
	for item in result: item["columns"] = result.size()
	var music: Array = menu.music.music_actions()
	result.append_array(media_tiles(44,"games","home.videos",menu.videos.open_videos,music,false,3))
	result.append_array(music)
	result.append_array(quick_grid())
	result.append_array(action_slots(action_tiles(path)))
	return result

## Settings, Screenshot and Recentre view (XR view in flat view), and Favourite for the game
## `favourite_path` when there is one: the Actions of a game's Pause menu and a video's.
func action_tiles(favourite_path := "") -> Array:
	var result: Array = [
		menu.tile(menu.catalog.action("settings","Settings",menu.open_settings_for_game,"Opens on this game's picture. The view, room, sound and controls are a category away." if host.emulator.loaded else "Adjust the view, picture, room, sound and controls."),"gear","","actions",4),
		menu.tile(menu.catalog.action("screenshot","Screenshot",host.take_screenshot,"Saves a clean single-eye image without menus or diagnostics."),"camera","","actions",4),
		view_tile("recenter")]
	if not favourite_path.is_empty(): result.append(favourite_tile(favourite_path))
	return result

## Recentre view in the room. Flat view has no view to recentre: the tile takes
## you back to the room instead, as XR view.
func view_tile(id: String) -> Dictionary:
	if host.flat_screen:
		return menu.tile(menu.catalog.action(id.replace("recenter", "xr_view"),"XR view",func():
			host.set_flat_screen(false)
			menu.notify("Flat view off · back in the room")
			menu.select.call_deferred(id, false),
			"Leaves Flat view for the room and the TV, for glasses. Y on Home comes back to Flat view."),"glasses","","actions",4)
	return menu.tile(menu.catalog.action(id,"Recentre view",host.recenter,"Points the view straight ahead again. Also on {R3}, without opening the menu."),"view","","actions",4)
