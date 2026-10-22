extends PanelContainer
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const Row = preload("res://scripts/ui/setting_row.gd")
const LibraryCard = preload("res://scripts/ui/library_card.gd")
const GameRow = preload("res://scripts/ui/library_game_row.gd")
const MusicIcon = preload("res://scripts/ui/music_transport_icon.gd")
const MusicTimeline = preload("res://scripts/ui/music_timeline.gd")
const ActionRow = preload("res://scripts/ui/action_row.gd")
const Catalog = preload("res://scripts/ui/menu_catalog.gd")
const Library = preload("res://scripts/ui/rom_library.gd")
const RomIndex = preload("res://scripts/content/rom_index.gd")
const Confirmation = preload("res://scripts/ui/confirmation_panel.gd")
const CATEGORIES := ["View","Picture","Audio","Room","Controls & XR","Saved setups","About & Help","Quick settings"]
var host
var catalog := Catalog.new()
var library := Library.new()
var rom_index := RomIndex.new()
const GAMES_PER_PAGE := 50
var launch_path := ""
var launch_origin: Dictionary = {}
var library_system := "snes"
var game_page := 0
var system_pages: Dictionary = {}
var mode := "pause"
var category := 7
var subsection := 0
var sections: Dictionary = {}
var memory: Dictionary = {}
var selected_id := ""
var items: Array = []
var rows: Array = []
var preview := false
var input_kind := "keyboard"
var search_query := ""
var alphabet_origin := "games"
var search_field: LineEdit
var back_button: Button
var back_glyph: Control
var preview_glyph: Control
var preview_button: Button
var section_hint: Label
var heading: Label
var subtitle: Label
var help_label: Label
var hints: HFlowContainer
var error_label: Label
var body: HBoxContainer
var sidebar: VBoxContainer
var section_bar: HBoxContainer
var section_tabs: HBoxContainer
var scroll: ScrollContainer
var column: VBoxContainer
var compact: Label
var confirm_panel: PanelContainer
var music_dir := ""
var music_page := 0
var music_origin: Dictionary = {}
var music_heading: Label
var folder_path_origin: Dictionary = {}
var folder_path_music := false
var rename_field: LineEdit
var sidebar_buttons: Array[Button] = []
var direction := Vector2i.ZERO
var repeat_remaining := 0.0
var stick := Vector2.ZERO
var stick_blocked := false
var dpad: Dictionary = {}
var held: Dictionary = {}
var blocked: Dictionary = {}
var triggers: Dictionary = {}
var device := -1
var default_armed := false
var rendering := false
var layout_revision := 0
var selecting := false
var scan_refresh_elapsed := 0.0
var scan_revision := -1
var scan_preferred_id := ""
var refresh_elapsed := 0.0
var notification := ""
var notification_time := 0.0
var notification_context := ""
var status_title := "Choose a game"
var status_detail := "Open a SNES, NES or Sega game, or adjust the test signal."
var confirmation: Dictionary = {}
var return_state: Dictionary = {}
var draft_names: Dictionary = {}
const PRESET_IDS := ["showcase","clean","rgb","auto","pal","ntsc"]
var picture_undo: ConfigFile
var help_title := ""
var help_copy := ""
var help_origin: Dictionary = {}
var caps := false
var entry_initialized := false
var sound_player: AudioStreamPlayer
var focus_tween: Tween


func _ready() -> void:
	theme = MenuSkin.create()
	sound_player=AudioStreamPlayer.new(); sound_player.volume_db=-28; add_child(sound_player)
	position = Vector2(36,28)
	size = Vector2(888,664)
	catalog.host = host; catalog.menu = self
	library.default_dir = host.default_rom_dir
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",8)
	add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	heading = Label.new(); heading.text = "CRT XR"
	heading.add_theme_font_size_override("font_size",32)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	back_button = Button.new(); back_button.text = "Back  [B]"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(back)
	top.add_child(back_button)
	back_button.flat=true; back_button.add_theme_font_size_override("font_size",16)
	back_glyph=preload("res://scripts/ui/button_glyph.gd").new("B"); top.add_child(back_glyph)
	subtitle = Label.new()
	subtitle.add_theme_color_override("font_color",MenuSkin.MUTED)
	subtitle.add_theme_font_size_override("font_size",20)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(subtitle)
	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.max_lines_visible = 2
	error_label.add_theme_color_override("font_color",Color("ffb59c"))
	error_label.add_theme_font_size_override("font_size",20)
	layout.add_child(error_label); error_label.hide()
	confirm_panel = Confirmation.new()
	layout.add_child(confirm_panel); confirm_panel.hide()
	rename_field = LineEdit.new()
	rename_field.max_length = 32
	rename_field.placeholder_text = "Name · Use on-screen keys or type"
	rename_field.text_submitted.connect(func(_text):
		if mode=="folder_path": submit_folder_path()
		elif mode=="radio_url": save_radio_url()
		else: save_draft_name())
	layout.add_child(rename_field); rename_field.hide()
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation",16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 176
	sidebar.add_theme_constant_override("separation",4)
	body.add_child(sidebar)
	var category_hint := Label.new(); category_hint.name="CategoryHint"; category_hint.add_theme_font_size_override("font_size",16); category_hint.add_theme_color_override("font_color",MenuSkin.MUTED); sidebar.add_child(category_hint)
	for i in range(CATEGORIES.size()):
		var index := i
		var button := Button.new()
		button.text = CATEGORIES[i]
		button.add_theme_font_size_override("font_size",20)
		button.custom_minimum_size.y = 36
		for style in ["normal","hover","pressed"]: button.add_theme_stylebox_override(style,MenuSkin.box(Color.TRANSPARENT,Color.TRANSPARENT,0,6))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): switch_category(index-category))
		sidebar.add_child(button); sidebar_buttons.append(button)
	# Keep category IDs stable while putting the everyday route first.
	sidebar.move_child(sidebar_buttons[7],1)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	body.add_child(content)
	section_bar = HBoxContainer.new()
	section_bar.add_theme_constant_override("separation",6)
	content.add_child(section_bar)
	section_tabs = HBoxContainer.new()
	section_tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	section_tabs.add_theme_constant_override("separation",8)
	section_bar.add_child(section_tabs)
	section_hint=Label.new(); section_hint.add_theme_font_size_override("font_size",16)
	section_hint.add_theme_color_override("font_color",MenuSkin.MUTED)
	section_hint.tooltip_text="Previous / next section"
	section_bar.add_child(section_hint)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = false
	search_field=LineEdit.new()
	search_field.placeholder_text="Search games…  (Ctrl+F)"
	search_field.text_changed.connect(update_search)
	content.add_child(search_field); search_field.hide()
	var scroll_frame := Control.new()
	scroll_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_child(scroll_frame)
	scroll_frame.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var edges := preload("res://scripts/ui/scroll_edges.gd").new()
	edges.scroll=scroll
	edges.panel=self
	scroll_frame.add_child(edges)
	edges.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",6)
	scroll.add_child(column)
	compact = Label.new()
	compact.add_theme_font_size_override("font_size",24)
	compact.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	compact.add_theme_color_override("font_color",MenuSkin.AMBER)
	layout.add_child(compact); compact.hide()
	help_label = Label.new()
	help_label.custom_minimum_size.y = 64
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.max_lines_visible = 2
	help_label.add_theme_font_size_override("font_size",20)
	layout.add_child(help_label)
	hints = preload("res://scripts/ui/shortcut_footer.gd").new()
	hints.add_theme_font_size_override("font_size",18)
	hints.add_theme_color_override("font_color",MenuSkin.MUTED)
	hints.custom_minimum_size.y=48
	layout.add_child(hints)
	preview_button=Button.new(); preview_button.text="Adjust with preview"
	preview_button.focus_mode=Control.FOCUS_NONE
	preview_button.pressed.connect(toggle_preview)
	top.add_child(preview_button)
	preview_button.flat=true; preview_button.add_theme_font_size_override("font_size",16)
	preview_glyph=preload("res://scripts/ui/button_glyph.gd").new("X"); top.add_child(preview_glyph)
	visibility_changed.connect(func(): set_process(visible))
	open_pause()
	hide()

func state_key() -> String:
	match mode:
		"settings": return "settings:%d:%d" % [category,subsection]
		"music_browser": return "music:%s:%d" % [music_dir,music_page]
		"browser": return "browser:"+library.current_dir
		"games": return "games:%s:%s:%d" % [host.default_rom_dir,library_system,game_page]
		"slot": return "slot:%d" % host.selected_profile
	return mode

func remember() -> void:
	if is_instance_valid(scroll): memory[state_key()] = {"id":selected_id,"scroll":scroll.scroll_vertical}

func refresh() -> void:
	if not is_instance_valid(column): return
	remember(); clear_input()
	if visible: render.call_deferred()

func open_pause() -> void:
	remember(); clear_input()
	mode = "pause"; preview = false
	selected_id = "resume" if host.emulator.loaded else ("home.continue" if FileAccess.file_exists(host.last_game_path) else "home.library")
	memory[state_key()] = {"id":selected_id,"scroll":0}
	render()

