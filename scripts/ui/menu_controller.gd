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
const LocationBar = preload("res://scripts/ui/location_bar.gd")
## Page builders and actions, one helper per area; each reaches the menu and host.
var pictures := preload("res://scripts/ui/menu_pictures.gd").new()
var videos := preload("res://scripts/ui/menu_videos.gd").new()
var music := preload("res://scripts/ui/menu_music.gd").new()
var games := preload("res://scripts/ui/menu_games.gd").new()
var play := preload("res://scripts/ui/menu_play.gd").new()
var keys := preload("res://scripts/ui/menu_keys.gd").new()
## File screens share one structure: where you are (the location bar), what
## you can do here (THIS FOLDER), what is inside (CONTENTS) and other places
## (GO TO). Section names are shown as small headers between rows.
const SECTION_HERE := "THIS FOLDER"
const SECTION_INSIDE := "CONTENTS"
const SECTION_PLACES := "GO TO"
const StatusLine = preload("res://scripts/ui/status_line.gd")
const HelpArticle = preload("res://scripts/ui/help_article.gd")
const Platform = preload("res://scripts/platform/platform.gd")
## Confirmation answers shown in the danger colour.
const DESTRUCTIVE := ["Exit","Delete","Forget","Remove","Reset","Overwrite","Stop","Replace"]
var location_bar: PanelContainer
const CATEGORIES := ["View","Picture","Audio","Room","Controls & XR","Saved setups","About & Help","Quick settings","Videos"]
var host
var catalog := Catalog.new()
var library := Library.new()
var rom_index := RomIndex.new()
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
var sidebar_panel: PanelContainer
var section_rule: ColorRect
var section_bar: HBoxContainer
var section_tabs: HBoxContainer
var scroll: ScrollContainer
var column: VBoxContainer
var compact: Label
var confirm_panel: PanelContainer
var music_heading: Label
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
var status_detail := "Open a game from your library, or adjust the test signal."
var confirmation: Dictionary = {}
var return_state: Dictionary = {}
var draft_names: Dictionary = {}
var rename_preset := -1
## Your own room being looked at or renamed (-1 when none).
var my_room := -1
var rename_room := -1
var status_line: HBoxContainer
var help_title := ""
var help_copy := ""
var help_origin: Dictionary = {}
var entry_initialized := false
var sound_player: AudioStreamPlayer
var focus_tween: Tween


func _ready() -> void:
	for helper in [pictures,videos,music,games,play,keys]: helper.host=host; helper.menu=self
	theme = MenuSkin.create()
	host.box_art.art_ready.connect(thumbnail_arrived)
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
	MenuSkin.weigh(heading,MenuSkin.BOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A long game title shortens with an ellipsis instead of widening the panel
	# past its edge (with the Deck's battery beside it, it did).
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(heading)
	back_button = Button.new(); back_button.text = "Back  [B]"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(back)
	status_line = StatusLine.new(); status_line.host = host
	top.add_child(status_line)
	top.add_child(back_button)
	back_button.flat=true; back_button.add_theme_font_size_override("font_size",16); MenuSkin.weigh(back_button,MenuSkin.REGULAR)
	back_glyph=preload("res://scripts/ui/button_glyph.gd").new("B"); top.add_child(back_glyph)
	subtitle = Label.new()
	subtitle.add_theme_color_override("font_color",MenuSkin.MUTED)
	subtitle.add_theme_font_size_override("font_size",20)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(subtitle)
	location_bar=LocationBar.new(); location_bar.hide(); layout.add_child(location_bar)
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
		if mode=="folder_path": games.submit_folder_path()
		elif mode=="radio_url": music.save_radio_url()
		else: save_draft_name())
	layout.add_child(rename_field); rename_field.hide()
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation",16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	# Categories sit on their own surface so they read apart from the page.
	sidebar_panel = PanelContainer.new()
	sidebar_panel.add_theme_stylebox_override("panel",MenuSkin.box(Color("202328"),Color.TRANSPARENT,0,6))
	body.add_child(sidebar_panel)
	sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 170
	sidebar.add_theme_constant_override("separation",2)
	sidebar_panel.add_child(sidebar)
	# A header lined up with the category names, with its shortcut chip on the right.
	var category_header := HBoxContainer.new(); category_header.custom_minimum_size.y=32
	var category_title := Label.new(); category_title.text="CATEGORIES"
	category_title.add_theme_font_size_override("font_size",14); category_title.add_theme_color_override("font_color",MenuSkin.MUTED)
	MenuSkin.weigh(category_title,MenuSkin.BOLD)
	category_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; category_title.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var title_margin := MarginContainer.new(); title_margin.add_theme_constant_override("margin_left",12)
	title_margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL; title_margin.add_child(category_title); category_header.add_child(title_margin)
	var category_hint := key_hint(); category_hint.name="CategoryHint"; category_hint.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	category_header.add_child(category_hint); sidebar.add_child(category_header)
	for i in range(CATEGORIES.size()):
		var index := i
		var button := Button.new()
		button.text = CATEGORIES[i]
		button.add_theme_font_size_override("font_size",20)
		button.custom_minimum_size.y = 32
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for style in ["normal","pressed"]: button.add_theme_stylebox_override(style,sidebar_box(Color.TRANSPARENT))
		button.add_theme_stylebox_override("hover",sidebar_box(Color("2a2e34")))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): switch_category(index-category))
		sidebar.add_child(button); sidebar_buttons.append(button)
	# Keep category IDs stable while putting the everyday route first.
	sidebar.move_child(sidebar_buttons[7],1)
	sidebar.move_child(sidebar_buttons[8],sidebar_buttons[3].get_index()+1)
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
	section_hint=key_hint(); section_hint.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	section_hint.tooltip_text="Previous / next section"
	section_bar.add_child(section_hint)
	# A baseline under the tabs; the chosen tab's underline sits on it.
	section_rule=ColorRect.new(); section_rule.color=Color("3a3f46"); section_rule.custom_minimum_size.y=1
	section_rule.mouse_filter=Control.MOUSE_FILTER_IGNORE; content.add_child(section_rule)
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
	compact.add_theme_font_size_override("font_size",24); MenuSkin.weigh(compact,MenuSkin.SEMIBOLD)
	compact.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	compact.add_theme_color_override("font_color",MenuSkin.AMBER)
	layout.add_child(compact); compact.hide()
	help_label = Label.new()
	help_label.custom_minimum_size.y = 64
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.max_lines_visible = 3
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
	preview_button.flat=true; preview_button.add_theme_font_size_override("font_size",16); MenuSkin.weigh(preview_button,MenuSkin.REGULAR)
	preview_glyph=preload("res://scripts/ui/button_glyph.gd").new("X"); top.add_child(preview_glyph)
	visibility_changed.connect(func(): set_process(visible))
	open_pause()
	hide()

