extends PanelContainer
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const Row = preload("res://scripts/ui/setting_row.gd")
const LibraryCard = preload("res://scripts/ui/library_card.gd")
const GameRow = preload("res://scripts/ui/library_game_row.gd")
const ActionRow = preload("res://scripts/ui/action_row.gd")
const Catalog = preload("res://scripts/ui/menu_catalog.gd")
const Library = preload("res://scripts/ui/rom_library.gd")
const RomIndex = preload("res://scripts/content/rom_index.gd")
const Confirmation = preload("res://scripts/ui/confirmation_panel.gd")
const CATEGORIES := ["View","Picture","Room","Controls & XR","Saved setups"]
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
var category := 0
var subsection := 0
var sections: Dictionary = {}
var memory: Dictionary = {}
var selected_id := ""
var items: Array = []
var rows: Array = []
var preview := false
var editing := false
var heading: Label
var subtitle: Label
var help_label: Label
var hints: Label
var error_label: Label
var body: HBoxContainer
var sidebar: VBoxContainer
var section_bar: VBoxContainer
var section_title: Label
var section_tabs: HFlowContainer
var scroll: ScrollContainer
var column: VBoxContainer
var compact: Label
var confirm_panel: PanelContainer
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
var selecting := false
var scan_refresh_elapsed := 0.0
var scan_revision := -1
var scan_preferred_id := ""
var refresh_elapsed := 0.0
var notification := ""
var notification_time := 0.0
var status_title := "Choose a game"
var status_detail := "Open a SNES, NES or Sega game, or adjust the test signal."
var confirmation: Dictionary = {}
var return_state: Dictionary = {}
var draft_names: Dictionary = {}

func _ready() -> void:
	theme = MenuSkin.create()
	position = Vector2(36,28)
	size = Vector2(888,664)
	catalog.host = host; catalog.menu = self
	library.default_dir = host.default_rom_dir
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",8)
	add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	heading = Label.new(); heading.text = "RetroCRT XR"
	heading.add_theme_font_size_override("font_size",32)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var back_button := Button.new(); back_button.text = "Back  [B]"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(back)
	top.add_child(back_button)
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
	rename_field.placeholder_text = "Optional name; keyboard entry"
	rename_field.text_submitted.connect(func(_text): save_draft_name())
	layout.add_child(rename_field); rename_field.hide()
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation",16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 176
	sidebar.add_theme_constant_override("separation",8)
	body.add_child(sidebar)
	for i in range(CATEGORIES.size()):
		var index := i
		var button := Button.new()
		button.text = CATEGORIES[i]
		button.add_theme_font_size_override("font_size",20)
		button.custom_minimum_size.y = 52
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): switch_category(index-category))
		sidebar.add_child(button); sidebar_buttons.append(button)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	body.add_child(content)
	section_bar = VBoxContainer.new()
	section_bar.add_theme_constant_override("separation",6)
	content.add_child(section_bar)
	var section_navigation := HBoxContainer.new()
	section_bar.add_child(section_navigation)
	for dir in [-1,1]:
		var button := Button.new()
		button.text = "‹ LT" if dir<0 else "RT ›"
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): switch_section(dir))
		if dir==1:
			section_title = Label.new()
			section_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			section_title.add_theme_color_override("font_color",MenuSkin.AMBER)
			section_navigation.add_child(section_title)
		section_navigation.add_child(button)
	section_tabs = HFlowContainer.new()
	section_tabs.add_theme_constant_override("h_separation",5)
	section_tabs.add_theme_constant_override("v_separation",5)
	section_bar.add_child(section_tabs)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = false
	content.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",6)
	scroll.add_child(column)
	compact = Label.new()
	compact.add_theme_font_size_override("font_size",26)
	compact.add_theme_color_override("font_color",MenuSkin.AMBER)
	layout.add_child(compact); compact.hide()
	help_label = Label.new()
	help_label.custom_minimum_size.y = 64
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.max_lines_visible = 2
	help_label.add_theme_font_size_override("font_size",20)
	layout.add_child(help_label)
	hints = Label.new()
	hints.add_theme_font_size_override("font_size",18)
	hints.add_theme_color_override("font_color",MenuSkin.MUTED)
	layout.add_child(hints)
	visibility_changed.connect(func(): set_process(visible))
	open_pause()
	hide()