func open_settings() -> void:
	remember(); clear_input()
	mode = "settings"; preview = false
	subsection = int(sections.get(category,0))
	render()

func switch_category(delta: int) -> void:
	if mode!="settings" or preview: return
	remember(); clear_input()
	sections[category] = subsection
	category = posmod(category+delta,CATEGORIES.size())
	subsection = int(sections.get(category,0))
	render()

func switch_section(delta: int) -> void:
	if mode!="settings" or preview: return
	remember(); clear_input()
	subsection = posmod(subsection+delta,catalog.pages(category).size())
	sections[category] = subsection
	render()

func snapshot() -> Dictionary:
	return {"mode":mode,"category":category,"subsection":subsection}

func restore(state: Dictionary) -> void:
	mode = state.mode; category = state.category; subsection = state.subsection
	clear_input(); render()

func back() -> void:
	if preview:
		remember(); preview = false; clear_input(); render(); return
	remember(); clear_input()
	match mode:
		"pause": host.close_settings()
		"settings", "library": mode="pause"; render()
		"library_tools": mode="library"; render()
		"browser", "volumes", "drives": mode="library_tools"; render()
		"games", "recent", "favourites": mode="library"; render()
		"alphabet": mode=alphabet_origin; render()
		"launch": restore(launch_origin)
		"slot", "room_presets": mode="settings"; render()
		"folder_path": restore(folder_path_origin)
		"rename": mode="slot"; render()
		"music_browser": restore(music_origin)
		"radio_url": mode="settings"; render()
		"help": restore(help_origin)
		"confirm": restore(return_state)

func ask(title: String, detail: String, callback: Callable, preview_path := "") -> void:
	remember(); return_state = snapshot(); clear_input()
	confirmation = {"title":title,"detail":detail,"callback":callback,"preview":preview_path}
	mode = "confirm"
	memory[state_key()] = {"id":"cancel","scroll":0}
	render()

func confirm_reset() -> void:
	ask("Reset all settings?","Restores option defaults. Games, SRAM and save states are kept.",host.reset_all_options)

func confirmed() -> void:
	var callback: Callable = confirmation.callback
	restore(return_state)
	callback.call()

func open_room_presets() -> void:
	remember(); clear_input(); mode="room_presets"; render()

func open_slot(slot: int) -> void:
	remember(); clear_input(); host.selected_profile=slot; mode="slot"; render()

func save_setup() -> void:
	var title := str(draft_names.get(host.selected_profile,setup_name()))
	var callback := func():
		if host.save_profile(title): refresh(); notify("Saved · "+title)
		else: show_error("Setup could not be saved. Check free space and user-folder permissions.")
	if FileAccess.file_exists(host.profile_path()) or FileAccess.file_exists(host.profile_path()+".bak"):
		ask("Overwrite this setup?","Replace “%s” with your current view, room and picture settings?" % setup_name(),callback)
	else: callback.call()

func setup_name() -> String:
	var config = host.settings_store.read(host.profile_path())
	return str(config.get_value("meta","name",host.PROFILE_NAMES[host.selected_profile]))

func save_draft_name() -> void:
	draft_names[host.selected_profile] = rename_field.text.strip_edges().left(32)
	mode="slot"; clear_input(); render()
	notify("Name ready. Save this setup to store the new name.")

func open_library() -> void:
	remember(); clear_input(); mode="library"; preview=false
	search_query=""; search_field.text=""
	scan_preferred_id=""
	library.default_dir = host.default_rom_dir
	rom_index.start(host.default_rom_dir)
	render()

func open_library_tools() -> void:
	remember(); clear_input(); mode="library_tools"; render()

func card(item: Dictionary, caption: String, glyph: String, accent: Color, group: String) -> Dictionary:
	item.merge({"layout":"card","caption":caption,"glyph":glyph,"accent":accent,"group":group})
	return item

func library_items() -> Array:
	var h=host
	if rom_index.total()==0:
		return [card(catalog.action("library.setup","Set up your ROM library" if h.default_rom_dir.is_empty() else "Choose a ROM folder",open_library_tools,"Choose your main ROM folder or SD card. Supported games appear here automatically; your files stay where they are."),"CHOOSE A FOLDER TO GET STARTED","locations",MenuSkin.AMBER,"LIBRARY SETUP")]
	var result: Array = [
		card(catalog.action("library.recent","Recently played",func(): open_history("recent"),"Return to your latest games. Unplugged-card entries are kept.",h.play_history.recent.is_empty(),"%d game%s" % [h.play_history.recent.size(),"" if h.play_history.recent.size()==1 else "s"]),"PICK UP & PLAY","recent",MenuSkin.AMBER,"QUICK ACCESS"),
		card(catalog.action("library.favourites","Favourites",func(): open_history("favourites"),"Your favourites across every supported console. Press X on a game to add it.",h.play_history.favourites.is_empty(),"%d game%s" % [h.play_history.favourites.size(),"" if h.play_history.favourites.size()==1 else "s"]),"YOUR PERSONAL SHELF","favourites",Color("dfb984"),"QUICK ACCESS")]
	var identity := {"snes":["NINTENDO · 16-BIT","ba9fdb"],"nes":["NINTENDO · 8-BIT","dc9b8e"],"megadrive":["SEGA · 16-BIT","8ebfdc"],"mastersystem":["SEGA · 8-BIT","9ac4ab"],"gamegear":["SEGA · HANDHELD","d4bb7d"]}
	for system in library.Registry.SYSTEMS:
		var id: String=system
		var count: int=rom_index.games.get(id,[]).size()
		if count==0: continue
		result.append(card(catalog.action("library.system."+id,library.Registry.SYSTEMS[id].name,func(): open_system(id),"Open all %s cartridges in your library. Folders for other consoles stay out of this view." % library.Registry.SYSTEMS[id].name,false,"%d game%s" % [count,"" if count==1 else "s"]),identity[id][0],id,Color(identity[id][1]),"YOUR CONSOLES"))
	if h.default_rom_dir.is_empty():
		result.push_front(card(catalog.action("library.setup","Set up your ROM library",open_library_tools,"Choose the folder containing snes, nes, megadrive and your other systems. Subfolders are included automatically."),"START HERE","locations",MenuSkin.AMBER,"LIBRARY SETUP"))
	var detail := "Choose your main ROM folder" if h.default_rom_dir.is_empty() else "Folders · SD cards · Refresh"
	result.append(card(catalog.action("library.locations","Library locations",open_library_tools,"Set the main roms folder once. CRT XR finds supported consoles and leaves the files where they are.",false,detail),"MAKE YOURSELF AT HOME","locations",Color("aeb6bf"),"YOUR CONSOLES" if rom_index.total()>0 else "LIBRARY"))
	return result

func refresh_library() -> void:
	var previous := selected_id
	remember(); clear_input(); error_label.hide()
	rom_index.start(host.default_rom_dir)
	scan_preferred_id=previous if mode=="library" else ""
	render()

func open_system(system: String) -> void:
	remember(); clear_input(); search_query=""; search_field.text=""
	library_system=system; game_page=int(system_pages.get(system,0))
	var count: int = rom_index.games.get(system,[]).size()
	game_page=clampi(game_page,0,maxi(0,(count-1)/GAMES_PER_PAGE))
	mode="games"; render()

func change_game_page(delta: int) -> void:
	var count: int = game_entries().size()
	var next := clampi(game_page+delta,0,maxi(0,(count-1)/GAMES_PER_PAGE))
	if next==game_page: return
	remember(); clear_input(); game_page=next; system_pages[library_system]=game_page
	render()

func open_folder(path: String) -> void:
	remember(); clear_input()
	if not library.show_folder(path): show_error(library.message); return
	error_label.hide()
	mode="browser"; render()

func open_drives() -> void:
	remember(); clear_input(); mode="drives"; render()

func enter_folder_path(for_music := false) -> void:
	remember(); folder_path_origin=snapshot(); folder_path_music=for_music
	clear_input(); mode="folder_path"; render()
	rename_field.text=music_dir if for_music else library.current_dir
	focus_entry(); rename_field.select_all()

func submit_folder_path() -> void:
	var path := library.Locations.normalize_windows_path(rename_field.text) if OS.get_name()=="Windows" else rename_field.text.strip_edges()
	if path.is_empty(): show_error("Enter a folder path, such as D:/roms or //server/share/roms."); return
	if DirAccess.open(path)==null:
		show_error("Cannot open this folder. Check the path, drive or network connection. For a network share, connect and sign in through Windows File Explorer first.")
		return
	if folder_path_music:
		var origin := music_origin.duplicate()
		open_music_browser(path)
		music_origin=origin
	else: open_folder(path)

func browse_folders() -> void:
	var candidates := [library.current_dir,host.default_rom_dir,host.last_game_path.get_base_dir(),library.home_folder()]
	for path in candidates:
		if not str(path).is_empty() and DirAccess.open(path)!=null:
			open_folder(path); return
	show_error("No available folder could be opened.")