# Left-aligned category labels need side padding without taller buttons.
func sidebar_box(colour: Color, chosen := false) -> StyleBoxFlat:
	var style := MenuSkin.box(colour,MenuSkin.AMBER,0,6)
	style.content_margin_left=12; style.content_margin_right=12
	# Nine categories must fit beside a page with three lines of help.
	style.content_margin_top=3; style.content_margin_bottom=3
	if chosen: style.border_width_left=3; style.content_margin_left=11
	return style

## A small key chip, such as "Q / E", so shortcuts read apart from content.
func key_hint() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_color_override("font_color",Color("c9cbce"))
	MenuSkin.weigh(label,MenuSkin.SEMIBOLD)
	var chip := MenuSkin.box(Color("2c3036"),Color.TRANSPARENT,0,0)
	chip.set_corner_radius_all(5); chip.content_margin_left=8; chip.content_margin_right=8; chip.content_margin_top=2; chip.content_margin_bottom=2
	label.add_theme_stylebox_override("normal",chip)
	label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	return label

func state_key() -> String:
	match mode:
		"settings": return "settings:%d:%d" % [category,subsection]
		# Each help page keeps its own place; a new one opens at the top.
		"help": return "help:"+help_title
		"music_browser": return "music:%s:%d" % [music.music_dir,music.music_page]
		"videos": return "videos:%s:%d" % [videos.video_view_dir,videos.video_page]
		"video_folder": return "video_folder:"+videos.video_folder_dir
		"browser": return "browser:"+library.current_dir
		"games": return "games:%s:%s:%d" % [host.default_rom_dir,games.library_system,games.game_page]
		"slot": return "slot:%d" % host.selected_profile
		"my_preset": return "my_preset:%d" % pictures.my_preset
		"my_room": return "my_room:%d" % my_room
		"states": return "states:%s" % play.states_saving
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
	selected_id = "resume" if host.emulator.loaded or host.video.loaded else ("home.continue" if FileAccess.file_exists(host.last_game_path) else "home.library")
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
	# Step through the sidebar as it reads, not through the category ids.
	var order: Array = sidebar_buttons.duplicate()
	order.sort_custom(func(a, b): return a.get_index() < b.get_index())
	category = sidebar_buttons.find(order[posmod(order.find(sidebar_buttons[category])+delta,order.size())])
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
		"alphabet": mode=games.alphabet_origin; render()
		"launch": restore(games.launch_origin)
		"slot": mode="settings"; render()
		"folder_path": restore(games.folder_path_origin)
		"rename": mode="my_room" if rename_room>=0 else ("my_preset" if rename_preset>=0 else "slot"); render()
		"my_preset", "my_room": mode="settings"; render()
		"states": mode="pause"; render()
		"music_browser": restore(music.music_origin)
		"videos":
			# Subfolders step back up towards the video folder before leaving it.
			if videos.video_view_dir!=host.video_dir and videos.video_view_dir.begins_with(host.video_dir): videos.open_videos(videos.video_view_dir.get_base_dir())
			else: mode="library"; render()
		"video_launch": mode="videos"; render()
		"video_search": mode="videos"; render()
		"video_folder": mode="library_tools"; render()
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

func open_my_room(index: int) -> void:
	remember(); clear_input(); my_room=index; mode="my_room"; render()

## The room quick switch: left/right moves through Custom, the built-in moods
## and your saved rooms, changing the room at once.
func room_choice(id: String) -> Dictionary:
	var choices: Array = host.rooms.choices()
	return {"id":id,"label":"Room","kind":"choice","choices":choices.map(func(pair): return pair[1]),"visual":true,"row_icon":"lamp",
		"getter":func(): return maxi(0,choices.map(func(pair): return pair[0]).find(host.rooms.active())),
		"setter":func(value):
			host.rooms.apply(str(choices[int(value)][0]))
			host.rebuild_settings(),
		"help":"Warm bedroom, Bright inspection, Dim XR or a room you saved under Room → Presets. Custom is your own tuned room."}

func save_my_room(index: int) -> void:
	var title: String=host.rooms.name(index)
	var callback := func():
		if host.rooms.save(index)!=OK: show_error("Room could not be saved. Check free space and user-folder permissions."); return
		refresh(); notify("Saved · "+title)
	if host.rooms.saved(index): ask("Overwrite this room?","Replace “%s” with the current room?" % title,callback)
	else: callback.call()

func delete_my_room(index: int) -> void:
	var title: String=host.rooms.name(index)
	ask("Delete this room?","Remove “%s”? The room you're in does not change." % title,func():
		host.rooms.delete(index); mode="settings"; refresh(); notify("Deleted · "+title))

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
	if rename_room>=0:
		if host.rooms.rename(rename_room,rename_field.text)!=OK: show_error("Room could not be renamed. Check user-folder permissions."); return
		var title: String=host.rooms.name(rename_room)
		rename_room=-1; mode="my_room"; clear_input(); render(); notify("Renamed · "+title); return
	if rename_preset>=0: pictures.rename_my_preset(rename_preset,rename_field.text); return
	draft_names[host.selected_profile] = rename_field.text.strip_edges().left(32)
	mode="slot"; clear_input(); render()
	notify("Name ready. Save this setup to store the new name.")