func state_key() -> String:
	match mode:
		"settings": return "settings:%d:%d" % [category,subsection]
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
	selected_id = "resume" if host.emulator.loaded else "games"
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
	if editing:
		finish_edit(); return
	if preview:
		remember(); preview = false; clear_input(); render(); return
	remember(); clear_input()
	match mode:
		"pause": host.close_settings()
		"settings", "library": mode="pause"; render()
		"library_tools": mode="library"; render()
		"browser", "volumes", "drives": mode="library_tools"; render()
		"games", "recent", "favourites": mode="library"; render()
		"launch": restore(launch_origin)
		"slot", "room_presets": mode="settings"; render()
		"rename": mode="slot"; render()
		"confirm": restore(return_state)

func ask(title: String, detail: String, callback: Callable) -> void:
	remember(); return_state = snapshot(); clear_input()
	confirmation = {"title":title,"detail":detail,"callback":callback}
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
		if host.save_profile(title): refresh()
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
	var result: Array = [
		card(catalog.action("library.recent","Recently played",func(): open_history("recent"),"Return to your latest games. Unplugged-card entries are kept.",h.play_history.recent.is_empty(),"%d game%s" % [h.play_history.recent.size(),"" if h.play_history.recent.size()==1 else "s"]),"PICK UP & PLAY","recent",MenuSkin.AMBER,"QUICK ACCESS"),
		card(catalog.action("library.favourites","Favourites",func(): open_history("favourites"),"Your favourites across every supported console. Press X on a game to add it.",h.play_history.favourites.is_empty(),"%d game%s" % [h.play_history.favourites.size(),"" if h.play_history.favourites.size()==1 else "s"]),"YOUR PERSONAL SHELF","favourites",Color("dfb984"),"QUICK ACCESS")]
	var identity := {"snes":["NINTENDO · 16-BIT","ba9fdb"],"nes":["NINTENDO · 8-BIT","dc9b8e"],"megadrive":["SEGA · 16-BIT","8ebfdc"],"mastersystem":["SEGA · 8-BIT","9ac4ab"],"gamegear":["SEGA · HANDHELD","d4bb7d"]}
	for system in library.Registry.SYSTEMS:
		var id: String=system
		var count: int=rom_index.games.get(id,[]).size()
		if count==0: continue
		result.append(card(catalog.action("library.system."+id,library.Registry.SYSTEMS[id].name,func(): open_system(id),"Open all %s cartridges in your library. Folders for other consoles stay out of this view." % library.Registry.SYSTEMS[id].name,false,"%d game%s" % [count,"" if count==1 else "s"]),identity[id][0],id,Color(identity[id][1]),"YOUR CONSOLES"))
	var detail := "Choose your main ROM folder" if h.default_rom_dir.is_empty() else "Folders · SD cards · Refresh"
	result.append(card(catalog.action("library.locations","Library locations",open_library_tools,"Set the main roms folder once. RetroCRT finds supported consoles and leaves the files where they are.",false,detail),"MAKE YOURSELF AT HOME","locations",Color("aeb6bf"),"YOUR CONSOLES" if rom_index.total()>0 else "LIBRARY"))
	return result

func refresh_library() -> void:
	var previous := selected_id
	remember(); clear_input(); error_label.hide()
	rom_index.start(host.default_rom_dir)
	scan_preferred_id=previous if mode=="library" else ""
	render()

func open_system(system: String) -> void:
	remember(); clear_input()
	library_system=system; game_page=int(system_pages.get(system,0))
	var count: int = rom_index.games.get(system,[]).size()
	game_page=clampi(game_page,0,maxi(0,(count-1)/GAMES_PER_PAGE))
	mode="games"; render()