func open_default() -> void:
	if host.default_rom_dir.is_empty(): show_error("No default folder yet. Browse to your ROM folder and press RB.")
	else: open_folder(host.default_rom_dir)

func open_cards() -> void:
	var paths := library.cards()
	if paths.is_empty(): show_error("No SD card is mounted. Insert the card, then try again.")
	elif paths.size()==1: open_folder(paths[0])
	else: remember(); clear_input(); mode="volumes"; render()

func set_default(path: String) -> void:
	if not path.is_empty() and DirAccess.open(path)==null:
		show_error("Open an available folder before setting a default."); return
	var previous: String = host.default_rom_dir
	host.default_rom_dir = path
	if host.save_library()!=OK:
		host.default_rom_dir = previous
		show_error("Default folder could not be saved. Check that user storage is writable.")
		return
	library.default_dir = path
	rom_index.start(path)
	notify("ROM library folder saved. Choose game shows systems after scanning." if not path.is_empty() else "Default folder cleared; your ROMs are unchanged")

func select_file(path: String) -> void:
	if not FileAccess.file_exists(path): show_error("Game unavailable. Reconnect its SD card and try again."); return
	var automatic: String = host.emulator.auto_path_for(path)
	if FileAccess.file_exists(automatic):
		remember(); launch_origin=snapshot(); launch_path=path
		clear_input(); mode="launch"; render()
	else: launch_game(path,false)

func launch_game(path: String, continuing: bool) -> void:
	if not host.load_game(path): show_error(host.startup_message); return
	if continuing and not host.emulator.load_auto():
		show_error(host.emulator.status+" Select Start fresh to play without this save.")
		return
	var feedback: String = host.emulator.status
	host.was_paused_before_menu=false
	host.close_settings()
	if continuing: host.show_notice(feedback)

func open_history(which: String) -> void:
	remember(); clear_input(); search_query=""; search_field.text=""; mode=which; render()

func game_item(path: String, label: String) -> Dictionary:
	var item: Dictionary = catalog.action("game:"+path,label,func(): select_file(path),"Open this cartridge or mark it as a favourite.",false,"★" if path in host.play_history.favourites else "›")
	item["rom_path"]=path
	item["layout"]="game"
	var system: String=library.Registry.identify(path)
	var folder := path.get_base_dir().get_file()
	if system.is_empty(): system=RomIndex.Folders.system(folder)
	item["detail"]=(library.Registry.SYSTEMS[system].name if not system.is_empty() else "Cartridge")+(" · Storage unavailable" if not FileAccess.file_exists(path) else (" · "+folder if RomIndex.Folders.system(folder).is_empty() else " cartridge"))
	return item

func toggle_favourite() -> void:
	var row = selected_row()
	if row==null or not row.item.has("rom_path"): return
	if not host.play_history.toggle(row.item.rom_path):
		show_error("Favourite could not be saved. Check user-folder permissions."); return
	refresh(); notify("Favourites updated")

func state_action(saving: bool) -> void:
	if not saving:
		if not FileAccess.file_exists(host.emulator.state_path()):
			show_error("No manual save yet. Choose Save state first."); return
		ask("Load manual save?","Current progress will be replaced. %s • Slot 0 • %s" % [host.emulator.rom_path.get_file().get_basename(),host.emulator.state_time(host.emulator.state_path())],func(): perform_state_action(false),host.emulator.state_path())
		return
	if FileAccess.file_exists(host.emulator.state_path()):
		ask("Overwrite manual save?", "Replace the save for %s from %s?" % [host.emulator.rom_path.get_file().get_basename(),host.emulator.state_time(host.emulator.state_path())],func(): perform_state_action(true),host.emulator.state_path())
	else: perform_state_action(true)

func perform_state_action(saving: bool) -> void:
	var succeeded: bool = host.emulator.save_state() if saving else host.emulator.load_state()
	if succeeded:
		notify(host.emulator.status)
		host.show_notice(host.emulator.status)
	else: show_error(host.emulator.status+". Check the save folder and available storage.")
	refresh()

func open_music_browser(path := "") -> void:
	if OS.get_name()=="Windows" and not path.is_empty(): path=library.Locations.normalize_windows_path(path)
	if mode!="music_browser": music_origin=snapshot()
	remember(); clear_input()
	if path.is_empty():
		path=music_dir if not music_dir.is_empty() else host.music.last_file.get_base_dir()
		if path.is_empty(): path=OS.get_system_dir(OS.SYSTEM_DIR_MUSIC)
		if DirAccess.open(path)==null: path=library.home_folder()
	if DirAccess.open(path)==null: show_error("Folder unavailable. Reconnect its drive."); return
	music_dir=path; music_page=0; mode="music_browser"; render()

func edit_radio_url() -> void:
	remember(); clear_input(); mode="radio_url"; render()
	rename_field.text=host.music.station_url; focus_entry()

func save_radio_url() -> void:
	var url := rename_field.text.strip_edges()
	if not url.is_empty() and host.music.parse_url(url).is_empty():
		show_error("Use a direct http:// or https:// MP3 stream URL."); return
	host.music.station_url=url
	mode="settings"; clear_input(); render(); notify("Radio URL ready. Choose Play radio to listen.")

func music_browser_items() -> Array:
	var result: Array=[catalog.action("music.up","Parent folder",func(): open_music_browser(music_dir.get_base_dir()))]
	var locations: Array=[catalog.action("music.path","Open folder or network path…",func(): enter_folder_path(true)),catalog.action("music.home","Music folder",func(): open_music_browser(OS.get_system_dir(OS.SYSTEM_DIR_MUSIC)))]
	for mount in library.cards():
		var path: String=mount
		locations.append(catalog.action("music.sd."+path,"SD card",func(): open_music_browser(path)))
	if OS.get_name()=="Windows":
		for drive in library.Locations.computer_drives():
			locations.append(catalog.action("music.drive."+drive,drive,func(): open_music_browser(drive)))
	var entries: Array=[]
	var album: Array=host.music.album_tracks(music_dir)
	if not album.is_empty():
		result.push_front(catalog.action("music.album","Play this album",func():
			if host.music.play_album(music_dir): mode="pause"; clear_input(); render()
			else: show_error(host.music.status),"Play this folder in disc/track order, falling back to natural filenames.",false,"%d tracks" % album.size()))
	for name in DirAccess.get_directories_at(music_dir):
		if name.begins_with("."): continue
		var path := music_dir.path_join(name)
		entries.append(catalog.action("music.folder."+path,name+" /",func(): open_music_browser(path)))
	for tag in album:
		var path: String=tag.path
		var label: String=str(tag.title)
		if not str(tag.artist).is_empty(): label+=" — "+str(tag.artist)
		entries.append(catalog.action("music.track."+path,label,func():
			if host.music.play_file(path): mode="pause"; clear_input(); render()
			else: show_error(host.music.status),"Play from this track, then continue through the folder. "+str(tag.album)))
	music_page=clampi(music_page,0,maxi(0,(entries.size()-1)/50))
	if music_page>0: result.append(catalog.action("music.previous","Previous page",func(): music_page-=1; clear_input(); render()))
	result.append_array(entries.slice(music_page*50,(music_page+1)*50))
	if (music_page+1)*50<entries.size(): result.append(catalog.action("music.next","Next page",func(): music_page+=1; clear_input(); render()))
	result.append_array(locations)
	return result

func music_actions() -> Array:
	var result: Array=[]
	var music=host.music
	if not music.kind.is_empty() and music.player.playing and not music.player.stream_paused:
		for item in [catalog.action("transport.previous","Previous",func(): music.skip(-1); refresh(),"Previous album track.",not music.can_skip(-1),""),
			catalog.action("transport.play",music.playback_caption(),func(): music.toggle_playback(); refresh(),"Pause/resume local music; reconnect live radio.",false,""),
			catalog.action("transport.next","Next",func(): music.skip(1); refresh(),"Next album track.",not music.can_skip(1),""),
			catalog.action("transport.stop","Stop",func(): music.stop(); refresh(),"Stop music. Play restarts the current track.",false,"")]:
			item.layout="transport"
			item.icon=item.id.get_slice(".",1)
			if item.id=="transport.play": item.icon="pause" if music.player.playing and not music.player.stream_paused else "play"
			result.append(item)
		if music.duration()>0:
			result.push_front({"id":"transport.seek","label":"Track position","kind":"seek","layout":"music_seek","getter":music.position_seconds,"setter":music.seek,"duration":music.duration,"progress":music.progress_text,"help":"Left/right seeks by 10 seconds. Drag or click the timeline to jump through a long mix."})
	if not music.kind.is_empty() and (not music.player.playing or music.player.stream_paused):
		result.append(catalog.action("transport.play","▶ Resume music",func(): music.toggle_playback(); refresh(),music.now_playing(),false,"Play"))
	var browse := catalog.action("transport.choose","Music · Browse albums",open_music_browser,"Choose an album or MP3 from local storage or SD card.")
	if not result.is_empty() and music.player.playing and not music.player.stream_paused: browse.layout="music_link"
	result.append(browse)
	return result