func card(item: Dictionary, caption: String, glyph: String, accent: Color, group: String) -> Dictionary:
	item.merge({"layout":"card","caption":caption,"glyph":glyph,"accent":accent,"group":group})
	return item



## Places a row in a section, with an icon, emphasis and an optional detail line.
func entry(item: Dictionary, section: String, icon := "", emphasis := "", detail := "", compact := false) -> Dictionary:
	item["section"]=section
	if not icon.is_empty(): item["row_icon"]=icon
	if not emphasis.is_empty(): item["emphasis"]=emphasis
	if not detail.is_empty(): item["layout"]="game"; item["detail"]=detail
	if compact: item["compact"]=true
	return item

## "Up to D:" for the parent of `path`, or nothing at a drive or share root.
func up_entry(id: String, path: String, callback: Callable) -> Array:
	var parent := path.get_base_dir()
	if parent.is_empty() or parent==path: return []
	var name := parent.get_file() if not parent.get_file().is_empty() else parent
	return [entry(catalog.action(id,"Up to "+name,callback.bind(parent),"Go to the folder that contains this one.",false,""),SECTION_INSIDE,"up")]

## The other places a file screen can jump to: home, SD cards, drives, a typed path.
func place_entries(prefix: String, open: Callable, path_entry: Callable, extra: Array = [], typed := true) -> Array:
	var result: Array=[]
	for place in extra+[[library.home_folder(),"Home folder","home"]]:
		var path: String=place[0]
		if not path.is_empty(): result.append(entry(catalog.action(prefix+".place:"+path,place[1],open.bind(path),path,false,""),SECTION_PLACES,place[2],"","",true))
	for mount in library.cards():
		var path: String=mount
		result.append(entry(catalog.action(prefix+".sd:"+path,"SD card",open.bind(path),path,false,""),SECTION_PLACES,"sd","","",true))
	if Platform.has_drive_list():
		for drive in library.Locations.computer_drives():
			var path: String=drive
			result.append(entry(catalog.action(prefix+".drive:"+path,"Drive "+path.trim_suffix("/"),open.bind(path),"Browse this drive, including mapped network drives.",false,""),SECTION_PLACES,"drive","","",true))
	if typed: result.append(entry(catalog.action(prefix+".path","Type a folder or network path…",path_entry,"Enter a local folder or a share such as //server/share. Windows handles the sign-in.",false,""),SECTION_PLACES,"network","","",true))
	return result










func thumbnail_arrived(path: String, texture: Texture2D) -> void:
	for row in rows:
		if row.item.get("thumbnail_path","")==path: row.set_thumbnail(texture)




























## "just now", "5 minutes ago", "yesterday", "3 days ago" or a date.
static func ago(unix: int) -> String:
	var seconds := int(Time.get_unix_time_from_system()) - unix
	if seconds < 60: return "just now"
	if seconds < 3600: return "%d minute%s ago" % [seconds / 60, "" if seconds / 60 == 1 else "s"]
	if seconds < 86400: return "%d hour%s ago" % [seconds / 3600, "" if seconds / 3600 == 1 else "s"]
	var days := seconds / 86400
	if days == 1: return "yesterday"
	if days < 14: return "%d days ago" % days
	var date := Time.get_date_dict_from_unix_time(unix)
	return "%d %s" % [date.day, ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][date.month - 1]]

## The end of a long folder path, so it fits on one line: "…/snes/rpgs".
static func short_path(path: String, keep := 2) -> String:
	var parts := path.replace("\\", "/").split("/", false)
	if parts.size() <= keep + 1: return path
	return "…/" + "/".join(parts.slice(parts.size() - keep))

## A compact action in a two-column grid of tiles. Actions you go to sit in
## tiles; rows you adjust with left/right, and panels, stay full width.
func tile(item: Dictionary, icon: String, emphasis := "") -> Dictionary:
	item.merge({"layout":"tile","row_icon":icon,"compact":true,"value":""}, true)
	if not emphasis.is_empty(): item["emphasis"]=emphasis
	return item
















