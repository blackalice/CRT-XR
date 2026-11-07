extends RefCounted
## First-run setup: a short run of pages, in the menu's own look, that teaches
## the menu shortcut and sets up the view, console region, game library, videos
## and music, and comfort options. New users see it once, straight from the boot
## animation; Help & system → Run setup again shows it any time.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const InputGlyph = preload("res://scripts/ui/input_glyph.gd")
const RowIcon = preload("res://scripts/ui/row_icon.gd")
const ConsoleGlyph = preload("res://scripts/ui/console_glyph.gd")
const Registry = preload("res://scripts/emulation/core_registry.gd")
const LOGO := preload("res://assets/branding/logo/boot-logo.svg")
const DIAMONDS := [preload("res://assets/branding/logo/boot-diamond-0.svg"), preload("res://assets/branding/logo/boot-diamond-1.svg"), preload("res://assets/branding/logo/boot-diamond-2.svg")]
## The boot logo is drawn at 348×400; the Welcome page holds it at two thirds.
const LOGO_SIZE := Vector2(232, 266)
const STEPS := ["welcome", "controls", "view", "region", "library", "found", "media", "comfort", "done"]
## Welcome and All set sit outside the six numbered steps; both library pages are step 4.
const NUMBERS := {"controls": 1, "view": 2, "region": 3, "library": 4, "found": 4, "media": 5, "comfort": 6}
const TITLES := {"controls": "Controls", "view": "Your view", "region": "Console names & icons", "library": "Game library",
	"found": "Game library", "media": "Videos & music", "comfort": "Comfort", "done": "You're all set"}
## The consoles the region page shows; their names and pictures follow the region.
const PREVIEW_CONSOLES := ["snes", "nes", "megadrive", "pcengine", "dreamcast"]
const REGION_CHOICES := [["pal", "PAL", "Europe and Australia: SNES, Mega Drive and PC Engine names and pictures."],
	["ntsc", "NTSC", "The Americas: SNES, Genesis and TurboGrafx-16 names and pictures."],
	["japan", "Japan", "Japanese names and pictures: Super Famicom, Famicom and Mark III."]]
## Countries that sold the NTSC (American) consoles under their American names.
const NTSC_COUNTRIES := ["US", "CA", "MX", "BR", "AR", "CL", "CO", "PE", "VE", "EC", "BO", "UY", "PY", "CR", "PA", "GT", "HN", "SV", "NI", "DO", "PR", "CU"]
var host: Node
var menu: Control
var step := "welcome"
## True from opening until finishing; reopening the menu returns here.
var active := false
## The menu shortcut was pressed on the Controls page.
var shortcut_done := false
## While a picker from elsewhere in the menu chooses something for setup
## ("library", "video" or "music"), its "Use this folder" returns here.
var choosing := ""
## The Welcome page's logo, where the boot animation's logo lands.
var logo: Control
var region_suggested := false
var keep_display_preferences := false

func open(at := "welcome") -> void:
	menu.remember(); menu.clear_input()
	active = true; shortcut_done = false; choosing = ""
	keep_display_preferences = host.welcome_done
	step = at; menu.mode = "welcome"; menu.preview = false
	menu.error_label.hide()
	menu.memory.erase(menu.state_key())
	menu.render()

## Back to setup from a picker it opened, or after the menu was closed and reopened.
func resume() -> void:
	menu.remember(); menu.clear_input(); choosing = ""
	menu.mode = "welcome"; menu.preview = false
	menu.render()

func go(next: String) -> void:
	menu.remember(); menu.clear_input(); menu.error_label.hide()
	step = next
	if step == "region" and not region_suggested:
		region_suggested = true
		# A first run starts from the region the system language suggests; running
		# setup again keeps the region already chosen.
		if not host.welcome_done: host.apply_console_region(suggested_region(OS.get_locale()))
	menu.render()

func back() -> void:
	match step:
		"welcome": return
		"found": go("library")
		"media": go("found" if not host.default_rom_dir.is_empty() else "library")
		_: go(STEPS[maxi(0, STEPS.find(step) - 1)])

## Skip setup goes to All set, which still shows the menu shortcut.
func skip() -> void:
	if step != "done": go("done")

## Ends setup, remembering it is done, then opens the library or Home.
func finish(library := false) -> void:
	active = false; choosing = ""
	host.welcome_done = true
	host.save_settings()
	if library: menu.games.open_library()
	else: menu.open_pause()