func change_game_page(delta: int) -> void:
	var count: int = rom_index.games.get(library_system,[]).size()
	var next := clampi(game_page+delta,0,maxi(0,(count-1)/GAMES_PER_PAGE))
	if next==game_page: return
	remember(); clear_input(); game_page=next; system_pages[library_system]=game_page
	render()

func open_folder(path: String) -> void:
	remember(); clear_input()
	if not library.show_folder(path): show_error(library.message); return
	error_label.hide()
	mode="browser"; render()

func browse_folders() -> void:
	var candidates := [library.current_dir,host.default_rom_dir,host.last_game_path.get_base_dir(),library.home_folder()]
	for path in candidates:
		if not str(path).is_empty() and DirAccess.open(path)!=null:
			open_folder(path); return
	show_error("No available folder could be opened.")

func open_default() -> void:
	if host.default_rom_dir.is_empty(): show_error("No default folder yet. Browse to your ROM folder and press R1.")
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
	remember(); clear_input(); mode=which; render()

func game_item(path: String, label: String) -> Dictionary:
	var item: Dictionary = catalog.action("game:"+path,label,func(): select_file(path),"A opens this cartridge. X adds or removes it from Favourites.",false,"★" if path in host.play_history.favourites else "›")
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
		ask("Load manual save?","Current progress will be replaced. %s • Slot 0 • %s" % [host.emulator.rom_path.get_file().get_basename(),host.emulator.state_time(host.emulator.state_path())],func(): perform_state_action(false))
		return
	perform_state_action(true)

func perform_state_action(saving: bool) -> void:
	var succeeded: bool = host.emulator.save_state() if saving else host.emulator.load_state()
	if succeeded:
		notify(host.emulator.status)
		host.show_notice(host.emulator.status)
	else: show_error(host.emulator.status+". Check the save folder and available storage.")
	refresh()