func get_items() -> Array:
	var h = host
	match mode:
		"music_browser": return music.music_browser_items()
		"radio_url": return keys.text_keys()+[catalog.action("radio.save","Use this URL",music.save_radio_url),catalog.action("radio.cancel","Cancel",back)]
		"videos": return videos.video_items()
		"video_search": return keys.text_keys()+[catalog.action("video_search.go","Search",videos.run_video_search,"Show videos whose names contain this."),catalog.action("video_search.cancel","Cancel",back,"Back to your videos.")]
		"video_folder": return videos.video_folder_items()
		"video_launch": return videos.launch_items()
		"pause":
			if h.video.loaded: return videos.video_pause_items()
			return play.pause_items() if h.emulator.loaded else play.home_items()
		"launch": return games.launch_items()
		"recent", "favourites": return games.history_items()
		"settings": return catalog.pages(category)[subsection].rows
		"help": return []
		"library": return games.library_items()
		"library_tools": return games.library_tool_items()
		"games": return games.console_items()
		"alphabet": return games.letter_items()
		"browser": return games.browser_items()
		"drives": return games.drive_items()
		"volumes": return games.volume_items()
		"states": return play.state_items()
		"my_room":
			var saved: bool=h.rooms.saved(my_room)
			return [catalog.unavailable(catalog.action("room_mine.apply","Use this room",func(): h.rooms.apply("mine.%d" % my_room); h.rebuild_settings(); refresh(); notify(h.rooms.name(my_room)+" in use"),"Changes the lighting, floor and props. The picture stays as it is.",not saved),"Nothing is saved here yet."),
				catalog.action("room_mine.save","Save current room here",func(): save_my_room(my_room),"Stores the current lighting, shadows, floor and props in this room."),
				catalog.unavailable(catalog.action("room_mine.rename","Rename",func(): rename_room=my_room; rename_preset=-1; mode="rename"; entry_initialized=false; clear_input(); render(); keys.focus_entry(),"Use the on-screen keys or a physical keyboard.",not saved),"Save a room here first."),
				catalog.unavailable(catalog.action("room_mine.delete","Delete",func(): delete_my_room(my_room),"Removes this room. The room you're in does not change.",not saved),"Nothing is saved here yet.")]
		"slot":
			var saved := FileAccess.file_exists(h.profile_path()) or FileAccess.file_exists(h.profile_path()+".bak")
			return [catalog.action("slot.save","Save current setup",save_setup,"Stores current room, view and picture in this slot."),
				catalog.unavailable(catalog.action("slot.load","Load setup",h.load_profile,"Apply this slot while retaining display mode and tracking provider.",not saved),"Save a setup to this slot first."),
				catalog.action("slot.rename","Rename slot",func(): rename_preset=-1; mode="rename"; entry_initialized=false; clear_input(); render(); keys.focus_entry(),"Use the on-screen keys or a physical keyboard."),
				catalog.unavailable(catalog.action("slot.undo","Undo last setup load",h.undo_profile,"Restores the settings from before the last setup load.",h.profile_undo==null),"Available after loading a setup.")]
		"folder_path": return keys.text_keys()+[catalog.action("folder_path.open","Open folder",games.submit_folder_path,"Opens a local folder or a network share you can access in Windows."),catalog.action("folder_path.cancel","Cancel",back)]
		"my_preset": return pictures.items()
		"rename": return keys.text_keys()+[catalog.action("rename.save","Use this name",save_draft_name,"Renames this preset now." if rename_preset>=0 else "The new name is stored when you save the setup."),catalog.action("rename.cancel","Cancel",back,"Leave the name unchanged.")]
		# Dialog titles lead with their verb ("Overwrite this setup?"), which names the button.
		"confirm":
			var answer: Dictionary = catalog.action("confirm",str(confirmation.title).get_slice(" ",0).trim_suffix("?"),confirmed,confirmation.detail,false,"")
			if answer.label in DESTRUCTIVE: answer["emphasis"]="danger"
			return [catalog.action("cancel","Cancel",back,"Keep things as they are.",false,""),answer]
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
	var section := ""
	var grid: GridContainer
	music_heading=null
	var music_layout: VBoxContainer
	var transport_grid: HBoxContainer
	var group_row := -1
	var group_index := 0
	var tiles: GridContainer
	var tile_items: Array = items.filter(func(entry): return entry.get("layout","")=="tile")
	var tile_number := 0
	for item in items:
		var parent: Container=column
		if item.get("layout","") in ["transport","music_seek","music_link","video_resume","video_seek"]:
			if music_layout==null:
				var watching := str(item.layout).begins_with("video_")
				var panel := PanelContainer.new()
				panel.add_theme_stylebox_override("panel",MenuSkin.box(Color("222a30"),Color("47535b"),1,12))
				column.add_child(panel)
				music_layout=VBoxContainer.new(); music_layout.add_theme_constant_override("separation",4); panel.add_child(music_layout)
				var badge := Label.new(); badge.text="NOW PLAYING" if watching else "MUSIC PLAYER"; badge.add_theme_font_size_override("font_size",16); MenuSkin.weigh(badge,MenuSkin.BOLD); badge.add_theme_color_override("font_color",MenuSkin.AMBER); music_layout.add_child(badge)
				if not watching and not host.music.kind.is_empty():
					music_heading=Label.new(); music_heading.add_theme_font_size_override("font_size",20); MenuSkin.weigh(music_heading,MenuSkin.SEMIBOLD)
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
				var label := Label.new(); label.text=group; label.add_theme_font_size_override("font_size",16); MenuSkin.weigh(label,MenuSkin.BOLD); label.add_theme_color_override("font_color",MenuSkin.MUTED); column.add_child(label)
				grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);column.add_child(grid)
			parent=grid
			item["nav_row"]=group_row+group_index/2; item["nav_col"]=group_index%2; group_index+=1
		if item.get("layout","")=="tile":
			if tiles==null:
				tiles=GridContainer.new(); tiles.columns=2; tiles.add_theme_constant_override("h_separation",8); tiles.add_theme_constant_override("v_separation",6); column.add_child(tiles)
			parent=tiles
			item["tile_index"]=tile_number; item["tile_count"]=tile_items.size(); tile_number+=1
		if item.get("layout","") in ["letter","key"]:
			if grid==null:
				grid=GridContainer.new(); grid.columns=10 if item.get("layout","")=="key" else 6; grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8); column.add_child(grid)
			parent=grid
			item["nav_row"]=group_index/grid.columns; item["nav_col"]=group_index%grid.columns; group_index+=1
		if item.has("section") and item.section!=section and item.get("layout","")!="card":
			if not section.is_empty():
				var gap := Control.new(); gap.custom_minimum_size.y=6; column.add_child(gap)
			section=item.section
			var header := Label.new(); header.text=section; header.add_theme_font_size_override("font_size",16); MenuSkin.weigh(header,MenuSkin.BOLD); header.add_theme_color_override("font_color",MenuSkin.MUTED)
			column.add_child(header)
		if item.id in ["exit","home.exit"] and item.get("layout","")!="tile":
			var divider := HSeparator.new()
			column.add_child(divider)
		var row = MusicIcon.new() if item.get("layout","")=="transport" else (MusicTimeline.new() if item.kind=="seek" else (LibraryCard.new() if item.get("layout","")=="card" else (GameRow.new() if item.get("layout","")=="game" else (ActionRow.new() if item.kind=="action" else Row.new()))))
		parent.add_child(row); row.configure(item)
		if item.get("layout","")=="tile": row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
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
	sidebar_panel.visible = sidebar.visible
	section_bar.visible = mode=="settings" and not preview and catalog.pages(category).size() > 1
	section_rule.visible = section_bar.visible
	for i in range(sidebar_buttons.size()):
		sidebar_buttons[i].add_theme_stylebox_override("normal",sidebar_box(Color("3b3329") if i==category else Color.TRANSPARENT,i==category))
		sidebar_buttons[i].add_theme_color_override("font_color",MenuSkin.TEXT if i==category else MenuSkin.MUTED)
		MenuSkin.weigh(sidebar_buttons[i],MenuSkin.SEMIBOLD if i==category else MenuSkin.REGULAR)
	if mode=="settings":
		var pages: Array = catalog.pages(category)
		for child in section_tabs.get_children(): section_tabs.remove_child(child);child.queue_free()
		for i in range(pages.size()):
			var index: int = i
			var tab := Button.new()
			tab.text = str(pages[i].title)
			tab.focus_mode=Control.FOCUS_NONE
			tab.add_theme_font_size_override("font_size",20 if host.menu_large_text else 18)
			MenuSkin.weigh(tab,MenuSkin.SEMIBOLD if i==subsection else MenuSkin.REGULAR)
			var tab_style := MenuSkin.box(Color.TRANSPARENT,MenuSkin.AMBER,0,6)
			tab_style.set_corner_radius_all(0)
			# Reach down to the baseline rule so the underline sits on it.
			tab_style.expand_margin_bottom=8
			if i==subsection: tab_style.border_width_bottom=3
			tab.add_theme_stylebox_override("normal",tab_style)
			tab.add_theme_stylebox_override("pressed",tab_style)
			var hover_style: StyleBoxFlat=tab_style.duplicate(); hover_style.bg_color=Color("292d33")
			tab.add_theme_stylebox_override("hover",hover_style)
			tab.add_theme_color_override("font_color",MenuSkin.TEXT if i==subsection else MenuSkin.MUTED)
			tab.pressed.connect(func(): switch_section(index-subsection))
			section_tabs.add_child(tab)
		heading.text = CATEGORIES[category]
	else: heading.text = {"help":help_title,"launch":"Continue or start fresh?","recent":"Recently played","favourites":"Favourites","alphabet":"Jump to letter","music_browser":"Music & albums","pause":playing_title(),"library":"Your game library","library_tools":"Library locations","videos":"Videos","video_search":"Search videos","video_folder":"Choose a video folder","video_launch":"Continue or start over?","games":library.Registry.SYSTEMS[games.library_system].name,"browser":"Browse games","volumes":"SD card volumes","drives":"Computer drives","slot":setup_name() if mode=="slot" else "","folder_path":"Open a folder", "rename":"Name your setup","confirm":str(confirmation.get("title","Please confirm")) if mode=="confirm" else "","my_room":host.rooms.name(my_room) if mode=="my_room" else "","states":"Save state" if play.states_saving else "Load state"}.get(mode,"CRT XR")
	confirm_panel.visible = mode=="confirm"
	if mode=="confirm": confirm_panel.describe("",confirmation.detail,confirmation.get("preview",""))
	rename_field.visible = mode in ["rename","radio_url","folder_path","video_search"]
	rename_field.max_length=2048 if mode in ["radio_url","folder_path"] else (64 if mode=="video_search" else 32)
	rename_field.placeholder_text="D:/roms or //server/share/roms" if mode=="folder_path" else "Direct MP3 stream URL" if mode=="radio_url" else ("Part of a video's name" if mode=="video_search" else "Name · Use on-screen keys or type")
	if mode=="rename" and not entry_initialized:
		rename_field.text = host.rooms.name(rename_room) if rename_room>=0 else (pictures.my_preset_name(rename_preset) if rename_preset>=0 else str(draft_names.get(host.selected_profile,setup_name()))); entry_initialized=true
	if mode=="rename" and rename_preset>=0: heading.text="Name your preset"
	if mode=="rename" and rename_room>=0: heading.text="Name your room"
	if mode=="my_preset": heading.text=pictures.my_preset_name(pictures.my_preset)
	search_field.visible = input_kind=="keyboard" and mode in ["games","recent","favourites","videos"] and not preview
	search_field.placeholder_text="Search videos…  (Ctrl+F)" if mode=="videos" else "Search games…  (Ctrl+F)"
	if not search_field.visible and search_field.has_focus(): search_field.release_focus()
	body.visible = not preview
	compact.visible = preview
	var place: String = {"browser":library.current_dir,"music_browser":music.music_dir,"videos":videos.video_view_dir,"video_folder":videos.video_folder_dir}.get(mode,"")
	location_bar.visible = not place.is_empty() and not preview
	if location_bar.visible: location_bar.show_path(place,library.home_folder(),library.cards())
	subtitle.visible = not preview and not location_bar.visible
	position = Vector2(36,522) if preview else Vector2(36,28)
	size = Vector2(888,170) if preview else Vector2(888,664)
	help_label.visible = not preview and mode!="help" # help pages use the room for the article
	if preview: heading.add_theme_font_size_override("font_size",22)
	else: heading.add_theme_font_size_override("font_size",32)
	var saved: Dictionary = memory.get(state_key(),{})
	var preferred: String = selected_id if preview else str(saved.get("id",""))
	if mode=="library" and not scan_preferred_id.is_empty(): preferred=scan_preferred_id
	if preferred.is_empty() and mode in ["games","recent","favourites"]:
		# Land on the first game rather than the Jump to letter tool above it.
		for row in rows:
			if row.item.get("layout","")=="game": preferred=row.item.id; break
	selected_id = ""
	for row in rows:
		if not row.disabled and (selected_id.is_empty() or row.item.id==preferred):
			selected_id = row.item.id
			if row.item.id==preferred: break
	rendering = false
	select(selected_id,false)
	style_rows()
	if mode=="launch":
		var hero := HBoxContainer.new(); hero.add_theme_constant_override("separation",16)
		column.add_child(hero)
		var preview_panel := Confirmation.new(); preview_panel.custom_minimum_size.x=400; hero.add_child(preview_panel)
		var auto: String=host.emulator.auto_path_for(games.launch_path)
		preview_panel.describe("Where you left off","Saved "+ago(host.emulator.state_stamp(auto)),auto)
		preview_panel.thumbnail.custom_minimum_size=Vector2(368,276)
		var actions := VBoxContainer.new(); actions.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.alignment=BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation",8); hero.add_child(actions)
		for row in rows: column.remove_child(row); actions.add_child(row)
		select(selected_id,false)
	if mode=="help":
		column.add_child(HelpArticle.build(help_copy,host.menu_large_text))
	if mode=="library" and not rom_index.scanning: scan_preferred_id=""
	if saved.has("scroll") and not preview: restore_scroll.call_deferred(int(saved.scroll),layout_revision)
	elif not preview: reveal_after_layout.call_deferred(layout_revision)
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