## The menu shortcut (or Escape) while setup is showing. On the Controls page it
## is the lesson; elsewhere it says how to leave, rather than closing setup.
func menu_shortcut() -> void:
	if step == "controls":
		if shortcut_done: return
		shortcut_done = true
		menu.play_menu_sound(true)
		host.menu_vibrate(1.0, 0.12)
		menu.remember(); menu.render()
		return
	menu.notify("That's the menu shortcut. Finish setup, or press {X} to skip it.")

static func suggested_region(locale: String) -> String:
	var parts := locale.replace("-", "_").split("_", false)
	var language := parts[0].to_lower() if parts.size() > 0 else ""
	var country := parts[1].to_upper() if parts.size() > 1 else ""
	if language == "ja" or country == "JP": return "japan"
	if country in NTSC_COUNTRIES: return "ntsc"
	return "pal"

func number() -> int:
	return int(NUMBERS.get(step, 0))

func title() -> String:
	return str(TITLES.get(step, "Welcome to CRT XR"))

func subtitle() -> String:
	return "First-run setup · Step %d of 6" % number() if number() > 0 else ""

func pinned(item: Dictionary) -> Dictionary:
	item["pinned"] = true
	item["compact"] = true
	return item

func next_row(next: String, label := "Next", help := "") -> Dictionary:
	return pinned(menu.catalog.action("welcome.next", label, func(): go(next), help))

## Footer prompts for the selected row.
func hints(row, pad: bool) -> Array:
	if menu.preview: return ["↑↓ Setting", "←→ Adjust", "Y Reset", ("B " if pad else "Backspace ") + "Done"]
	var parts: Array = []
	if row != null:
		match str(row.item.kind):
			"toggle": parts.append("←→ Change")
			"number", "choice": parts.append(("A Preview" if pad else "Enter Preview") if row.item.get("quick_preview", false) else "←→ Adjust")
			_: parts.append("A Select" if pad else "Enter Select")
		if row.item.has("default") and row.item.kind != "toggle": parts.append("Y Reset")
	if menu.scroll.get_v_scroll_bar().max_value > menu.scroll.size.y + 1.0: parts.append("↑↓ Scroll")
	if step != "welcome":
		var back_word := "Choose another folder" if step == "found" else "Back"
		parts.append(("B " if pad else "Backspace ") + back_word)
	if not step in ["welcome", "done"]: parts.append("X Skip setup")
	return parts

func items() -> Array:
	# Back on a setup page, any picker it opened has finished.
	choosing = ""
	var c = menu.catalog
	var h = host
	match step:
		"welcome":
			var start: Dictionary = c.action("welcome.start", "Let's get set up", func(): go("controls"), "", false, "")
			start["emphasis"] = "primary"
			return [start, c.action("welcome.skip", "Skip setup", skip, "", false, "")]
		"controls":
			return [pinned(c.action("welcome.next", "Continue" if shortcut_done else "Can't press it right now? Continue", func(): go("view"),
				"The game pauses while the menu is open. Close it with the same buttons, or choose Resume."))]
		"view": return view_items()
		"region": return region_items()
		"library": return library_items()
		"found":
			return [next_row("media", "Next", "Change or refresh this any time in Game Library › Library locations.")]
		"media": return media_items()
		"comfort": return comfort_items()
		"done":
			var library: Dictionary = menu.entry(c.action("welcome.library", "Open Game Library", func(): finish(true), "Run this setup again from Settings › Help & system › Run setup again.", false, "›"), "", "gamepad")
			library["emphasis"] = "primary"
			return [library, menu.entry(c.action("welcome.home", "Go to Home", func(): finish(false), "Run this setup again from Settings › Help & system › Run setup again.", false, "›"), "", "home")]
	return []

func tracking_working() -> bool:
	return host.provider.real and host.provider.valid