func get_items() -> Array:
	var h = host
	match mode:
		"pause": return [
			catalog.action("resume","Resume",h.close_settings,"Return to the game with your settings saved.",not h.emulator.loaded),
			catalog.action("games","Choose game",open_library,"Open your recent game, default ROM folder or SD card."),
			catalog.action("save_state","Save state",func(): state_action(true),"Saves the current game to state slot 0.",not h.emulator.loaded),
			catalog.action("load_state","Load state",func(): state_action(false),"Restores state slot 0 for the current game.",not h.emulator.loaded or not FileAccess.file_exists(h.emulator.state_path())),
			catalog.action("screenshot","Screenshot",h.take_screenshot,"Saves a clean single-eye image without menus or diagnostics."),
			catalog.action("settings","Settings",open_settings,"Adjust the view, picture, room, controls and saved setups."),
			catalog.action("exit","Exit RetroCRT",func(): ask("Exit RetroCRT?","An automatic resume point, settings and cartridge SRAM will be saved.",h.request_exit),"Close the application.")]
		"launch": return [
			catalog.action("launch.continue","Continue",func(): launch_game(launch_path,true),launch_path.get_file()+" • Automatic save • "+h.emulator.state_time(h.emulator.auto_path_for(launch_path))),
			catalog.action("launch.fresh","Start fresh",func(): launch_game(launch_path,false),"Start from the title screen. Cartridge battery saves and manual states are kept."),
			catalog.action("launch.cancel","Back",back,"Return without starting this game.")]
		"recent", "favourites":
			var result: Array = []
			var paths: Array = h.play_history.recent if mode=="recent" else h.play_history.favourites
			for path in paths: result.append(game_item(path,path.get_file().get_basename()))
			return result
		"settings": return catalog.pages(category)[subsection].rows
		"library": return library_items()
		"library_tools":
			return [
			catalog.action("library.refresh","Refresh library",refresh_library,"Rescans the saved ROM folder for added or removed cartridges.",h.default_rom_dir.is_empty()),
			catalog.action("library.default","ROM library folder",open_default,h.default_rom_dir if not h.default_rom_dir.is_empty() else "Browse to the main roms folder (containing snes, nes, megadrive, etc.), then press R1."),
			catalog.action("library.sd","SD card",open_cards,"Browse a mounted Steam Deck SD card."),
			catalog.action("library.browse","Browse folders",browse_folders,"Browse folders on this computer."),
			catalog.action("library.drives","Computer drives",func(): remember(); clear_input(); mode="drives"; render(),"Choose a drive, then browse to your ROM folder.",OS.get_name()!="Windows"),
			catalog.action("library.clear","Clear default folder",func(): set_default(""),"Forget the default folder without changing any files.",h.default_rom_dir.is_empty())]
		"games":
			var result: Array = []
			var games: Array = rom_index.games.get(library_system,[])
			for game in games.slice(game_page*GAMES_PER_PAGE,(game_page+1)*GAMES_PER_PAGE):
				var path: String = game.path
				result.append(game_item(path,game.label))
			if games.size()>GAMES_PER_PAGE:
				result.append(catalog.action("games.previous","Previous page",func(): change_game_page(-1),"Also available with L1 or Left.",game_page==0))
				result.append(catalog.action("games.next","Next page",func(): change_game_page(1),"Also available with R1 or Right.",(game_page+1)*GAMES_PER_PAGE>=games.size()))
			return result
		"browser":
			var result: Array = []
			for entry in library.entries:
				var path: String = entry.path
				var folder: bool = entry.folder
				result.append(catalog.action("file:"+path,entry.label,func():
					if folder: open_folder(path)
					else: select_file(path),path,false,"Folder" if folder else entry.get("system","Game")))
			result.append(catalog.action("folder.home","Home folder",func(): open_folder(library.home_folder()),"Browse your home folder."))
			result.append(catalog.action("folder.remember","Set as default",func(): set_default(library.current_dir),"Remember this folder as the default ROM location. Also available on R1."))
			return result
		"drives":
			var result: Array = []
			for index in range(DirAccess.get_drive_count()):
				var path := DirAccess.get_drive_name(index)
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
				catalog.action("slot.rename","Name for next save",func(): mode="rename"; clear_input(); render(); rename_field.grab_focus(),"Optional keyboard entry. Default names work with a controller."),
				catalog.action("slot.undo","Undo last setup load",h.undo_profile,"Restores the settings from before the last setup load.",h.profile_undo==null)]
		"rename": return [catalog.action("rename.save","Use this name",save_draft_name,"The new name is stored when you save the setup."),catalog.action("rename.cancel","Cancel",back,"Leave the name unchanged.")]
		"confirm": return [catalog.action("cancel","Cancel",back,"Keep things as they are."),catalog.action("confirm","Confirm",confirmed,confirmation.detail)]
	return []