func get_items() -> Array:
	var h = host
	match mode:
		"music_browser": return music_browser_items()
		"radio_url": return text_keys()+[catalog.action("radio.save","Use this URL",save_radio_url),catalog.action("radio.cancel","Cancel",back)]
		"pause":
			if not h.emulator.loaded:
				var home: Array = [catalog.action("home.continue","Continue last game",func(): select_file(h.last_game_path),"Open your last cartridge and its automatic resume point, when available.",h.last_game_path.is_empty() or not FileAccess.file_exists(h.last_game_path),h.last_game_path.get_file().get_basename() if not h.last_game_path.is_empty() else "No recent game"),
					catalog.action("home.library","Game library",open_library,"Choose your main ROM folder or SD card. Your supported games appear automatically." if h.default_rom_dir.is_empty() else "Recent, Favourites and supported consoles."),
					catalog.action("home.settings","Settings",open_settings,"Adjust the view, picture, audio and room."),
					catalog.action("home.exit","Exit",func(): ask("Exit CRT XR?","Your settings will be saved.",h.request_exit),"Close CRT XR.")]
				home.insert(2,catalog.action("home.quick","Quick settings",func(): category=7; subsection=0; open_settings(),"TV position, recenter, picture preset and volumes."))
				if h.default_rom_dir.is_empty(): home[1].label="Set up library"
				home=home.slice(0,3)+music_actions()+home.slice(3)
				return home
			var pause_items: Array = [
			catalog.action("resume","Resume",h.close_settings,"Return to the game with your settings saved.",not h.emulator.loaded),
			catalog.action("games","Choose game",open_library,"Open your recent game, default ROM folder or SD card."),
			catalog.action("save_state","Save state",func(): state_action(true),"Saves the current game to state slot 0.",not h.emulator.loaded),
			catalog.action("load_state","Load state",func(): state_action(false),"Restores state slot 0 for the current game.",not h.emulator.loaded or not FileAccess.file_exists(h.emulator.state_path())),
			catalog.action("screenshot","Screenshot",h.take_screenshot,"Saves a clean single-eye image without menus or diagnostics."),
			catalog.action("settings","Settings",open_settings,"Adjust the view, picture, room, controls and saved setups."),
			catalog.action("exit","Exit CRT XR",func(): ask("Exit CRT XR?","An automatic resume point, settings and cartridge SRAM will be saved.",h.request_exit),"Close the application.")]
			pause_items.insert(2,catalog.action("quick","Quick settings",func(): category=7; subsection=0; open_settings(),"Everyday picture, placement and volume controls."))
			pause_items=pause_items.slice(0,-1)+music_actions()+pause_items.slice(-1)
			return pause_items
		"launch": return [
			catalog.action("launch.continue","Continue",func(): launch_game(launch_path,true),launch_path.get_file()+" • Automatic save • "+h.emulator.state_time(h.emulator.auto_path_for(launch_path))),
			catalog.action("launch.fresh","Start fresh",func(): launch_game(launch_path,false),"Start from the title screen. Cartridge battery saves and manual states are kept."),
			catalog.action("launch.cancel","Back",back,"Return without starting this game.")]
		"recent", "favourites":
			var result: Array = [catalog.action("games.jump","Jump to letter…",open_alphabet,"Jump to a game with the controller.",history_paths().is_empty())]
			var paths: Array = history_paths()
			for path in paths: result.append(game_item(path,path.get_file().get_basename()))
			return result
		"settings": return catalog.pages(category)[subsection].rows
		"help": return []
		"library": return library_items()
		"library_tools":
			var locations: Array = []
			for candidate in library.Locations.library_candidates(library.home_folder(),library.Locations.sd_cards()):
				var path: String = candidate
				locations.append(catalog.action("library.detected:"+path,"Found ROM folder: "+path.trim_prefix(library.home_folder()+"/"),func(): open_folder(path),"Open this detected library, then choose Use this folder for my library. "+path))
			return locations + [
			catalog.action("library.refresh","Refresh library",refresh_library,"Rescans the saved ROM folder for added or removed cartridges.",h.default_rom_dir.is_empty()),
			catalog.action("library.default","Set up ROM library" if h.default_rom_dir.is_empty() else "Change ROM library folder",browse_folders,h.default_rom_dir if not h.default_rom_dir.is_empty() else "Browse to the main roms folder (containing snes, nes, megadrive, etc.), then press RB."),
			catalog.action("library.sd","SD card",open_cards,"Browse a mounted Steam Deck SD card."),
			catalog.action("library.browse","Browse folders",browse_folders,"Browse folders on this computer."),
			catalog.action("library.drives","Computer drives",open_drives,"Choose a drive, then browse to your ROM folder.",OS.get_name()!="Windows"),
			catalog.action("library.path","Open folder or network path…",enter_folder_path,"Enter a drive folder or a network share path; Windows handles sign-in."),
			catalog.action("library.clear","Clear default folder",func(): set_default(""),"Forget the default folder without changing any files.",h.default_rom_dir.is_empty())]
		"games":
			var result: Array = [catalog.action("games.jump","Jump to letter…",open_alphabet,"Jump to a game with the controller.",game_entries().is_empty())]
			var games: Array = game_entries()
			for game in games.slice(game_page*GAMES_PER_PAGE,(game_page+1)*GAMES_PER_PAGE):
				var path: String = game.path
				result.append(game_item(path,game.label))
			if games.size()>GAMES_PER_PAGE:
				result.append(catalog.action("games.previous","Previous page",func(): change_game_page(-1),"Also available with LB. Left/right jumps ten games.",game_page==0))
				result.append(catalog.action("games.next","Next page",func(): change_game_page(1),"Also available with RB. Left/right jumps ten games.",(game_page+1)*GAMES_PER_PAGE>=games.size()))
			return result
		"alphabet":
			var result: Array=[]
			var available: Dictionary={}
			for entry in alphabet_entries(): available[letter_for(str(entry.label))]=true
			for letter in ["#","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]:
				var chosen: String=letter
				var item=catalog.action("letter."+chosen,chosen,func(): jump_to_letter(chosen),"Jump to the first matching game.",not available.has(chosen))
				item.layout="letter"; result.append(item)
			return result
		"browser":
			var result: Array = []
			result.append(catalog.action("folder.remember","Use this folder for my library",func():
				set_default(library.current_dir)
				if host.default_rom_dir==library.current_dir: open_library(),"Choose the parent ROM folder to include all supported systems and their subfolders. Current folder: "+library.current_dir))
			if OS.get_name()=="Windows": result.append(catalog.action("folder.drives","Computer drives",open_drives,"Open another drive, including mapped network drives."))
			result.append(catalog.action("folder.path","Open folder or network path…",enter_folder_path,"Enter a local folder or //server/share/roms."))
			for entry in library.entries:
				var path: String = entry.path
				var folder: bool = entry.folder
				result.append(catalog.action("file:"+path,entry.label,func():
					if folder: open_folder(path)
					else: select_file(path),path,false,"Folder" if folder else entry.get("system","Game")))
			result.append(catalog.action("folder.home","Home folder",func(): open_folder(library.home_folder()),"Browse your home folder."))
			return result
		"drives":
			var result: Array = [catalog.action("drives.path","Open folder or network path…",enter_folder_path,"Use a network share such as //server/share/roms, or enter a drive path.")]
			for path in library.Locations.computer_drives():
				result.append(catalog.action("drive:"+path,path,func(): open_folder(path),"Browse this drive."))
			return result
		"volumes":
			var result: Array = []
			for path in library.cards():
				var location: String = path
				result.append(catalog.action("volume:"+location,location.get_file(),func(): open_folder(location),location))
			return result
		"room_presets":
			var result: Array = []
			for pair in [["warm","Warm bedroom"],["bright","Bright inspection"],["dim","Dim XR"]]:
				var preset: String = pair[0]
				result.append(catalog.action("lighting."+preset,pair[1],func(): h.room_preset(preset); notify("Lighting preset applied"),"Changes room illumination and distance fade. Picture settings stay as they are."))
			return result
		"slot":
			var saved := FileAccess.file_exists(h.profile_path()) or FileAccess.file_exists(h.profile_path()+".bak")
			return [catalog.action("slot.save","Save current setup",save_setup,"Stores current room, view and picture in this slot."),
				catalog.action("slot.load","Load setup",h.load_profile,"Apply this slot while retaining display mode and tracking provider.",not saved),
				catalog.action("slot.rename","Name for next save",func(): mode="rename"; entry_initialized=false; clear_input(); render(); focus_entry(),"Use the on-screen keys or a physical keyboard."),
				catalog.action("slot.undo","Undo last setup load",h.undo_profile,"Restores the settings from before the last setup load.",h.profile_undo==null)]
		"folder_path": return text_keys()+[catalog.action("folder_path.open","Open folder",submit_folder_path,"Opens a local folder or a network share you can access in Windows."),catalog.action("folder_path.cancel","Cancel",back)]
		"rename": return text_keys()+[catalog.action("rename.save","Use this name",save_draft_name,"The new name is stored when you save the setup."),catalog.action("rename.cancel","Cancel",back,"Leave the name unchanged.")]
		"confirm": return [catalog.action("cancel","Cancel",back,"Keep things as they are."),catalog.action("confirm","Confirm",confirmed,confirmation.detail)]
	return []

func render() -> void:
	if not is_instance_valid(column) or not visible: return
	rendering = true
	layout_revision+=1
	items = get_items()
	if preview:
		items = items.filter(func(item): return item.get("visual",false))
	for child in column.get_children(): column.remove_child(child); child.queue_free()
	rows.clear()
	var group := ""
	var grid: GridContainer
	music_heading=null
	var music_layout: VBoxContainer
	var transport_grid: HBoxContainer
	var group_row := -1
	var group_index := 0
	for item in items:
		var parent: Container=column
		if item.get("layout","") in ["transport","music_seek","music_link"]:
			if music_layout==null:
				var panel := PanelContainer.new()
				panel.add_theme_stylebox_override("panel",MenuSkin.box(Color("222a30"),Color("47535b"),1,12))
				column.add_child(panel)
				music_layout=VBoxContainer.new(); music_layout.add_theme_constant_override("separation",4); panel.add_child(music_layout)
				var badge := Label.new(); badge.text="MUSIC PLAYER"; badge.add_theme_font_size_override("font_size",16); badge.add_theme_color_override("font_color",MenuSkin.AMBER); music_layout.add_child(badge)
				if not host.music.kind.is_empty():
					music_heading=Label.new(); music_heading.add_theme_font_size_override("font_size",20)
					music_heading.autowrap_mode=TextServer.AUTOWRAP_OFF; music_heading.max_lines_visible=2; music_heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
					music_layout.add_child(music_heading)
			if item.layout=="transport":
				if transport_grid==null:
					transport_grid=HBoxContainer.new(); transport_grid.add_theme_constant_override("separation",12); transport_grid.alignment=BoxContainer.ALIGNMENT_CENTER; music_layout.add_child(transport_grid)
				parent=transport_grid
			else: parent=music_layout
		if item.get("layout","")=="card":
			if item.group!=group:
				if grid!=null: group_row+=ceili(float(group_index)/2.0)
				else: group_row=0
				group=item.group; group_index=0
				var label := Label.new(); label.text=group; label.add_theme_font_size_override("font_size",16); label.add_theme_color_override("font_color",MenuSkin.MUTED); column.add_child(label)
				grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);column.add_child(grid)
			parent=grid
			item["nav_row"]=group_row+group_index/2; item["nav_col"]=group_index%2; group_index+=1
		if item.get("layout","") in ["letter","key"]:
			if grid==null:
				grid=GridContainer.new(); grid.columns=10 if item.get("layout","")=="key" else 6; grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8); column.add_child(grid)
			parent=grid
			item["nav_row"]=group_index/grid.columns; item["nav_col"]=group_index%grid.columns; group_index+=1
		if item.id in ["exit","home.exit"]:
			var divider := HSeparator.new()
			column.add_child(divider)
		var row = MusicIcon.new() if item.get("layout","")=="transport" else (MusicTimeline.new() if item.kind=="seek" else (LibraryCard.new() if item.get("layout","")=="card" else (GameRow.new() if item.get("layout","")=="game" else (ActionRow.new() if item.kind=="action" else Row.new()))))
		parent.add_child(row); row.configure(item)
		row.selected.connect(select)
		row.adjust_requested.connect(func(id,delta):
			select(id,false)
			if selected_id==id: adjust(delta))
		row.pressed.connect(func(): select(item.id,false); activate())
		if item.get("layout","") in ["letter","key"]:
			row.custom_minimum_size=Vector2(58 if item.get("layout","")=="key" else 84,46); row.value_label.hide()
			if item.get("layout","")=="key":
				for child in row.get_children(): child.hide()
				row.text=item.label; row.add_theme_font_size_override("font_size",18)
		rows.append(row)
	sidebar.visible = mode=="settings" and not preview
	section_bar.visible = mode=="settings" and not preview
	for i in range(sidebar_buttons.size()):
		sidebar_buttons[i].add_theme_stylebox_override("normal",MenuSkin.box(Color("353a40") if i==category else Color.TRANSPARENT,Color.TRANSPARENT,0,6))
		sidebar_buttons[i].add_theme_color_override("font_color",MenuSkin.TEXT if i==category else MenuSkin.MUTED)
	if mode=="settings":
		var pages: Array = catalog.pages(category)
		section_hint.text="LT / RT" if input_kind=="controller" else "Z / C"
		for child in section_tabs.get_children(): section_tabs.remove_child(child);child.queue_free()
		for i in range(pages.size()):
			var index: int = i
			var tab := Button.new()
			tab.text = str(pages[i].title)
			tab.focus_mode=Control.FOCUS_NONE
			tab.add_theme_font_size_override("font_size",20 if host.menu_large_text else 18)
			var tab_style := MenuSkin.box(Color.TRANSPARENT,MenuSkin.TEXT,0,6)
			tab_style.set_corner_radius_all(0)
			if i==subsection: tab_style.border_width_bottom=2
			tab.add_theme_stylebox_override("normal",tab_style)
			tab.add_theme_stylebox_override("pressed",tab_style)
			var hover_style: StyleBoxFlat=tab_style.duplicate(); hover_style.bg_color=Color("292d33")
			tab.add_theme_stylebox_override("hover",hover_style)
			tab.add_theme_color_override("font_color",MenuSkin.TEXT if i==subsection else MenuSkin.MUTED)
			tab.pressed.connect(func(): switch_section(index-subsection))
			section_tabs.add_child(tab)
		heading.text = CATEGORIES[category]
	else: heading.text = {"help":help_title,"launch":"Continue or start fresh?","recent":"Recently played","favourites":"Favourites","alphabet":"Jump to letter","music_browser":"Music & albums","pause":"CRT XR" if host.emulator.loaded else "Welcome to CRT XR","library":"Your game library","library_tools":"Library locations","games":library.Registry.SYSTEMS[library_system].name,"browser":"Browse games","volumes":"SD card volumes","drives":"Computer drives","slot":setup_name() if mode=="slot" else "","folder_path":"Open a folder", "rename":"Name your setup","confirm":"Please confirm","room_presets":"Lighting presets"}.get(mode,"CRT XR")
	confirm_panel.visible = mode=="confirm"
	if mode=="confirm": confirm_panel.describe(confirmation.title,confirmation.detail,confirmation.get("preview",""))
	rename_field.visible = mode in ["rename","radio_url","folder_path"]
	rename_field.max_length=2048 if mode in ["radio_url","folder_path"] else 32
	rename_field.placeholder_text="D:/roms or //server/share/roms" if mode=="folder_path" else "Direct MP3 stream URL" if mode=="radio_url" else "Name · Use on-screen keys or type"
	if mode=="rename" and not entry_initialized:
		rename_field.text = str(draft_names.get(host.selected_profile,setup_name())); entry_initialized=true
	search_field.visible = input_kind=="keyboard" and mode in ["games","recent","favourites"] and not preview
	if not search_field.visible and search_field.has_focus(): search_field.release_focus()
	body.visible = not preview
	compact.visible = preview
	subtitle.visible = not preview
	position = Vector2(36,522) if preview else Vector2(36,28)
	size = Vector2(888,170) if preview else Vector2(888,664)
	help_label.visible = not preview
	if preview: heading.add_theme_font_size_override("font_size",22)
	else: heading.add_theme_font_size_override("font_size",32)
	var saved: Dictionary = memory.get(state_key(),{})
	var preferred: String = selected_id if preview else str(saved.get("id",""))
	if mode=="library" and not scan_preferred_id.is_empty(): preferred=scan_preferred_id
	selected_id = ""
	for row in rows:
		if not row.disabled and (selected_id.is_empty() or row.item.id==preferred):
			selected_id = row.item.id
			if row.item.id==preferred: break
	rendering = false
	select(selected_id,false)
	style_rows()
	if mode=="launch":
		var preview_panel := Confirmation.new(); column.add_child(preview_panel); preview_panel.describe("Automatic resume",host.emulator.state_time(host.emulator.auto_path_for(launch_path)),host.emulator.auto_path_for(launch_path))
	if mode=="help":
		var article := Label.new(); article.text=help_copy; article.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; article.add_theme_font_size_override("font_size",24 if host.menu_large_text else 22); column.add_child(article)
	if mode=="library" and not rom_index.scanning: scan_preferred_id=""
	if saved.has("scroll") and not preview: restore_scroll.call_deferred(int(saved.scroll),layout_revision)
	fit_panel.call_deferred()
	refresh_labels()