func view_items() -> Array:
	var c = menu.catalog
	var h = host
	var result: Array = []
	var games_tv: Dictionary = h.display_settings.policy_row("welcome.tv.games", keep_display_preferences)
	games_tv["section"] = "YOUR TV"
	games_tv["section_detail"] = "Either TV can show 4:3 or widescreen games. Fit adds borders; Fill crops; Stretch changes shape."
	result.append(games_tv)
	result.append(h.display_settings.video_tv_row("welcome.tv.videos"))
	var fitting_help: Dictionary = c.fitting_help("welcome.tv.help")
	fitting_help["compact"] = true
	result.append(fitting_help)
	if not tracking_working():
		result.append(menu.tile(c.action("welcome.view.connect", "Connect glasses", func(): h.use_tracking(true); menu.refresh(), "Connects or retries the glasses' head tracking.", false, ""), "glasses", "", "tracking", 2))
		result.append(menu.tile(c.action("welcome.view.fixed", "Use fixed view", func(): h.use_tracking(false); h.recenter(); menu.refresh(), "Keeps the TV still. This is also how CRT XR plays on a normal screen.", false, ""), "view", "", "tracking", 2))
	var recentre: Dictionary = c.action("welcome.view.recentre", "Look straight ahead, then press", func(): h.recenter(); menu.notify("View recentred"), "Centres the TV in front of you. {R3} does this any time, in a game too.", false, "")
	recentre["row_icon"] = "view"; recentre["value_inputs"] = ["R3"]
	result.append(recentre)
	for source in c.pages(0)[0].rows:
		if source.id in ["view.distance", "view.height_offset"]:
			var copy: Dictionary = source.duplicate()
			copy.id = "welcome." + str(source.id)
			copy["section"] = "TV POSITION"
			copy["row_icon"] = "tv" if source.id == "view.distance" else "up"
			# As on the pause menu: A or left/right opens the preview, where the room shows the TV move.
			copy["quick"] = true; copy["quick_preview"] = true
			copy.help = ("Moves the whole TV and table nearer or farther. The right stick does this while you play, too." if source.id == "view.distance" else "Moves the screen, stand and room up or down.") + " {A} previews it with the room in view."
			result.append(copy)
	result.append({"id": "welcome.view.menu", "label": "Menu position", "kind": "choice", "choices": ["On the TV", "Floating"], "default": 0,
		"section": "MENU", "row_icon": "home", "visual": false,
		"getter": func(): return 0 if h.menu_on_tv else 1,
		"setter": func(value): h.menu_on_tv = int(value) == 0; menu.refresh(),
		"help": "Choose where menus appear after this step. This page floats so you can see and position either TV without moving the controls."})
	result.append(next_row("region"))
	return result

func region_items() -> Array:
	var c = menu.catalog
	var h = host
	var suggestion := suggested_region(OS.get_locale())
	var result: Array = []
	for choice in REGION_CHOICES:
		var id: String = choice[0]
		var item: Dictionary = c.action("welcome.region." + id, choice[1], func():
			h.apply_console_region(id); menu.refresh(), choice[2], false, "Suggested" if id == suggestion else "")
		item.merge({"layout": "tile", "group": "regions", "columns": 3, "expanded": h.console_region == id}, true)
		if h.console_region == id: item["row_icon"] = "check"
		result.append(item)
	result.append(next_row("library", "Next", "Also in Settings › Menu & access › Layout & placement › Console names & icons."))
	return result

## "SD card · Emulation/roms" or "Deck storage · Emulation/roms" for a found folder.
func place_name(path: String) -> String:
	for mount in menu.library.cards():
		if path.begins_with(mount): return "SD card · " + path.substr(str(mount).length()).trim_prefix("/")
	var home: String = menu.library.home_folder()
	if not home.is_empty() and path.begins_with(home):
		return ("Deck storage" if menu.deck_controls else "Home folder") + " · " + path.substr(home.length()).trim_prefix("/").trim_prefix("\\")
	return menu.short_path(path)

func choose_library(path: String) -> void:
	if menu.games.set_default(path): go("found")

## A picker elsewhere in the menu chose the library folder.
func library_chosen() -> void:
	choosing = ""; menu.mode = "welcome"; go("found")