func render() -> void:
	if not is_instance_valid(column) or not visible: return
	editing=false
	rendering = true
	items = get_items()
	if preview:
		items = items.filter(func(item): return item.get("visual",false))
	for child in column.get_children(): column.remove_child(child); child.queue_free()
	rows.clear()
	var group := ""
	var grid: GridContainer
	var group_row := -1
	var group_index := 0
	for item in items:
		var parent: Container=column
		if item.get("layout","")=="card":
			if item.group!=group:
				if grid!=null: group_row+=ceili(float(group_index)/2.0)
				else: group_row=0
				group=item.group; group_index=0
				var label := Label.new(); label.text=group; label.add_theme_font_size_override("font_size",16); label.add_theme_color_override("font_color",MenuSkin.MUTED); column.add_child(label)
				grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);column.add_child(grid)
			parent=grid
			item["nav_row"]=group_row+group_index/2; item["nav_col"]=group_index%2; group_index+=1
		if item.id=="exit":
			var divider := HSeparator.new()
			column.add_child(divider)
		var row = LibraryCard.new() if item.get("layout","")=="card" else (GameRow.new() if item.get("layout","")=="game" else (ActionRow.new() if item.kind=="action" else Row.new()))
		parent.add_child(row); row.configure(item)
		row.selected.connect(select)
		row.adjust_requested.connect(func(id,delta): select(id); begin_edit(); adjust(delta))
		row.pressed.connect(func(): select(item.id); activate())
		rows.append(row)
	sidebar.visible = mode=="settings" and not preview
	section_bar.visible = mode=="settings" and not preview
	for i in range(sidebar_buttons.size()):
		sidebar_buttons[i].add_theme_stylebox_override("normal",MenuSkin.box(Color("3b3022"),MenuSkin.AMBER,2) if i==category else MenuSkin.box(Color("23272d")))
	if mode=="settings":
		var pages: Array = catalog.pages(category)
		section_title.text = "%s  ·  %d of %d" % [pages[subsection].title,subsection+1,pages.size()]
		for child in section_tabs.get_children(): section_tabs.remove_child(child);child.queue_free()
		for i in range(pages.size()):
			var index: int = i
			var tab := Button.new()
			tab.text = ("▸ " if i==subsection else "")+str(pages[i].title)
			tab.focus_mode=Control.FOCUS_NONE
			tab.add_theme_font_size_override("font_size",18)
			tab.add_theme_stylebox_override("normal",MenuSkin.box(Color("3b3022"),MenuSkin.AMBER,2,8) if i==subsection else MenuSkin.box(Color("23272d"),Color("52565c"),1,8))
			tab.pressed.connect(func(): switch_section(index-subsection))
			section_tabs.add_child(tab)
		heading.text = CATEGORIES[category]
	else: heading.text = {"launch":"Continue or start fresh?","recent":"Recently played","favourites":"Favourites","pause":"RetroCRT XR","library":"Your game library","library_tools":"Library locations","games":library.Registry.SYSTEMS[library_system].name,"browser":"Browse games","volumes":"SD card volumes","drives":"Computer drives","slot":setup_name() if mode=="slot" else "","rename":"Name your setup","confirm":"Please confirm","room_presets":"Lighting presets"}.get(mode,"RetroCRT XR")
	confirm_panel.visible = mode=="confirm"
	if mode=="confirm": confirm_panel.describe(confirmation.title,confirmation.detail)
	rename_field.visible = mode=="rename"
	if mode=="rename": rename_field.text = str(draft_names.get(host.selected_profile,setup_name()))
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
	if mode=="library" and not rom_index.scanning: scan_preferred_id=""
	if saved.has("scroll") and not preview: restore_scroll.call_deferred(int(saved.scroll))
	fit_panel.call_deferred()
	refresh_labels()

func fit_panel() -> void:
	position = Vector2(36,522) if preview else Vector2(36,28)
	size = Vector2(888,170) if preview else Vector2(888,664)

func restore_scroll(value: int) -> void:
	scroll.scroll_vertical = value
	reveal_selected()

func selected_row():
	for row in rows:
		if row.item.id==selected_id: return row
	return null

func select(id: String, user_action := true) -> void:
	if rendering or selecting: return
	if user_action: scan_preferred_id=""
	var candidate = null
	for row in rows:
		if row.item.id==id and not row.disabled: candidate=row
	if candidate==null: return
	if editing and id!=selected_id: clear_input()
	selecting = true
	selected_id = id
	for row in rows: row.set_selected(row==candidate)
	if not preview and get_viewport().gui_get_focus_owner()!=candidate: candidate.grab_focus()
	selecting = false
	reveal_selected.call_deferred()
	refresh_labels()

func reveal_selected() -> void:
	var row = selected_row()
	if row!=null and not preview: scroll.ensure_control_visible(row)