func reveal_after_layout(revision: int) -> void:
	# New rows only have final positions once wrapped text has laid out.
	await get_tree().process_frame
	await get_tree().process_frame
	if revision==layout_revision: reveal_selected()

## Where the menu's depth layers sit, in menu-viewport pixels, for
## scripts/ui/menu_depth.gd: the page and the selected row (clipped to it).
func depth_layout() -> Dictionary:
	var layout := {"page": Rect2(), "lift": Rect2(), "page_key": state_key() + ("|preview" if preview else ""), "selected": selected_id}
	if not visible: return layout
	if body.visible:
		var clip := scroll.get_global_rect()
		layout.page = clip
		var row = selected_row()
		if row != null and row.is_visible_in_tree():
			layout.lift = row.get_global_rect().intersection(clip)
		# The About page's logo floats in front of its page, as a selected row does.
		var logo := column.find_child("Logo3D", true, false) as Control if mode == "help" else null
		if logo != null and logo.is_visible_in_tree():
			layout.lift = logo.get_global_rect().intersection(clip)
	return layout

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
	if user_action and selected_id!=id:
		play_menu_sound()
		host.menu_vibrate(0.56, 0.04)
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
	if row==null or preview: return
	# The first row of a section brings its header with it, so the section's
	# name is never scrolled just out of view; the top row scrolls fully home.
	# Rows inside a panel (Now playing, the music player) count as the panel:
	# reaching its first row shows the whole panel, header included.
	var block: Control=row
	while block.get_parent()!=column and block.get_parent() is Control: block=block.get_parent()
	var position: int=rows.find(row)
	if position==0: scroll.scroll_vertical=0
	elif block!=row:
		if not block.is_ancestor_of(rows[position-1]): scroll.ensure_control_visible(block)
	elif row.get_index()>0 and column.get_child(row.get_index()-1) is Label: scroll.ensure_control_visible(column.get_child(row.get_index()-1))
	scroll.ensure_control_visible(row)