func library_items() -> Array:
	var c = menu.catalog
	var result: Array = []
	var found_section := "FOUND ON THIS DECK" if menu.deck_controls else "FOUND ON THIS COMPUTER"
	var candidates: Array = Array(menu.library.Locations.library_candidates(menu.library.home_folder(), menu.library.Locations.sd_cards()))
	var current: String = host.default_rom_dir
	if not current.is_empty() and not current in candidates:
		result.append(menu.entry(c.action("welcome.library.current", "Keep your current folder", func(): choose_library(current), "Your games stay where they are.", false, "Use ›"), found_section, "check", "", current))
	for candidate in candidates:
		var path: String = candidate
		var on_card: bool = menu.library.cards().any(func(mount): return path.begins_with(mount))
		result.append(menu.entry(c.action("welcome.library.found:" + path, place_name(path), func(): choose_library(path), "Every supported console inside is found for you. Your files stay where they are.", false, "Use ›"), found_section, "sd" if on_card else "drive", "", path))
	if result.is_empty():
		result.append(menu.entry(c.unavailable(c.action("welcome.library.none", "No ROM folder found automatically", func(): pass, "", true, ""), "Browse to it, or type its path, below."), found_section, "search"))
	var find := "OR FIND IT YOURSELF"
	result.append(menu.tile(c.action("welcome.library.browse", "Browse folders", func(): choosing = "library"; menu.games.browse_folders(), "Browse to the folder holding snes, nes, megadrive and the rest, then choose Use this folder.", false, ""), "folder", "", "find", 3))
	if OS.get_name() == "Windows":
		result.append(menu.tile(c.action("welcome.library.drives", "Computer drives", func(): choosing = "library"; menu.games.open_drives(), "Choose a drive, then browse to your ROM folder.", false, ""), "drive", "", "find", 3))
	else:
		result.append(menu.tile(c.action("welcome.library.sd", "SD card", func(): choosing = "library"; menu.games.open_cards(), "Browse a mounted SD card.", false, ""), "sd", "", "find", 3))
	result.append(menu.tile(c.action("welcome.library.path", "Type a path", func(): choosing = "library"; menu.games.enter_folder_path(), "Enter a folder or a network share path.", false, ""), "network", "", "find", 3))
	for item in result.slice(result.size() - 3): item["section"] = find
	result.append(pinned(c.action("welcome.library.later", "Not now: I'll add games later", func(): go("media"), "Plain files or single-game ZIPs. Box art scraped by EmuDeck, ES-DE or RetroDECK shows automatically.")))
	return result

func media_items() -> Array:
	var c = menu.catalog
	var h = host
	var result: Array = []
	if menu.videos.VideoSession.available():
		var video: Dictionary = menu.entry(c.action("welcome.media.video", "Choose a video folder", func(): choosing = "video"; menu.videos.open_video_folder_picker(), "Nothing is copied or moved. Your files stay where they are.", false, "›"), "", "video", "",
			("Using " + menu.short_path(h.video_dir)) if not h.video_dir.is_empty() else "Kick back and watch MP4, M4V and MKV files with realistic VHS simulation.")
		result.append(video)
	else:
		result.append_array(menu.videos.video_setup_items(""))
	result.append(menu.entry(c.action("welcome.media.music", "Choose a music folder", func(): choosing = "music"; menu.music.open_music_browser(h.music_folder), "Nothing is copied or moved. Your files stay where they are.", false, "›"), "", "music", "",
		("Using " + menu.short_path(h.music_folder)) if not h.music_folder.is_empty() else "Listen to MP3s while you game, or immerse yourself in the music visualizer."))
	result.append(next_row("comfort"))
	return result

## The music browser chose a folder for setup.
func music_chosen(path: String) -> void:
	var previous: String = host.music_folder
	host.music_folder = path
	if host.save_library() != OK:
		host.music_folder = previous
		menu.show_error("The music folder could not be saved. Check that user storage is writable.")
		return
	resume(); menu.notify("Music folder ready.")