func fit_panel() -> void:
	position = Vector2(36,522) if preview else Vector2(36,28)
	size = Vector2(888,170) if preview else Vector2(888,664)

func restore_scroll(value: int, revision: int) -> void:
	# Let wrapped text establish row heights before restoring the saved viewport.
	await get_tree().process_frame
	await get_tree().process_frame
	if revision!=layout_revision: return
	scroll.scroll_vertical = value

func selected_row():
	for row in rows:
		if row.item.id==selected_id: return row
	return null

func select(id: String, user_action := true) -> void:
	if rendering or selecting: return
	if user_action:
		scan_preferred_id=""; notification_time=0
	var candidate = null
	for row in rows:
		if row.item.id==id and not row.disabled: candidate=row
	if candidate==null: return
	selecting = true
	if user_action and selected_id!=id: play_menu_sound()
	selected_id = id
	for row in rows: row.set_selected(row==candidate)
	if not preview and not search_field.has_focus() and not rename_field.has_focus() and get_viewport().gui_get_focus_owner()!=candidate: candidate.grab_focus()
	if is_instance_valid(focus_tween): focus_tween.kill()
	for row in rows: row.modulate=Color.WHITE
	if user_action and not host.menu_reduced_motion:
		candidate.modulate=Color("d8d5cc")
		focus_tween=create_tween(); focus_tween.tween_property(candidate,"modulate",Color.WHITE,.10)
	selecting = false
	reveal_selected.call_deferred()
	refresh_labels()