func refresh_labels() -> void:
	if is_instance_valid(music_heading): music_heading.text=host.music.now_playing()
	var row = selected_row()
	# Picture pages change whichever picture is in use; say which, plainly.
	var context: String
	if host.active_game_key==host.VIDEO_PROFILE: context="Editing the video picture · all videos"
	elif not host.active_game_key.is_empty(): context="Editing %s's picture · this game only" % host.emulator.rom_path.get_file().get_basename()
	elif host.video.loaded: context="Editing the global picture · games, videos and test signal"
	else: context="Editing the global picture · games and test signal"
	if mode=="pause":
		if host.video.loaded: subtitle.text = "Video · paused" if host.video.paused else "Video"
		elif host.emulator.loaded: subtitle.text = library.Registry.SYSTEMS.get(host.emulator.system_id, {}).get("name", "Game") + " · paused"
		else: subtitle.text = status_title
		subtitle.tooltip_text=status_detail
	elif mode=="help": subtitle.text="Game library" if help_title=="Full game title" else "CRT XR · Help"
	elif mode=="music_browser": subtitle.text=music.music_dir+" · Page %d" % [music.music_page+1]
	elif mode=="videos": subtitle.text=videos.video_view_dir+(" · Page %d" % [videos.video_page+1] if videos.video_page>0 else "")
	elif mode=="video_folder": subtitle.text=videos.video_folder_dir
	elif mode=="radio_url": subtitle.text="Direct MP3 streams · On-screen keys or keyboard"
	elif mode=="browser": subtitle.text = library.current_dir
	elif mode=="library":
		subtitle.text = ("Finding your games… %d found · You can browse while we look" % rom_index.total()) if rom_index.scanning else (count_caption(rom_index.total(),"game")+" · "+count_caption(rom_index.games.values().filter(func(found): return not found.is_empty()).size(),"console")+" · Ready to play" if rom_index.total()>0 else "%d consoles supported · Your files stay where they are" % library.Registry.SYSTEMS.size())
	elif mode=="games":
		var count: int = games.game_entries().size()
		subtitle.text = count_caption(count,"game")
		if count>games.GAMES_PER_PAGE: subtitle.text += " · Page %d of %d" % [games.game_page+1,ceili(float(count)/games.GAMES_PER_PAGE)]
	elif mode in ["recent","favourites"]:
		subtitle.text = count_caption(games.history_paths().size(),"game")
	elif mode=="launch": subtitle.text = games.launch_path.get_file().get_basename()
	elif mode=="library_tools": subtitle.text = "Where CRT XR finds your games and videos · Your files stay where they are"
	elif mode=="settings":
		if category==1: subtitle.text=context+" · "+pictures.preset_caption()
		elif category==2 and subsection==2: subtitle.text=host.music.status
		else: subtitle.text="• marks a setting you've changed"
	elif mode=="states": subtitle.text = host.emulator.rom_path.get_file().get_basename()+" · %d slots" % play.STATE_SLOTS
	elif mode=="my_room": subtitle.text = "Room %d · %s" % [my_room+1,"✓ In use" if host.rooms.active()=="mine.%d" % my_room else ("Saved" if host.rooms.saved(my_room) else "Empty")]
	elif mode=="my_preset": subtitle.text = "Picture preset %d · %s" % [pictures.my_preset+1,"✓ Active" if pictures.applied_preset()=="mine.%d" % pictures.my_preset else ("Saved" if pictures.my_preset_saved(pictures.my_preset) else "Empty")]
	elif mode=="slot": subtitle.text = "Setup slot %d  ·  %s" % [host.selected_profile+1,str(draft_names.get(host.selected_profile,setup_name()))]
	else: subtitle.text = ""
	# Highlighted when Picture changes belong to one game or to videos, not everything.
	subtitle.add_theme_color_override("font_color",MenuSkin.AMBER if mode=="settings" and category==1 and not host.active_game_key.is_empty() else MenuSkin.MUTED)
	subtitle.visible = not preview and not subtitle.text.is_empty() and not location_bar.visible
	if mode in ["games","recent","favourites"] and not search_query.is_empty(): subtitle.text += " · Search: "+search_query
	if notification_time>0 and notification_context==state_key(): help_label.text = notification
	elif mode=="help": help_label.text=""
	elif mode=="favourites" and items.is_empty(): help_label.text = "No favourites yet. Select a game in any console list and press X."
	elif mode=="library" and not rom_index.message.is_empty(): help_label.text=rom_index.message
	elif mode=="library" and host.default_rom_dir.is_empty(): help_label.text="Choose Set up your ROM library and select your main ROM folder. Your supported consoles appear here automatically."
	elif mode=="library" and not rom_index.scanning and rom_index.total()==0: help_label.text="No supported games here yet. Check Library locations. Cartridges can be plain files or ZIPs; Sega CD discs can be .cue/.bin, or CHD in a Sega CD folder. 7z and RAR are not supported."
	elif row!=null: help_label.text = str(row.item.get("help",""))
	else: help_label.text = library.message if mode=="browser" else ("Nothing here yet. B goes back." if input_kind=="controller" else "Nothing here yet. Backspace goes back.")
	if preview and row!=null: compact.text = "▸  %s    ‹  %s  ›" % [row.item.label,row.formatted_value()]
	refresh_hints(row)