func comfort_items() -> Array:
	var c = menu.catalog
	var h = host
	var pictures = menu.pictures
	var descriptions := ["Keep your current picture.", "Crisp source pixels; scanlines and phosphor effects off.",
		"Clean RGB colour with a defined CRT beam.", "Composite character matched to the game’s frame rate.",
		"Soft PAL colour blending and analog texture.", "NTSC colour bleed and classic composite artifacts."]
	var custom: bool = not pictures.applied_preset() in pictures.PRESET_IDS
	var offset: int = 1 if custom else 0
	var picture := {"id": "welcome.picture", "label": "Picture style", "kind": "choice", "choices": (["Current picture"] if custom else []) + pictures.PRESET_NAMES, "section": "PICTURE", "row_icon": "tv", "visual": false,
		"getter": func(): return pictures.PRESET_IDS.find(pictures.applied_preset()) + offset,
		"setter": func(value):
			if int(value) >= offset: pictures.apply_preset(pictures.PRESET_IDS[int(value) - offset]),
		"detail_getter": func(): return descriptions[pictures.PRESET_IDS.find(pictures.applied_preset()) + 1],
		"help": "More looks, and your own, in Settings › TV & picture › Presets."}
	var rows: Array = [picture]
	for spec in [["welcome.clean", "Clearer menus", "menu_clean_feed", false, "Shows menus without CRT distortion while keeping your game picture.", func(): menu.refresh(), "tv"],
			["welcome.large", "Larger menu text", "menu_large_text", false, "Bigger text and taller rows.", menu.apply_accessibility, "search"],
			["welcome.motion", "Reduced animation", "menu_reduced_motion", false, "No TV warm-up, boot animation or drifting stars.", menu.apply_accessibility, "refresh"],
			["welcome.music", "Menu music", "menu_music_enabled", true, "Quiet background music in the menus.", h.apply_menu_music, "music"],
			["welcome.haptics", "Menu vibration", "menu_haptics", false, "A light tick as the selection moves.", func(): menu.refresh(), "gamepad"]]:
		var row: Dictionary = c.toggle(spec[0], spec[1], h, spec[2], spec[3], spec[4] + " More in Settings › Menu & access › Accessibility.", spec[5], false)
		row["section"] = "READING AND MOTION"; row["row_icon"] = spec[6]
		rows.append(row)
	rows.append(next_row("done", "Finish"))
	return rows

# ── Page decorations: the parts of a page that are not rows ──────────────────

## Wrapping text; `wrap` false keeps a label to one line, as it must be beside
## other controls in a row (a wrapping label there shrinks to one letter wide).
func text(words: String, size := 19, colour := MenuSkin.TEXT, centred := false, wrap := true) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", size + (3 if host.menu_large_text else 0))
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if centred: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuSkin.shadow(label)
	return label

func heading(words: String) -> Label:
	var label := text(words, 16, MenuSkin.MUTED)
	MenuSkin.weigh(label, MenuSkin.BOLD)
	return label

## A recessed well, as the menu draws its panels, holding `inside`.
func well(inside: Control, margin := 14) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(MenuSkin.pixel_panel("well"))
	var inset := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]: inset.add_theme_constant_override("margin_" + side, margin)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inset); inset.add_child(inside)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

## A raised panel, as an unselected row, holding `inside`.
func plate(inside: Control, margin := 10) -> PanelContainer:
	var panel := well(inside, margin)
	panel.get_child(0).material = MenuSkin.panel_material("row")
	return panel

## The CRT XR logo, built as the boot animation builds it, so the boot's logo can land on it.
func make_logo() -> Control:
	var image := TextureRect.new()
	image.name = "WelcomeLogo"
	image.texture = LOGO
	image.custom_minimum_size = LOGO_SIZE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for texture in DIAMONDS:
		var diamond := TextureRect.new()
		diamond.texture = texture
		diamond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		diamond.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		diamond.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.add_child(diamond)
		diamond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return image

func console_tile(system: String, caption: String) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var glyph := ConsoleGlyph.new()
	glyph.kind = str(Registry.SYSTEMS.get(system, {}).get("icon", system))
	glyph.custom_minimum_size = Vector2(64, 64)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(glyph)
	box.add_child(text(caption, 17, MenuSkin.TEXT, true))
	return box

## Adds the page's own pieces around its rows, after the menu has built them.
func decorate() -> void:
	logo = null
	var column: VBoxContainer = menu.column
	var top: Array[Control] = []
	match step:
		"welcome": decorate_welcome(column); return
		"controls": top = controls_parts()
		"view": top = [view_status()]
		"region":
			top = [text("Which consoles did you grow up with? Names and pictures follow your region.", 18)]
			var grid := GridContainer.new(); grid.columns = PREVIEW_CONSOLES.size()
			grid.add_theme_constant_override("h_separation", 6)
			for system in PREVIEW_CONSOLES:
				if Registry.SYSTEMS.has(system): grid.add_child(console_tile(system, str(Registry.SYSTEMS[system].name)))
			for part in [heading("YOUR LIBRARY WILL SHOW (and more!)"), well(grid, 12),
					text("Suggested from your system language (%s). Games, saves and folder names aren't affected." % OS.get_locale(), 16, MenuSkin.MUTED)]:
				column.add_child(part)
		"library":
			top = [text("Choose your main ROM folder: the one holding snes, nes, megadrive and the rest.\nEvery supported console inside is found for you.", 18)]
		"found": top = found_parts()
		"media":
			top = [text("This TV plays more than games. Point CRT XR at your own videos and albums now, or later from Home.", 18)]
		"done": top = done_parts()
	for i in range(top.size()):
		column.add_child(top[i]); column.move_child(top[i], i)