func refresh_labels() -> void:
	var row = selected_row()
	var context: String = "Picture for "+host.emulator.rom_path.get_file() if not host.active_game_key.is_empty() else "Global picture"
	if mode=="pause": subtitle.text = host.emulator.rom_path.get_file() if host.emulator.loaded else status_title
	elif mode=="browser": subtitle.text = library.current_dir
	elif mode=="library":
		subtitle.text = ("Finding your games… %d found · You can browse while we look" % rom_index.total()) if rom_index.scanning else ("%d games · %d consoles · Ready to play" % [rom_index.total(),rom_index.games.values().filter(func(games): return not games.is_empty()).size()] if rom_index.total()>0 else "SNES · NES · Mega Drive · Master System · Game Gear")
	elif mode=="games":
		var count: int = rom_index.games.get(library_system,[]).size()
		subtitle.text = "%d games · Page %d of %d · L1/R1 pages" % [count,game_page+1,maxi(1,ceili(float(count)/GAMES_PER_PAGE))]
	elif mode in ["recent","favourites"]:
		subtitle.text = "%d games · X adds or removes a favourite" % items.size()
	elif mode=="launch": subtitle.text = launch_path.get_file().get_basename()
	elif mode=="library_tools": subtitle.text = host.default_rom_dir if not host.default_rom_dir.is_empty() else "Choose the main roms folder, once"
	elif mode=="settings": subtitle.text = ("Editing · " if editing else "")+(context if category==1 else "Global settings")+(" · changes apply live" if editing else "  ·  ←→ Categories")
	elif mode=="slot": subtitle.text = "Setup slot %d  ·  %s" % [host.selected_profile+1,str(draft_names.get(host.selected_profile,setup_name()))]
	else: subtitle.text = "RetroCRT XR"
	if notification_time>0: help_label.text = notification
	elif mode=="favourites" and items.is_empty(): help_label.text = "No favourites yet. Select a game in Recently played or a system list and press X. B returns."
	elif mode=="pause" and not host.emulator.loaded: help_label.text = status_detail
	elif mode=="library" and not rom_index.message.is_empty(): help_label.text=rom_index.message
	elif mode=="library" and host.default_rom_dir.is_empty(): help_label.text="Open Library locations and choose your main ROM folder. Your supported consoles appear here automatically."
	elif mode=="library" and not rom_index.scanning and rom_index.total()==0: help_label.text="No supported cartridges here yet. Check Library locations. Use uncompressed SNES, NES or Sega cartridges; archives and discs are not supported."
	elif row!=null: help_label.text = str(row.item.label)+" — "+str(row.item.get("help",""))
	else: help_label.text = library.message if mode=="browser" else "Nothing to select. B returns."
	if preview and row!=null: compact.text = "▸  %s    ‹  %s  ›" % [row.item.label,row.formatted_value()]
	if mode=="library": hints.text = "D-pad Select   A Open   B Back   R1 Refresh"
	elif mode=="browser": hints.text = "A Open   B Back   L1 Up   X SD card   Y Default   R1 Save default"
	elif mode in ["games","recent","favourites"]: hints.text = "↑↓ Select   A Play   X Favourite   B Systems"+("   L1/R1 Pages" if mode=="games" else "")
	elif preview: hints.text = "↑↓ Option   ←→ Adjust   Y Reset   X / B Settings"
	elif mode=="settings":
		hints.text = "←→ Adjust   A / B Done   Y Reset   X Preview" if editing else "↑↓ Option   ←→ Category   A Edit / Open   B Back   Y Reset   LT/RT Section"
	elif mode=="rename": hints.text = "Keyboard: type a name / Enter   ↓ Save   B Cancel"
	else: hints.text = "↑↓ Select   A Select   B Back   R3 Recenter"

func navigate_library(next: Vector2i) -> void:
	var row=selected_row()
	if row==null: return
	var x: int=row.item.nav_col
	var y: int=row.item.nav_row
	if next.x!=0:
		for candidate in rows:
			if not candidate.disabled and candidate.item.nav_row==y and candidate.item.nav_col==x+next.x:
				select(candidate.item.id); return
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
	if mode=="library": navigate_library(next); return
	if mode=="settings" and not preview:
		if editing:
			if next.x!=0: adjust(next.x)
			return
		if next.x!=0:
			switch_category(next.x); return
	var index := -1
	for i in range(rows.size()):
		if rows[i].item.id==selected_id: index=i
	if index<0: return
	if next.y!=0:
		var candidate := index+next.y
		while candidate>=0 and candidate<rows.size():
			if not rows[candidate].disabled: select(rows[candidate].item.id); return
			candidate+=next.y
	elif next.x!=0:
		if mode=="games": change_game_page(next.x)
		else: adjust(next.x)