func preview_available() -> bool:
	if mode!="settings": return false
	return items.any(func(item): return item.get("visual",false) and not item.get("disabled",false) and item.kind!="action")

func count_caption(count: int, noun: String) -> String:
	return "%d %s%s" % [count,noun,"" if count==1 else "s"]

## The pause menu's heading: the game or video by name, or a welcome.
func playing_title() -> String:
	if host.video.loaded: return host.video.path.get_file().get_basename()
	if host.emulator.loaded: return host.emulator.rom_path.get_file().get_basename()
	return "Welcome to CRT XR"

func refresh_hints(row) -> void:
	var pad := input_kind=="controller"
	hints.controller=pad
	var back_caption := ("Return to game" if host.emulator.loaded else "Close menu") if mode=="pause" else "Back"
	back_button.text=back_caption+("" if pad else "  [Backspace]")
	back_glyph.visible=pad
	sidebar.find_child("CategoryHint",true,false).text="L1 / R1" if pad else "Q / E"
	section_hint.text="L2 / R2" if pad else "Z / C"
	preview_button.visible=preview_available() and not preview
	preview_button.text="Preview" if pad else "Preview  [X]"
	preview_glyph.visible=pad and preview_button.visible
	# One vocabulary everywhere: Deck glyphs for the pad, key names for the keyboard.
	var parts: Array=["D-pad Select" if pad else "↑↓ Select"]
	var open := "A Open" if pad else "Enter Open"
	var go_back := "B Back" if pad else "Backspace Back"
	if mode=="settings":
		if row!=null:
			if row.item.kind=="toggle": parts.append("←→ Change")
			elif row.item.kind!="action": parts.append("←→ Adjust")
			elif str(row.item.get("value",""))=="Apply": parts.append("A Apply" if pad else "Enter Apply")
			else: parts.append(open)
			if row.item.has("default"): parts.append("Y Reset")
		if preview: parts.append("B Settings" if pad else "Backspace Settings")
	elif mode in ["games","recent","favourites"]:
		parts.append(open)
		if row!=null and row.item.has("rom_path"): parts.append_array(["X Favourite","Y Full title" if search_query.is_empty() else "Y Clear search"])
	elif mode=="browser": parts.append_array([open,go_back,"R1 Use folder"] if pad else [open,go_back])
	elif mode=="help": parts=["D-pad Scroll" if pad else "↑↓ Scroll",go_back]
	elif mode=="library":
		parts.append_array([open,go_back])
		if not host.default_rom_dir.is_empty(): parts.append("R1 Refresh" if pad else "R Refresh")
	elif mode=="pause": parts.append_array([open,("B " if pad else "Backspace ")+back_caption])
	elif mode=="confirm": parts.append_array(["A Choose" if pad else "Enter Choose","B Cancel" if pad else "Backspace Cancel"])
	elif mode in ["folder_path","rename","radio_url"]: parts=["D-pad Keys","A Type",go_back] if pad else ["Type or click keys","Enter Submit",go_back]
	else: parts.append_array([open,go_back])
	hints.text=" · ".join(parts)

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
	if mode in ["rename","folder_path","radio_url","video_search"] and input_kind=="controller":
		keys.navigate_keys(next); return
	var index := -1
	for i in range(rows.size()):
		if rows[i].item.id==selected_id: index=i
	if index<0: return
	if rows[index].item.get("layout","")=="tile":
		var position: int=rows[index].item.tile_index
		var count: int=rows[index].item.tile_count
		var first: int=index-position
		if next.x!=0:
			var beside := position+next.x
			if beside>=0 and beside<count and beside/2==position/2 and not rows[first+beside].disabled: select(rows[first+beside].item.id)
			return
		if next.y!=0:
			# Step a grid row at a time; prefer the same column, else the other.
			var line := position/2+next.y
			while line>=0 and line*2<count:
				for option in [line*2+position%2, line*2+1-position%2]:
					if option<count and not rows[first+option].disabled:
						select(rows[first+option].item.id); return
				line+=next.y
			# Past the grid: carry on from its first or last tile.
			index=first if next.y<0 else first+count-1
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
		var listed := games.game_entries()
		if listed.is_empty(): return
		var current := games.game_page*games.GAMES_PER_PAGE
		for i in range(listed.size()):
			if "game:"+str(listed[i].path)==selected_id: current=i; break
		var target := clampi(current+amount,0,listed.size()-1)
		var target_id := "game:"+str(listed[target].path)
		var page := target/games.GAMES_PER_PAGE
		# Same page: just move, and the list follows as it does for up/down.
		if page==games.game_page: select(target_id); return
		remember(); games.game_page=page; games.system_pages[games.library_system]=games.game_page
		# New page: no saved offset, so the rebuilt list scrolls to the target
		# instead of restoring a stale position over it.
		memory[state_key()]={"id":target_id}
		render(); return
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
	if row==null or row.disabled: return
	if mode!="settings" and not (mode=="pause" and (str(row.item.id).begins_with("video.") or row.item.id=="pause.room")): return
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
		host.menu_vibrate(1.0, 0.07)
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
				if default_armed: games.set_default(library.current_dir)
				default_armed=false
		elif blocked.has(event.button_index): return true
		if event.button_index in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
			dpad[event.button_index]=event.pressed; update_direction(); return true
		if not event.pressed: return true
		match event.button_index:
			JOY_BUTTON_A: activate()
			JOY_BUTTON_B: back()
			JOY_BUTTON_Y:
				if mode=="browser": games.open_default()
				elif mode in ["games","recent","favourites"]: games.game_title_action()
				else: reset_option()
			JOY_BUTTON_X:
				if mode=="browser": games.open_cards()
				elif mode in ["games","recent","favourites"]: games.toggle_favourite()
				else: toggle_preview()
			JOY_BUTTON_RIGHT_STICK: host.recenter()
			JOY_BUTTON_LEFT_SHOULDER:
				if mode=="browser": default_armed=false; games.open_folder(library.current_dir.get_base_dir())
				elif mode=="games": games.change_game_page(-1)
				else: switch_category(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				if mode=="browser": default_armed=not held.get(JOY_BUTTON_LEFT_SHOULDER,false)
				elif mode=="games": games.change_game_page(1)
				elif mode=="library": games.refresh_library()
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
		if mode in ["games","recent","favourites","videos"]:
			if event.pressed and not event.echo and event.ctrl_pressed and event.physical_keycode==KEY_F:
				clear_input(); search_field.grab_focus(); return true
			if search_field.has_focus():
				if event.pressed and event.physical_keycode in [KEY_DOWN,KEY_UP,KEY_ENTER,KEY_KP_ENTER]:
					search_field.release_focus(); select(selected_id,false); return true
				return false
		if mode in ["rename","radio_url","folder_path","video_search"] and get_viewport().gui_get_focus_owner()==rename_field:
			if event.pressed and event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER] and mode=="video_search": videos.run_video_search(); return true
			if event.pressed and event.physical_keycode==KEY_DOWN:
				select({"folder_path":"folder_path.open","radio_url":"radio.save","video_search":"video_search.go"}.get(mode,"rename.save")); return true
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
					if mode in ["games","recent","favourites"]: games.game_title_action()
					else: reset_option()
				KEY_X:
					if mode in ["games","recent","favourites"]: games.toggle_favourite()
					else: toggle_preview()
				KEY_J:
					if mode in ["games","recent","favourites"]: games.open_alphabet()
				KEY_R:
					if mode=="library": games.refresh_library()
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
	search_field.visible=kind=="keyboard" and mode in ["games","recent","favourites","videos"]
	if kind=="controller" and search_field.has_focus():
		search_field.release_focus(); select(selected_id,false)
	refresh_labels()