func decorate_welcome(column: VBoxContainer) -> void:
	var page := VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 14)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	logo = make_logo()
	page.add_child(logo)
	var title_label := Label.new()
	title_label.text = "Welcome to CRT XR"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	MenuSkin.weigh(title_label, MenuSkin.BOLD)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_outline_color", MenuSkin.SHADOW)
	title_label.add_theme_constant_override("outline_size", 6)
	title_label.add_theme_color_override("font_shadow_color", MenuSkin.SHADOW)
	title_label.add_theme_constant_override("shadow_offset_x", 3); title_label.add_theme_constant_override("shadow_offset_y", 3)
	var chrome := ShaderMaterial.new(); chrome.shader = preload("res://shaders/menu_chrome.gdshader"); title_label.material = chrome
	title_label.resized.connect(func(): chrome.set_shader_parameter("height", title_label.size.y))
	page.add_child(title_label)
	page.add_child(text("Let's get your controls, view and games ready.\nIt takes about two minutes.", 20, MenuSkin.TEXT, true))
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.custom_minimum_size.x = 480
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(actions)
	for row in menu.rows:
		row.get_parent().remove_child(row); actions.add_child(row)
		row.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(text("Everything here can be changed later in Settings.", 16, MenuSkin.MUTED, true))
	# Fill the visible page so the welcome sits in its middle. The page's height is
	# known once this layout (without the title bar) has settled.
	page.custom_minimum_size.y = 560
	column.add_child(page)
	fill_page.call_deferred(page)

func fill_page(page: Control) -> void:
	await menu.get_tree().process_frame
	if is_instance_valid(page) and menu.scroll.size.y > 100.0: page.custom_minimum_size.y = menu.scroll.size.y - 8.0

func controls_parts() -> Array[Control]:
	var pad: bool = menu.input_kind == "controller"
	var lit := shortcut_done
	var inside := VBoxContainer.new()
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.add_theme_constant_override("separation", 10)
	inside.add_child(text("Open the menu from any game", 22, MenuSkin.TEXT, true))
	var keys: Control = InputGlyph.row("L1 + R1 + Start", 60.0, 30, MenuSkin.MUTED) if pad else InputGlyph.new("Esc", 60.0)
	keys.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if keys is HBoxContainer: keys.add_theme_constant_override("separation", 12)
	for glyph in ([keys] if keys is InputGlyph else keys.get_children()):
		if glyph is InputGlyph: glyph.colour = MenuSkin.AMBER if lit else Color("e6e6e6"); glyph.drop_shadow = true
	inside.add_child(keys)
	inside.add_child(text("Got it. That's the menu shortcut." if lit else ("Try it now: press them together to continue" if pad else "Try it now: press Esc to continue"), 18, MenuSkin.VALUE, true))
	if not lit: inside.add_child(text("Shown for the controller you last used." if pad else "Using a controller? Press L1 + R1 + Start.", 15, MenuSkin.MUTED, true))
	var handy := GridContainer.new(); handy.columns = 3
	handy.add_theme_constant_override("h_separation", 8)
	for spec in [["R3" if pad else "R", "Recentre the view"], ["B" if pad else "Backspace", "Back, in any menu"], ["rs_up rs_down" if pad else "PgUp / PgDn", "Move the TV nearer or farther"]]:
		var cell := HBoxContainer.new(); cell.add_theme_constant_override("separation", 10)
		var control: Control
		if pad: control = InputGlyph.row(spec[0], 34.0, 16, MenuSkin.MUTED)
		else: control = key_chip(spec[0])
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(control)
		var words := text(spec[1], 17)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(words)
		var tile := plate(cell, 12)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		handy.add_child(tile)
	return [heading("THE ONE TO REMEMBER"), well(inside, 14), heading("ALSO HANDY"), handy]