func adjust(delta: int) -> void:
	if mode=="settings" and not editing and not preview: return
	var row = selected_row()
	if row==null: return
	var item: Dictionary = row.item
	match item.kind:
		"number": item.setter.call(clampf(snappedf(float(item.getter.call())+delta*float(item.step),float(item.step)),item.min,item.max))
		"choice": item.setter.call(posmod(int(item.getter.call())+delta,item.choices.size()))
		"toggle": item.setter.call(delta>0)
	row.refresh(); refresh_labels()

func activate() -> void:
	var row = selected_row()
	if row==null or row.disabled: return
	if editing: finish_edit()
	elif row.item.kind=="action": row.item.action.call()
	elif preview: adjust(1)
	else: begin_edit()
	refresh_labels()

func begin_edit() -> void:
	var row = selected_row()
	if row==null or row.item.kind=="action" or preview: return
	clear_input(); editing=true
	row.set_editing(true)
	refresh_labels()

func finish_edit() -> void:
	clear_input()
	refresh_labels()

func reset_option() -> void:
	var row = selected_row()
	if row==null or not row.item.has("default"): return
	row.item.setter.call(row.item.default)
	row.refresh(); notify("Selected option restored to its default")

func toggle_preview() -> void:
	if mode!="settings": return
	var row = selected_row()
	if row==null or not row.item.get("visual",false): return
	remember(); preview=not preview; clear_input(); render()

func notify(message: String) -> void:
	notification = message; notification_time=4.0
	refresh_labels()

func show_error(message: String) -> void:
	error_label.text=message; error_label.show()

func clear_input() -> void:
	editing=false
	for row in rows:
		if is_instance_valid(row): row.set_editing(false)
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
				else: reset_option()
			JOY_BUTTON_X:
				if mode=="browser": open_cards()
				elif mode in ["games","recent","favourites"]: toggle_favourite()
				else: toggle_preview()
			JOY_BUTTON_RIGHT_STICK: host.recenter()
			JOY_BUTTON_LEFT_SHOULDER:
				if mode=="browser": default_armed=false; open_folder(library.current_dir.get_base_dir())
				elif mode=="games": change_game_page(-1)
				elif not editing: switch_category(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				if mode=="browser": default_armed=not held.get(JOY_BUTTON_LEFT_SHOULDER,false)
				elif mode=="games": change_game_page(1)
				elif mode=="library": refresh_library()
				elif not editing: switch_category(1)
		return true
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			if event.axis_value<.25: triggers[event.axis]=false
			elif event.axis_value>.65 and not triggers.get(event.axis,false):
				triggers[event.axis]=true
				if not editing: switch_section(-1 if event.axis==JOY_AXIS_TRIGGER_LEFT else 1)
		elif event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			if event.axis==JOY_AXIS_LEFT_X: stick.x=event.axis_value
			else: stick.y=event.axis_value
			if stick.length()<.25: stick_blocked=false
			update_direction()
		return true
	if event is InputEventKey:
		if mode=="rename" and get_viewport().gui_get_focus_owner()==rename_field:
			if event.pressed and event.physical_keycode==KEY_DOWN:
				select("rename.save"); return true
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
				KEY_Y: reset_option()
				KEY_X:
					if mode in ["games","recent","favourites"]: toggle_favourite()
					else: toggle_preview()
				KEY_TAB:
					if not editing: switch_category(-1 if event.shift_pressed else 1)
				KEY_Q:
					if not editing: switch_category(-1)
				KEY_E:
					if not editing: switch_category(1)
				KEY_Z:
					if not editing: switch_section(-1)
				KEY_C:
					if not editing: switch_section(1)
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