func reveal_selected() -> void:
	var row = selected_row()
	if row!=null and not preview: scroll.ensure_control_visible(row)

func refresh_labels() -> void:
	if is_instance_valid(music_heading): music_heading.text=host.music.now_playing()
	var row = selected_row()
	var context: String = "Picture for "+host.emulator.rom_path.get_file() if not host.active_game_key.is_empty() else "Global picture"
	if mode=="pause":
		subtitle.text = host.emulator.rom_path.get_file() if host.emulator.loaded else status_title
		subtitle.tooltip_text=status_detail
	elif mode=="help": subtitle.text="Game library" if help_title=="Full game title" else "CRT XR · Help"
	elif mode=="music_browser": subtitle.text=music_dir+" · Page %d" % [music_page+1]
	elif mode=="radio_url": subtitle.text="Direct MP3 streams · On-screen keys or keyboard"
	elif mode=="browser": subtitle.text = library.current_dir
	elif mode=="library":
		subtitle.text = ("Finding your games… %d found · You can browse while we look" % rom_index.total()) if rom_index.scanning else (count_caption(rom_index.total(),"game")+" · "+count_caption(rom_index.games.values().filter(func(games): return not games.is_empty()).size(),"console")+" · Ready to play" if rom_index.total()>0 else "SNES · NES · Mega Drive · Master System · Game Gear")
	elif mode=="games":
		var count: int = game_entries().size()
		subtitle.text = count_caption(count,"game")
		if count>GAMES_PER_PAGE: subtitle.text += " · Page %d of %d" % [game_page+1,ceili(float(count)/GAMES_PER_PAGE)]
	elif mode in ["recent","favourites"]:
		subtitle.text = count_caption(history_paths().size(),"game")
	elif mode=="launch": subtitle.text = launch_path.get_file().get_basename()
	elif mode=="library_tools": subtitle.text = host.default_rom_dir if not host.default_rom_dir.is_empty() else "Choose the main roms folder, once"
	elif mode=="settings":
		if category==1: subtitle.text=context+" · "+preset_caption()
		elif category==2: subtitle.text=["Game volume and TV sound", "Lower game audio while music plays", host.music.status, "Place music in the room"][subsection]
		else: subtitle.text="Global settings · • Changed from default"
	elif mode=="slot": subtitle.text = "Setup slot %d  ·  %s" % [host.selected_profile+1,str(draft_names.get(host.selected_profile,setup_name()))]
	else: subtitle.text = "CRT XR"
	if mode in ["games","recent","favourites"] and not search_query.is_empty(): subtitle.text += " · Search: "+search_query
	if notification_time>0 and notification_context==state_key(): help_label.text = notification
	elif mode=="help": help_label.text=""
	elif mode=="favourites" and items.is_empty(): help_label.text = "No favourites yet. Select a game in Recently played or a system list and press X. B returns."
	elif mode=="library" and not rom_index.message.is_empty(): help_label.text=rom_index.message
	elif mode=="library" and host.default_rom_dir.is_empty(): help_label.text="Choose Set up your ROM library and select your main ROM folder. Your supported consoles appear here automatically."
	elif mode=="library" and not rom_index.scanning and rom_index.total()==0: help_label.text="No supported cartridges here yet. Check Library locations. Use uncompressed SNES, NES or Sega cartridges; archives and discs are not supported."
	elif row!=null: help_label.text = str(row.item.get("help",""))
	else: help_label.text = library.message if mode=="browser" else "Nothing to select. B returns."
	if preview and row!=null: compact.text = "▸  %s    ‹  %s  ›" % [row.item.label,row.formatted_value()]
	refresh_hints(row)

func preview_available() -> bool:
	if mode!="settings": return false
	return items.any(func(item): return item.get("visual",false) and not item.get("disabled",false) and item.kind!="action")

func count_caption(count: int, noun: String) -> String:
	return "%d %s%s" % [count,noun,"" if count==1 else "s"]

func refresh_hints(row) -> void:
	var pad := input_kind=="controller"
	hints.controller=pad
	var back_caption := ("Return to game" if host.emulator.loaded else "Close menu") if mode=="pause" else "Back"
	back_button.text=back_caption+("" if pad else "  [Backspace]")
	back_glyph.visible=pad
	sidebar.get_node("CategoryHint").text="LB / RB · Categories" if pad else "Q / E · Categories"
	preview_button.visible=preview_available() and not preview
	preview_button.text="Preview" if pad else "Preview  X"
	preview_glyph.visible=pad and preview_button.visible
	if mode=="settings":
		var parts: Array[String]=["↑↓ Select"]
		if row!=null:
			if row.item.kind!="action": parts.append("←→ Adjust")
			else: parts.append("A Open" if pad else "Enter Open")
			if row.item.has("default"): parts.append("Y Reset")
		if preview: parts.append("B Settings" if pad else "Backspace Settings")
		hints.text=" · ".join(parts)
	elif mode in ["games","recent","favourites"]:
		hints.text="↑↓ Select · "+("A Open" if pad else "Enter Open")
		if row!=null and row.item.has("rom_path"): hints.text+=" · X Favourite · "+("Y Full title" if search_query.is_empty() else "Y Clear search")
	elif mode=="browser": hints.text="↑↓ Select · "+("A Open · B Back · RB Set folder" if pad else "Enter Open · Backspace Back")
	elif mode=="help": hints.text="↑↓ Scroll · "+("B Back" if pad else "Backspace Back")
	elif mode=="library": hints.text="D-pad Select · A Open · B Back · RB Refresh" if pad else "Arrows Select · Enter Open · Backspace Back · R Refresh"
	elif mode=="pause": hints.text="↑↓ Select · "+("A Open · B "+back_caption if pad else "Enter Open · Backspace "+back_caption)
	elif mode in ["folder_path","rename","radio_url"]: hints.text="D-pad Keys · A Type · B Back" if pad else "Type or click keys · Enter Submit · Backspace Back"
	else: hints.text="D-pad Select · A Open · B Back" if pad else "Arrows Select · Enter Open · Backspace Back"

func navigate_library(next: Vector2i) -> void:
	var row=selected_row()
	if row==null: return
	var x: int=row.item.nav_col
	var y: int=row.item.nav_row
	if next.x!=0:
		var closest=null
		for candidate in rows:
			if candidate.disabled or candidate.item.nav_row!=y: continue
			var dx:int=candidate.item.nav_col-x
			if signi(dx)!=next.x: continue
			if closest==null or absi(dx)<absi(int(closest.item.nav_col)-x): closest=candidate
		if closest!=null: select(closest.item.id)
	elif next.y!=0:
		var target := y+next.y
		var last_row := 0
		for candidate in rows: last_row=maxi(last_row,candidate.item.nav_row)
		while target>=0 and target<=last_row:
			var closest=null
			for candidate in rows:
				if candidate.disabled or candidate.item.nav_row!=target: continue
				if closest==null or abs(candidate.item.nav_col-x)<abs(closest.item.nav_col-x): closest=candidate
			if closest!=null: select(closest.item.id); return
			target+=next.y

func navigate(next: Vector2i) -> void:
	if mode=="help": scroll.scroll_vertical+=next.y*80; return
	if mode in ["library","alphabet"]: navigate_library(next); return
	if mode in ["rename","folder_path","radio_url"] and input_kind=="controller":
		navigate_keys(next); return
	var index := -1
	for i in range(rows.size()):
		if rows[i].item.id==selected_id: index=i
	if index<0: return
	if next.y!=0:
		var candidate := index+next.y
		if rows[index].item.get("layout","")=="transport":
			while candidate>=0 and candidate<rows.size() and rows[candidate].item.get("layout","")=="transport": candidate+=next.y
		while candidate>=0 and candidate<rows.size():
			if not rows[candidate].disabled:
				if rows[candidate].item.get("layout","")=="transport": select("transport.play")
				else: select(rows[candidate].item.id)
				return
			candidate+=next.y
	elif next.x!=0:
		if mode=="pause" and rows[index].item.get("layout","")=="transport":
			var candidate := index+next.x
			while candidate>=0 and candidate<rows.size() and rows[candidate].item.get("layout","")=="transport":
				if not rows[candidate].disabled: select(rows[candidate].item.id); return
				candidate+=next.x
		elif mode in ["browser","games","recent","favourites"]: jump_entries(next.x*10)
		else: adjust(next.x)

func jump_entries(amount: int) -> void:
	if mode=="games":
		var games := game_entries()
		if games.is_empty(): return
		var current := game_page*GAMES_PER_PAGE
		for i in range(games.size()):
			if "game:"+str(games[i].path)==selected_id: current=i; break
		var target := clampi(current+amount,0,games.size()-1)
		remember(); game_page=target/GAMES_PER_PAGE; system_pages[library_system]=game_page
		render(); select("game:"+str(games[target].path)); return
	var candidates: Array = []
	for row in rows:
		if row.disabled: continue
		if mode=="browser" and not str(row.item.id).begins_with("file:"): continue
		if mode in ["recent","favourites"] and row.item.get("layout","")!="game": continue
		candidates.append(row.item.id)
	if candidates.is_empty(): return
	var current := candidates.find(selected_id)
	var target := clampi((current if current>=0 else 0)+amount,0,candidates.size()-1)
	select(candidates[target])

func adjust(delta: int) -> void:
	var row = selected_row()
	if row!=null and row.item.kind=="seek":
		row.item.setter.call(float(row.item.getter.call())+10*delta); row.refresh(); return
	if mode!="settings": return
	if row==null or row.disabled: return
	var item: Dictionary = row.item
	match item.kind:
		"number": item.setter.call(clampf(snappedf(float(item.getter.call())+delta*float(item.step),float(item.step)),item.min,item.max))
		"choice": item.setter.call(posmod(int(item.getter.call())+delta,item.choices.size()))
		"toggle": item.setter.call(delta>0)
	row.refresh(); notify("Changed · Saved when you close the menu")

func activate() -> void:
	var row=selected_row()
	if row==null or row.disabled: return
	if row.item.kind=="action":
		play_menu_sound(true)
		row.item.action.call()
	elif row.item.kind=="seek": pass
	elif row.item.kind=="toggle": adjust(-1 if bool(row.item.getter.call()) else 1)
	elif row.item.get("visual",false) and not preview: toggle_preview()
	else: adjust(1)
	refresh_labels()

func reset_option() -> void:
	var row = selected_row()
	if row==null or row.disabled or not row.item.has("default"): return
	row.item.setter.call(row.item.default)
	row.refresh(); notify("Selected option restored to its default")

func toggle_preview() -> void:
	if mode!="settings": return
	if preview:
		remember(); preview=false; clear_input(); render(); return
	if not preview_available(): return
	var row=selected_row()
	if row==null or row.disabled or not row.item.get("visual",false):
		for candidate in rows:
			if not candidate.disabled and candidate.item.get("visual",false):
				select(candidate.item.id,false); break
	remember(); preview=true; clear_input(); render()

func notify(message: String) -> void:
	notification = message; notification_time=4.0; notification_context=state_key()
	refresh_labels()

func show_error(message: String) -> void:
	error_label.text=message; error_label.show()

func clear_input() -> void:
	direction=Vector2i.ZERO; repeat_remaining=0
	dpad.clear()
	for button in held:
		if held[button]: blocked[button]=true
	stick_blocked = stick.length()>.55
	default_armed=false

func release_input(event: InputEvent) -> void:
	# Releases can arrive after an action closes the menu. Keep the latch honest
	# without dispatching actions to a hidden screen.
	if event is InputEventJoypadButton and not event.pressed:
		held[event.button_index]=false
		blocked.erase(event.button_index)
	if not visible and event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT] and event.axis_value<.25:
			triggers[event.axis]=false
		if event.axis==JOY_AXIS_LEFT_X: stick.x=event.axis_value
		if event.axis==JOY_AXIS_LEFT_Y: stick.y=event.axis_value