func view_status() -> Control:
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 14)
	line.add_child(RowIcon.new("glasses", MenuSkin.TEXT))
	var words := VBoxContainer.new(); words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_text := "Playing on this screen"
	var detail := "The TV stays still. Connect glasses later in View & glasses › Tracking."
	var dot := MenuSkin.MUTED
	if tracking_working():
		title_text = "Head tracking is on"; detail = str(host.provider.status); dot = Color("58d878")
	elif host.provider.real:
		title_text = "Glasses found, but no head tracking yet"; dot = MenuSkin.AMBER
		detail = "Check the VITURE SDK is beside CRT-XR.exe, or use OpenTrack in View & glasses › Tracking." if OS.get_name() == "Windows" else "Check XR Gaming in Decky can see the glasses, then connect."
	words.add_child(text(title_text, 20)); words.add_child(text(detail, 16, MenuSkin.MUTED))
	line.add_child(words)
	var light := ColorRect.new(); light.color = dot; light.custom_minimum_size = Vector2(12, 12)
	light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(light)
	return well(line, 12)

## The consoles found, with any BIOS they need and anything skipped.
func found_parts() -> Array[Control]:
	var index = menu.rom_index
	var parts: Array[Control] = []
	var place := place_name(host.default_rom_dir) if not host.default_rom_dir.is_empty() else ""
	var systems: Array = []
	for system in Registry.SYSTEMS:
		if index.games.get(system, []).size() > 0: systems.append(system)
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 12)
	if index.scanning:
		line.add_child(RowIcon.new("scan", MenuSkin.AMBER))
		line.add_child(text("Finding your games… %d found" % index.total(), 22, MenuSkin.TEXT, false, false))
	elif systems.is_empty():
		line.add_child(text("No games found here yet", 24, MenuSkin.VALUE, false, false))
	else:
		line.add_child(text(menu.count_caption(index.total(), "game"), 28, MenuSkin.VALUE, false, false))
		line.add_child(text("across " + menu.count_caption(systems.size(), "console"), 20, MenuSkin.TEXT, false, false))
	var where := text(place, 16, MenuSkin.MUTED)
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL; where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	where.autowrap_mode = TextServer.AUTOWRAP_OFF; where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(where)
	parts.append(line)
	if systems.is_empty() and not index.scanning:
		var reason: String = index.message if not str(index.message).is_empty() else "Check this is the folder holding snes, nes, megadrive and the rest. Press {B} to choose another folder."
		parts.append(well(text(reason.replace("{B}", "B"), 17), 12))
		return parts
	# The grid flexes to the library: big tiles for a few consoles, four compact columns for many.
	var grid := GridContainer.new()
	grid.columns = 2 if systems.size() <= 2 else (3 if systems.size() <= 9 else 4)
	grid.add_theme_constant_override("h_separation", 6); grid.add_theme_constant_override("v_separation", 6)
	for system in systems:
		var spec: Dictionary = Registry.SYSTEMS[system]
		var chip := HBoxContainer.new(); chip.add_theme_constant_override("separation", 10)
		var glyph := ConsoleGlyph.new(); glyph.kind = str(spec.get("icon", system))
		# Console sprites are drawn at twice their 32-pixel size on the menu's grid.
		glyph.custom_minimum_size = Vector2(64, 64)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(glyph)
		var words := VBoxContainer.new(); words.add_theme_constant_override("separation", 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL; words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name_label := text(str(spec.name), 18 if grid.columns < 4 else 16)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF; name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.add_child(name_label)
		words.add_child(text(menu.count_caption(index.games[system].size(), "game"), 14, MenuSkin.MUTED))
		chip.add_child(words)
		if not Registry.bios_satisfied(system): chip.add_child(tag("BIOS", MenuSkin.AMBER))
		var tile := plate(chip, 8 if grid.columns < 4 else 6)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
	parts.append(grid)
	var notes := notes_for(systems)
	if not notes.is_empty():
		var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 8)
		for note in notes:
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
			var badge := tag(note[0], note[1]); badge.custom_minimum_size.x = 84
			badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(badge)
			var words := text(note[2], 16); words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(words)
			list.add_child(row)
		parts.append(heading("WORTH KNOWING"))
		parts.append(well(list, 12))
	return parts