func update_search(value: String) -> void:
	remember(); clear_input(); search_query=value; games.game_page=0; videos.video_page=0; render()


























func open_help(title: String, copy: String) -> void:
	remember(); help_origin=snapshot(); help_title=title; help_copy=copy
	mode="help"; clear_input()
	if not memory.has(state_key()): memory[state_key()]={"id":"","scroll":0}
	render()


func apply_accessibility() -> void:
	host.power_on.reduced_motion=host.menu_reduced_motion
	if host.menu_reduced_motion and is_instance_valid(focus_tween): focus_tween.kill()
	refresh()

func style_rows() -> void:
	for row in rows:
		if row.item.get("layout","") in ["transport","card"]: continue
		var compact: bool = row.item.get("compact",false)
		var hero: bool=row.item.get("hero",false)
		row.title_label.add_theme_font_size_override("font_size",(23 if host.menu_large_text else 20) if compact else ((32 if host.menu_large_text else 29) if hero else (27 if host.menu_large_text else 24)))
		row.value_label.add_theme_font_size_override("font_size",(21 if host.menu_large_text else 18) if compact else (25 if host.menu_large_text else 22))
		row.sync_content_height()
		if host.menu_high_contrast:
			row.title_label.add_theme_color_override("font_color",Color.WHITE)
			row.value_label.add_theme_color_override("font_color",Color.WHITE)
			row.unavailable_label.add_theme_color_override("font_color",Color("dddddd"))
	if host.menu_high_contrast: add_theme_stylebox_override("panel",MenuSkin.box(Color("080a0d"),Color("cccccc"),1,18))
	else: remove_theme_stylebox_override("panel")






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