func handle(event: InputEvent) -> bool:
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>.55):
		set_input_kind("controller")
	if event is InputEventMouse:
		set_input_kind("keyboard"); return false
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if device!=event.device:
			clear_input(); held.clear(); blocked.clear(); stick=Vector2.ZERO; stick_blocked=false; triggers.clear()
			device=event.device
	if event is InputEventJoypadButton:
		held[event.button_index]=event.pressed
		if not event.pressed:
			blocked.erase(event.button_index)
			if mode=="browser" and event.button_index==JOY_BUTTON_RIGHT_SHOULDER:
				if default_armed: set_default(library.current_dir)
				default_armed=false
		elif blocked.has(event.button_index): return true
		if event.button_index in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
			dpad[event.button_index]=event.pressed; update_direction(); return true
		if not event.pressed: return true
		match event.button_index:
			JOY_BUTTON_A: activate()
			JOY_BUTTON_B: back()
			JOY_BUTTON_Y:
				if mode=="browser": open_default()
				elif mode in ["games","recent","favourites"]: game_title_action()
				else: reset_option()
			JOY_BUTTON_X:
				if mode=="browser": open_cards()
				elif mode in ["games","recent","favourites"]: toggle_favourite()
				else: toggle_preview()
			JOY_BUTTON_RIGHT_STICK: host.recenter()
			JOY_BUTTON_LEFT_SHOULDER:
				if mode=="browser": default_armed=false; open_folder(library.current_dir.get_base_dir())
				elif mode=="games": change_game_page(-1)
				else: switch_category(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				if mode=="browser": default_armed=not held.get(JOY_BUTTON_LEFT_SHOULDER,false)
				elif mode=="games": change_game_page(1)
				elif mode=="library": refresh_library()
				else: switch_category(1)
		return true
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			if event.axis_value<.25: triggers[event.axis]=false
			elif event.axis_value>.65 and not triggers.get(event.axis,false):
				triggers[event.axis]=true
				switch_section(-1 if event.axis==JOY_AXIS_TRIGGER_LEFT else 1)
		elif event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			if event.axis==JOY_AXIS_LEFT_X: stick.x=event.axis_value
			else: stick.y=event.axis_value
			if stick.length()<.25: stick_blocked=false
			update_direction()
		return true
	if event is InputEventKey:
		set_input_kind("keyboard")
		if mode in ["games","recent","favourites"]:
			if event.pressed and not event.echo and event.ctrl_pressed and event.physical_keycode==KEY_F:
				clear_input(); search_field.grab_focus(); return true
			if search_field.has_focus():
				if event.pressed and event.physical_keycode in [KEY_DOWN,KEY_UP,KEY_ENTER,KEY_KP_ENTER]:
					search_field.release_focus(); select(selected_id,false); return true
				return false
		if mode in ["rename","radio_url","folder_path"] and get_viewport().gui_get_focus_owner()==rename_field:
			if event.pressed and event.physical_keycode==KEY_DOWN:
				select("folder_path.open" if mode=="folder_path" else ("radio.save" if mode=="radio_url" else "rename.save")); return true
			return false
		var moves := {KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN,KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT}
		if moves.has(event.physical_keycode):
			if event.pressed and not event.echo: direction=moves[event.physical_keycode]; repeat_remaining=.35; navigate(direction)
			elif not event.pressed: direction=Vector2i.ZERO
			return true
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ENTER,KEY_SPACE: activate()
				KEY_BACKSPACE: back()
				KEY_Y:
					if mode in ["games","recent","favourites"]: game_title_action()
					else: reset_option()
				KEY_X:
					if mode in ["games","recent","favourites"]: toggle_favourite()
					else: toggle_preview()
				KEY_J:
					if mode in ["games","recent","favourites"]: open_alphabet()
				KEY_R:
					if mode=="library": refresh_library()
				KEY_TAB:
					switch_category(-1 if event.shift_pressed else 1)
				KEY_Q:
					switch_category(-1)
				KEY_E:
					switch_category(1)
				KEY_Z:
					switch_section(-1)
				KEY_C:
					switch_section(1)
		return true
	return false

func update_direction() -> void:
	var next := Vector2i(int(dpad.get(JOY_BUTTON_DPAD_RIGHT,false))-int(dpad.get(JOY_BUTTON_DPAD_LEFT,false)),int(dpad.get(JOY_BUTTON_DPAD_DOWN,false))-int(dpad.get(JOY_BUTTON_DPAD_UP,false)))
	if next==Vector2i.ZERO and not stick_blocked and stick.length()>.55:
		next = Vector2i(int(signf(stick.x)),0) if absf(stick.x)>absf(stick.y) else Vector2i(0,int(signf(stick.y)))
	if next!=direction:
		direction=next; repeat_remaining=.35
		if next!=Vector2i.ZERO: navigate(next)

func _process(delta: float) -> void:
	scan_refresh_elapsed+=delta
	if mode=="library" and rom_index.scanning and scan_refresh_elapsed>.25 and scan_revision!=rom_index.revision:
		scan_refresh_elapsed=0; scan_revision=rom_index.revision; remember(); render()
	if rom_index.scanning and rom_index.step():
		if mode in ["library","games"]:
			remember(); render()
	if preview and size.y>190: fit_panel()
	if direction!=Vector2i.ZERO:
		repeat_remaining-=delta
		if repeat_remaining<=0: navigate(direction); repeat_remaining=.10
	notification_time=maxf(0,notification_time-delta)
	refresh_elapsed+=delta
	if refresh_elapsed>=.1:
		refresh_elapsed=0
		for row in rows: row.refresh()
		refresh_labels()

func set_input_kind(kind: String) -> void:
	if kind==input_kind: return
	input_kind=kind
	search_field.visible=kind=="keyboard" and mode in ["games","recent","favourites"]
	if kind=="controller" and search_field.has_focus():
		search_field.release_focus(); select(selected_id,false)
	if mode=="settings": section_hint.text="LT / RT" if kind=="controller" else "Z / C"
	refresh_labels()

func update_search(value: String) -> void:
	remember(); clear_input(); search_query=value; game_page=0; render()

func game_entries() -> Array:
	var games: Array=rom_index.games.get(library_system,[])
	if search_query.is_empty(): return games
	return games.filter(func(game): return str(game.label).to_lower().contains(search_query.to_lower()))

func history_paths() -> Array:
	var paths: Array=host.play_history.recent if mode=="recent" else host.play_history.favourites
	if search_query.is_empty(): return paths
	return paths.filter(func(path): return str(path).get_file().get_basename().to_lower().contains(search_query.to_lower()))

func open_alphabet() -> void:
	if mode not in ["games","recent","favourites"]: return
	remember(); clear_input(); alphabet_origin=mode; mode="alphabet"; render()

func alphabet_entries() -> Array:
	if alphabet_origin=="games": return game_entries()
	var paths: Array=host.play_history.recent if alphabet_origin=="recent" else host.play_history.favourites
	var result: Array=[]
	for path in paths:
		var label: String=str(path).get_file().get_basename()
		if label.to_lower().contains(search_query.to_lower()): result.append({"path":path,"label":label})
	return result

func letter_for(label: String) -> String:
	var letter:=label.left(1).to_upper()
	return letter if letter>="A" and letter<="Z" else "#"

func jump_to_letter(letter: String) -> void:
	var entries:=alphabet_entries()
	for i in range(entries.size()):
		if letter_for(str(entries[i].label))!=letter: continue
		remember(); clear_input(); mode=alphabet_origin
		if mode=="games": game_page=i/GAMES_PER_PAGE; system_pages[library_system]=game_page
		selected_id="game:"+str(entries[i].path)
		memory[state_key()]={"id":selected_id,"scroll":0}
		render(); return

func picture_signature() -> String:
	var config := ConfigFile.new()
	host.SettingsStore.copy_sections(host.capture_settings(),config,host.PICTURE_SECTIONS)
	return config.encode_to_text()

func applied_preset() -> String:
	return host.picture_preset_id if not host.picture_preset_signature.is_empty() and host.picture_preset_signature==picture_signature() else ""

func preset_caption() -> String:
	var id := applied_preset()
	return "Custom" if id.is_empty() else "✓ "+["Deck Showcase (PAL)","Clean source","RGB CRT","Auto composite","PAL composite","NTSC composite"][PRESET_IDS.find(id)]

func apply_preset(id: String) -> void:
	picture_undo=host.capture_settings()
	host.apply_picture_preset(id)
	host.picture_preset_id=id; host.picture_preset_signature=picture_signature()
	refresh(); notify("Picture preset applied · Undo available on Picture → Presets")

func undo_picture_preset() -> void:
	if picture_undo==null: return
	var merged: ConfigFile=host.capture_settings()
	host.SettingsStore.copy_sections(picture_undo,merged,host.PICTURE_SECTIONS)
	merged.set_value("menu","picture_preset_id",picture_undo.get_value("menu","picture_preset_id",""))
	merged.set_value("menu","picture_preset_signature",picture_undo.get_value("menu","picture_preset_signature",""))
	host.apply_settings(merged); picture_undo=null
	refresh(); notify("Previous picture restored")

func open_help(title: String, copy: String) -> void:
	remember(); help_origin=snapshot(); help_title=title; help_copy=copy
	mode="help"; clear_input(); render()

func game_title_action() -> void:
	if not search_query.is_empty():
		search_field.text=""; update_search(""); return
	var row=selected_row()
	if row!=null and row.item.has("rom_path"):
		open_help("Full game title",str(row.item.label))

func apply_accessibility() -> void:
	host.power_on.reduced_motion=host.menu_reduced_motion
	if host.menu_reduced_motion and is_instance_valid(focus_tween): focus_tween.kill()
	refresh()

func style_rows() -> void:
	for row in rows:
		if row.item.get("layout","") in ["transport","card"]: continue
		row.title_label.add_theme_font_size_override("font_size",27 if host.menu_large_text else 24)
		row.value_label.add_theme_font_size_override("font_size",25 if host.menu_large_text else 22)
		row.sync_content_height()
		if host.menu_high_contrast:
			row.title_label.add_theme_color_override("font_color",Color.WHITE)
			row.value_label.add_theme_color_override("font_color",Color.WHITE)
			row.unavailable_label.add_theme_color_override("font_color",Color("dddddd"))
	if host.menu_high_contrast: add_theme_stylebox_override("panel",MenuSkin.box(Color("080a0d"),Color("cccccc"),1,18))
	else: remove_theme_stylebox_override("panel")

func focus_entry() -> void:
	if input_kind=="keyboard": rename_field.grab_focus()
	else: rename_field.release_focus()

func text_keys() -> Array:
	var result: Array=[]
	var letters := "abcdefghijklmnopqrstuvwxyz0123456789:/._-\\?=&%#@+~"
	if caps: letters=letters.to_upper()
	for i in range(letters.length()):
		var character := letters.substr(i,1)
		var key := catalog.action("key.%d" % i,character,func(): insert_text(character),"Insert at the cursor.",false,"")
		key.layout="key"; result.append(key)
	for pair in [["space","Space"],["erase","Delete"],["caps","Aa"],["left","←"],["right","→"]]:
		var command: String=pair[0]
		var key := catalog.action("key."+command,pair[1],func(): edit_text(command),"Edit the text above.",false,"")
		key.layout="key"; result.append(key)
	return result

func insert_text(value: String) -> void:
	var start := rename_field.get_selection_from_column() if rename_field.has_selection() else rename_field.caret_column
	var end := rename_field.get_selection_to_column() if rename_field.has_selection() else start
	var available := rename_field.max_length-(rename_field.text.length()-(end-start))
	var inserted := value.left(maxi(0,available))
	rename_field.text=rename_field.text.left(start)+inserted+rename_field.text.substr(end)
	rename_field.caret_column=start+inserted.length()

func edit_text(command: String) -> void:
	match command:
		"space": insert_text(" ")
		"erase": rename_field.delete_char_at_caret()
		"left": rename_field.caret_column=maxi(0,rename_field.caret_column-1)
		"right": rename_field.caret_column=mini(rename_field.text.length(),rename_field.caret_column+1)
		"caps":
			var cursor := rename_field.caret_column
			caps=not caps; remember(); render()
			rename_field.caret_column=cursor

func navigate_keys(next: Vector2i) -> void:
	var keys: Array=rows.filter(func(row): return row.item.get("layout","")=="key")
	var row=selected_row()
	if row==null: return
	if row.item.get("layout","")=="key":
		var index := keys.find(row)
		var target := index+(next.x if next.x!=0 else next.y*10)
		if target>=keys.size() and next.y>0:
			for candidate in rows:
				if candidate.item.get("layout","")!="key": select(candidate.item.id); return
		if target>=0 and target<keys.size(): select(keys[target].item.id)
	elif next.y<0 and not keys.is_empty(): select(keys[-1].item.id)
	elif next.y>0:
		var index := rows.find(row)+1
		if index<rows.size(): select(rows[index].item.id)

func play_menu_sound(confirm := false) -> void:
	if not host.menu_sounds or sound_player==null: return
	var samples := PackedByteArray()
	var count := 1323 if confirm else 660
	samples.resize(count*2)
	for i in range(count):
		var wave := sin(float(i)*TAU*(660.0 if confirm else 440.0)/22050.0)*.25*(1.0-float(i)/count)
		samples.encode_s16(i*2,int(wave*32767))
	var sound := AudioStreamWAV.new(); sound.format=AudioStreamWAV.FORMAT_16_BITS; sound.mix_rate=22050; sound.data=samples
	sound_player.stream=sound; sound_player.play()