## [tag, colour, text] for each thing worth knowing about the library just found.
func notes_for(systems: Array) -> Array:
	var notes: Array = []
	var index = menu.rom_index
	for system in systems:
		var spec: Dictionary = Registry.SYSTEMS[system]
		if not Registry.bios_satisfied(system):
			notes.append(["NEEDED", MenuSkin.AMBER, "%s games need the console's BIOS, such as %s, in the bios folder beside your ROM folder." % [spec.name, spec.bios_any[0]]])
	for system in systems:
		var spec: Dictionary = Registry.SYSTEMS[system]
		if spec.has("bios_optional") and not spec.has("bios_any") and spec.bios_optional.all(func(name): return Registry.bios_file(name).is_empty()):
			notes.append(["OPTIONAL", MenuSkin.MUTED, "%s runs without a BIOS; a real one can improve compatibility." % spec.name])
	if index.ignored_system_folders > 0:
		notes.append(["SKIPPED", Color("e87870"), "%s for consoles CRT XR doesn't support yet." % menu.count_caption(index.ignored_system_folders, "folder")])
	if not index.scanning and not str(index.message).is_empty():
		notes.append(["NOTE", MenuSkin.MUTED, str(index.message)])
	return notes

func tag(words: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("301800") if colour.get_luminance() > 0.45 else MenuSkin.TEXT)
	label.add_theme_stylebox_override("normal", MenuSkin.box(colour, Color.TRANSPARENT, 0, 2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuSkin.weigh(label, MenuSkin.BOLD)
	return label

func done_parts() -> Array[Control]:
	var h = host
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16); grid.add_theme_constant_override("v_separation", 8)
	var games: int = menu.rom_index.total()
	var consoles: int = menu.rom_index.games.values().filter(func(found): return not found.is_empty()).size()
	var library := "Not set up yet: add games from Game Library"
	if not h.default_rom_dir.is_empty(): library = (menu.count_caption(games, "game") + " · " + menu.count_caption(consoles, "console")) if games > 0 else place_name(h.default_rom_dir)
	var tracking := "On · " + str(h.provider.status) if tracking_working() else "Fixed view"
	var preset: String = menu.pictures.applied_preset()
	var picture: String = menu.pictures.PRESET_NAMES[menu.pictures.PRESET_IDS.find(preset)] if preset in menu.pictures.PRESET_IDS else "Custom"
	var media: Array = []
	if not h.video_dir.is_empty(): media.append("Videos")
	if not h.music_folder.is_empty(): media.append("Music")
	var region_index: int = maxi(0, Registry.REGIONS.find(h.console_region))
	for pair in [["Console names & icons", Registry.REGION_LABELS[region_index]], ["Game library", library], ["Head tracking", tracking],
			["Games TV", h.display_settings.TV_POLICY_NAMES[h.display_settings.TV_POLICIES.find(h.display_settings.data.game_tv_policy)] if h.display_settings.data.game_tv_policy in h.display_settings.TV_POLICIES else "Current console preferences"],
			["Videos TV", "Wide TV (16:9)" if h.display_settings.data.defaults.video == "wide" else "Standard TV (4:3)"],
			["Menu", "On the TV" if h.menu_on_tv else "Floating"], ["Picture", picture],
			["Videos, music", " and ".join(media) + " ready" if not media.is_empty() else "Not set up yet: add them from Home"]]:
		var key := text(pair[0], 18, MenuSkin.MUTED); key.custom_minimum_size.x = 190
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		var value := text(pair[1], 18); value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(key); grid.add_child(value)
	var pad: bool = menu.input_kind == "controller"
	var shortcut := HBoxContainer.new(); shortcut.add_theme_constant_override("separation", 12)
	shortcut.add_child(text("Menu any time", 19, MenuSkin.TEXT, false, false))
	shortcut.add_child(InputGlyph.row("L1 + R1 + Start", 34.0, 18, MenuSkin.MUTED) if pad else key_chip("Esc"))
	var gap := Control.new(); gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; shortcut.add_child(gap)
	shortcut.add_child(text("Recentre", 19, MenuSkin.TEXT, false, false))
	shortcut.add_child(InputGlyph.new("R3", 34.0) if pad else key_chip("R"))
	return [well(grid, 14), well(shortcut, 12)]

func key_chip(words: String) -> Label:
	var chip: Label = menu.key_hint(); chip.text = words; chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip
