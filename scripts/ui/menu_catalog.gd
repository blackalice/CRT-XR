extends RefCounted
## Explicit ordered rows and stable IDs; bindings reuse the application's
## existing actions and preferences rather than a second settings store.
const GameTitle = preload("res://scripts/content/game_title.gd")
const VideoSession = preload("res://scripts/video/video_session.gd")
## Help pages, in the help page markup (scripts/ui/help_article.gd): the
## controller button first, then its keyboard key.
const CONTROLS_GUIDE := """## Anywhere
L1 + R1 + Start | Escape :: Open or close the menu
R3 | R :: Recentre the view
F3 :: Flat screen on or off
## In the menu
D-pad | Arrows :: Move
A | Enter :: Select
B | Backspace :: Back
L1 / R1 | Q / E :: Change category
L2 / R2 | Z / C :: Change section
Y :: Reset an option to its default
X :: Preview the picture"""
const WEBSITE := "stua.rtfoy.co.uk"
const PROJECT_PAGE := "github.com/blackalice/CRT-XR"
const TV_FITTING_GUIDE := """## TV model and game shape are separate
Standard TV has a 4:3 screen. Wide TV has a 16:9 screen. Either TV can show a 4:3 game, a widescreen game or a handheld's picture.
Choosing the TV changes the cabinet. It does not change the console's rendering or force games into that screen's shape.
## How the picture fills the TV
Fit := Keeps the complete image and its proportions. Adds borders where the game and TV shapes differ. This is the setup default.
Fill := Keeps proportions and fills the TV by cutting off part of the image.
Stretch := Shows the full image across the TV, changing its proportions when the shapes differ.
## A 4:3 game on the wide TV
Fit := Side borders; the game keeps its normal shape.
Fill := Cuts off the top and bottom to fill the wider screen.
Stretch := Makes the picture wider, including characters and circles.
## A 16:9 game on the standard TV
Fit := Borders above and below; the game keeps its normal shape.
Fill := Cuts off the left and right edges.
Stretch := Squeezes the picture horizontally to fit the narrower screen.
## Which consoles use which shape?
Most older TV-console games, including NES, SNES, Mega Drive and PlayStation, normally target a 4:3 TV. They can still play on the wide TV with side borders.
PSP games normally use a widescreen picture. Handhelds such as Game Boy and Game Boy Advance have their own shapes; Fit preserves those too.
PS2 and GameCube depend on the game. Many games are 4:3; some have a widescreen option. A wide TV alone does not enable that option.
Choose by console selects the wide cabinet for PS2, GameCube and PSP, and the standard cabinet for others. It still uses Fit, so a 4:3 PS2 game gets side borders on the wide TV.
## Console defaults and individual games
Setup chooses the starting TV for consoles. Console and individual-game overrides take priority.
During play, the pause menu's TV & fit tile chooses the TV and Fit, Fill or Stretch for this game.
For separate controls, open Picture → Fit & TV. Apply changes to chooses This game for an exception or Console defaults for every game on that console; TV for this game picks the cabinet and Fit picks how the picture fills it.
Leave Game shape on Automatic normally. If a game's own widescreen mode produces a squeezed picture, choose 16:9 under Game shape. Stretch is a deliberate shape change, not a substitute for enabling widescreen in the game."""

func fitting_help(id: String) -> Dictionary:
	return action(id, "TVs, game shape & fitting", func(): menu.open_help("TVs & picture fitting", TV_FITTING_GUIDE), "See 4:3 on a wide TV, Fit / Fill / Stretch, and console-specific examples.")
const TROUBLESHOOTING_GUIDE := """!! Tracking unavailable
Reconnect the glasses in View & glasses → Tracking, or choose Use fixed view.

!! Double image
Match the glasses' SBS mode with View & glasses → Stereo & comfort → Side-by-side 3D.

!! Missing games
Check Game Library → Library locations. Games can be plain files or ZIPs for a supported console. Sega CD discs can be .cue/.bin, or CHD in a Sega CD folder. 7z and RAR aren't supported.

!! No radio
Use a direct MP3 stream URL.

!! Save failed
Check free space and the save folder's permissions."""
var host: Node
var menu: Control

## About CRT XR, in the help page markup: the animated logo, what it is, and who made it.
func about_page() -> String:
	return "
".join([
		"@@ logo",
		"A little CRT room for your XR glasses: your games and videos on a 90s TV, in a room you can light, furnish and settle into.",
		"## About",
		"Version := " + str(ProjectSettings.get_setting("application/config/version")),
		"Running on := %s · Godot %s" % [OS.get_name(), Engine.get_version_info().string],
		"Made by := Stuart Foy",
		"Website := " + WEBSITE,
		"Source and updates := " + PROJECT_PAGE,
		"> CRT XR is free and in beta. Bug reports, results with your glasses and ideas are all welcome on GitHub.",
		"## Thanks",
		"Built with Godot and the libretro emulator cores. Their authors and licences are under Credits & licences."])

func action(id: String, label: String, callback: Callable, help := "", disabled := false, value := "›") -> Dictionary:
	return {"id":id,"label":label,"kind":"action","action":callback,"help":help,"disabled":disabled,"value":value}

# Says why a greyed-out row is unavailable, inline under its title.
func unavailable(item: Dictionary, reason: String) -> Dictionary:
	if item.get("disabled",false): item.disabled_reason=reason
	return item

func number(id: String, label: String, target: Object, key: String, low: float, high: float, step: float, fallback: float, unit: String, help: String, changed: Callable, visual := true) -> Dictionary:
	return {"id":id,"label":label,"kind":"number","min":low,"max":high,"step":step,"default":fallback,"unit":unit,"help":help,"visual":visual,
		"getter":func(): return target.get(key),"setter":func(value): target.set(key,value); changed.call()}

func toggle(id: String, label: String, target: Object, key: String, fallback: bool, help: String, changed: Callable, visual := true) -> Dictionary:
	return {"id":id,"label":label,"kind":"toggle","default":fallback,"help":help,"visual":visual,
		"getter":func(): return target.get(key),"setter":func(value): target.set(key,value); changed.call()}

## Icons for settings rows that lead somewhere or do something, by row id.
const ROW_ICONS := {"view.fit":"fit","view.recenter":"view","tracking.fixed":"view","tracking.recenter":"view",
	"system.version":"help","system.setup":"refresh","system.glasses":"help","system.device":"help","system.controls":"help","system.help":"help","system.credits":"help"}

## Rows that only change the room, the TV's place or the TV's glass, which flat
## screen mode does not show. Room presets, its sounds and the tube whine still
## apply. The flat picture is drawn without the tube's curve or its glass.
const FLAT_UNUSED := ["view.distance","view.height_offset","view.tv_scale","view.fit","view.scene_msaa","view.edge_fade","access.tv",
	"crt.glass_reflections","crt.screen_curvature"]
const FLAT_ROOM_KEPT := ["room.preset","room.custom","room.ambience","room.ambience_level","room.crt_whine"]
## The TV model only shapes the flat screen in TV's shape; on the whole display
## it changes nothing.
const FLAT_WHOLE_UNUSED := ["picture.cabinet","picture.tv_policy","picture.video_policy"]
## Rows that Basic settings leave out: fine-tuning most people never need. They
## keep working at their current values; Show advanced settings brings them back.
const ADVANCED := ["tracking.diagnostics","view.tv_scale","view.distance_speed","view.edge_fade","view.scene_msaa",
	"view.ipd","view.convergence","view.vertical_fov","view.smoothing","view.motion_predict",
	"picture.beam_softness","picture.vignette","picture.gamma","picture.hue","picture.composite_strength","picture.artifact_strength","picture.phase_noise","picture.signal_motion",
	"picture.width","picture.height","picture.shift_x","picture.shift_y","picture.safe_border","picture.guides",
	"room.screen_bloom","room.ambient","room.key_energy","room.fill_energy","room.shadow_strength","room.lamp_height","room.lamp_side","room.fade_begin","room.fade_end",
	"room.cabinet_ao_strength","room.cabinet_grain_strength","room.floor_brightness",
	"music.duck_amount","audio.room_amount","audio.speaker_character","audio.directional_strength","music.directional","music.side",
	"controls.separate_preview","emulation.game_fps","access.haptic_strength"]

func advanced_hidden(id: String) -> bool:
	return not bool(host.get("settings_advanced")) and id in ADVANCED

## The Accessibility row that switches between Basic and all settings.
func advanced_row() -> Dictionary:
	return toggle("access.advanced","Show advanced settings",host,"settings_advanced",false,"Off keeps settings to the everyday ones. On adds fine-tuning: signal detail, lamp and lens calibration, picture position and more. Hidden settings keep working.",func(): menu.refresh(),false)

const FLAT_REASON := "Not used in flat screen mode. Turn off View & glasses → Stereo & comfort → Flat screen to use it."

static func flat_unused(id: String) -> bool:
	if id in FLAT_UNUSED: return true
	return id.begins_with("room.") and not id in FLAT_ROOM_KEPT and not id.begins_with("room.mine.") and not id.begins_with("room.look.")

## Whether flat view leaves this row unused just now: always for the room's
## rows, and for the TV model while the screen is the whole display.
func flat_unused_now(id: String) -> bool:
	return flat_unused(id) or (int(host.get("flat_shape")) == 0 and id in FLAT_WHOLE_UNUSED)

## Why a page's rows are hidden in flat view, for its one-line note.
static func flat_note_reason(ids: Array) -> String:
	if ids.all(func(id): return str(id).begins_with("crt.")):
		return "They shape the TV's curved glass, which flat view does not draw. Turn off Flat view (beside Exit, or View & glasses → Stereo & comfort) to change them."
	if ids.all(func(id): return id in FLAT_WHOLE_UNUSED):
		return "The TV model has no effect while Screen shape is Whole display. Choose TV's shape (View & glasses → Stereo & comfort), or turn off Flat view, to change it."
	return "They move the TV or change the room. Turn off Flat view (beside Exit, or View & glasses → Stereo & comfort) to change them."

## Where a picture value comes from, as a short line under the row's title.
func picture_source(field: String) -> String:
	match host.display_settings.field_source(field):
		"Custom at this scope": return "Changed here"
		"Using console default": return "From console"
		"Using look": return "From look"
		"Using TV default": return "From defaults"
	return "Default"

## A settings tab. `subtitle` is the context line under the category title;
## `scope` (see picture_scope) puts the editing scope strip in its place.
## In flat view, rows that only change the room or the TV's place are left out
## and one line says so; hide_flat=false greys them out in place instead (quick
## tiles, which keep the pause menu's grid).
func page(title: String, rows: Array, subtitle := "", scope := {}, hide_flat := true) -> Dictionary:
	var flat: bool = bool(host.get("flat_screen"))
	if flat:
		var kept: Array = []
		var hidden: Array = []
		var pending_section := ""
		for row in rows:
			if row is Dictionary and flat_unused_now(str(row.get("id",""))):
				if hide_flat:
					hidden.append(str(row.id))
					# A hidden row's section heading passes to the next row shown.
					if row.has("section"): pending_section = str(row.section)
					continue
				if not row.get("disabled",false): row["disabled"]=true; row["disabled_reason"]=FLAT_REASON
			if not pending_section.is_empty() and row is Dictionary:
				if not row.has("section"): row["section"] = pending_section
				pending_section = ""
			kept.append(row)
		if not hidden.is_empty():
			var note := unavailable(action("flat.note." + title.to_lower().replace(" ", "_"), "%d %s hidden in flat view" % [hidden.size(), "setting" if hidden.size() == 1 else "settings"], func(): pass, "", true, ""),
				flat_note_reason(hidden))
			kept.push_front(note)
		rows = kept
	if not bool(host.get("settings_advanced")):
		var shown: Array = []
		var hidden_count := 0
		var carried := ""
		for row in rows:
			if row is Dictionary and str(row.get("id","")) in ADVANCED:
				hidden_count += 1
				if row.has("section"): carried = str(row.section)
				continue
			if not carried.is_empty() and row is Dictionary:
				if not row.has("section"): row["section"] = carried
				carried = ""
			shown.append(row)
		if hidden_count > 0:
			# The note is also the way back: A shows every setting.
			shown.append(action("advanced.note." + title.to_lower().replace(" ", "_"), "%d advanced %s hidden" % [hidden_count, "setting" if hidden_count == 1 else "settings"],
				func(): host.settings_advanced = true; host.settings_dirty = true; menu.refresh(),
				"Fine-tuning most people never need. Select to show every setting; turn them off again in Menu & access › Accessibility.", false, "Show ›"))
		rows = shown
	for row in rows:
		if row is Dictionary and ROW_ICONS.has(row.get("id","")) and not row.has("row_icon"): row["row_icon"]=ROW_ICONS[row.id]
		if not row is Dictionary: continue
		var id: String=row.get("id","")
		var field: String={"picture.source_aspect":"picture.aspect_override","picture.connection":"picture.mode"}.get(id,id)
		if id.begins_with("crt.") and id.trim_prefix("crt.") in host.SettingsDefaults.PICTURE or id.begins_with("picture.") and field in host.display_settings.live_picture():
			row["reset"]=func(): host.display_settings.reset_field(field); menu.refresh()
			row["default"]=host.display_settings.inherited_value(field,row.get("default",0))
			row["picture_field"] = field
			row["reset_label"] = "Inherited" if host.display_settings.scope != 2 and not picture_scope_row().is_empty() else "Default"
			row["detail_getter"] = func(): return picture_source(field)
		if id=="picture.fitting":
			row["reset"]=func(): host.display_settings.reset_fields(["picture.keep_aspect","picture.fit_mode"]); menu.refresh()
	return {"title":title,"rows":rows,"subtitle":subtitle,"scope":scope}

func picture_scope_row() -> Dictionary:
	var prefs = host.display_settings
	if prefs.content.is_empty() and prefs.system.is_empty(): return {}
	var scopes: Array = [0,1,2] if prefs.kind == "game" and not prefs.system.is_empty() else [0,2]
	var labels: Array = []
	for value in scopes: labels.append(["This video" if prefs.kind == "video" else "This game", "Console defaults", "TV defaults"][value])
	return {"id":"picture.scope","label":"Apply picture changes to","kind":"choice","choices":labels,"default":0,
		"getter":func(): return maxi(0, scopes.find(prefs.scope)), "setter":func(value): prefs.set_scope(scopes[int(value)]); menu.refresh(),
		"help":"Choose where changes are saved. This game or video overrides its defaults; each TV keeps separate pictures for games and videos."}

## The scope strip for every Picture tab: which picture the tabs edit. With a game
## loaded: this game, all games on its console, or the defaults; with a video:
## this video or the video defaults; with nothing loaded, game or video defaults.
## Changing scope only changes what is edited; it never removes anything.
func picture_scope() -> Dictionary:
	var prefs = host.display_settings
	if not prefs.editing_look.is_empty(): return {}
	if prefs.content.is_empty() and prefs.system.is_empty():
		if host.emulator.loaded or host.video.loaded: return {}
		return {"choices":["Game defaults","Video defaults"],"index":1 if prefs.kind == "video" else 0,
			"set":func(value):
				prefs.leave_context(); prefs.kind="video" if int(value) == 1 else "game"; prefs.scope=2; prefs.content=""; prefs.system=""; prefs.refresh_screen(); menu.refresh()}
	var video: bool = prefs.kind == "video"
	var scopes: Array = [0,1,2] if not video and not prefs.system.is_empty() else [0,2]
	var labels: Array = []
	for value in scopes:
		match value:
			0: labels.append("This video" if video else "This game")
			1: labels.append("All %s games" % console_short(prefs.system))
			2: labels.append("Video defaults" if video else "Game defaults")
	return {"choices":labels,"index":maxi(0, scopes.find(prefs.scope)),"set":func(value): prefs.set_scope(scopes[int(value)]); menu.refresh()}

func console_short(system: String) -> String:
	var spec: Dictionary = host.emulator.Registry.SYSTEMS.get(system, {})
	return str(spec.get("short", spec.get("name", system.to_upper())))

## The scope strip for Games → Console settings and Controls while a game is loaded.
var game_scope := 0
func games_scope() -> Dictionary:
	var em = host.emulator
	if not em.loaded or not em.Registry.SYSTEMS.has(em.system_id): return {}
	return {"choices":["This game","All %s games" % console_short(em.system_id)],"index":game_scope,
		"set":func(value): game_scope=int(value); menu.refresh()}

## The top of Picture → Fit & TV: the editing scope and the TV model for it.
func display_rows() -> Array:
	var prefs = host.display_settings
	var rows: Array = []
	var inheritable: bool = prefs.scope != 2 and not picture_scope_row().is_empty()
	if inheritable:
		var console_scope: bool = prefs.scope == 1
		var group: String = "platforms" if console_scope else ("videos" if prefs.kind == "video" else "games")
		var key: String = prefs.system if console_scope else prefs.content
		var subject: String = "console" if console_scope else ("video" if prefs.kind == "video" else "game")
		var inherited: String = "Same as console" if prefs.kind == "game" and not console_scope else "Same as default"
		rows.append({"id":"picture.cabinet","label":"TV for this " + subject,"kind":"choice","choices":[inherited] + prefs.TV_POLICY_CHOICES.slice(0,2),"default":0,"visual":true,"value_width":260,"section":"TV",
			"getter":func(): return ["","standard","wide"].find(prefs.entry(group,key).get("screen","")),
			"setter":func(value):
				if int(value) == 0:
					if console_scope: prefs.set_platform_screen(key,0)
					else: prefs.inherit_screen()
				else: host.set_widescreen(int(value) == 2)
				menu.refresh(),
			"help":"Chooses the cabinet for this " + subject + ". Both TVs can show either picture shape; Fit below decides how it fills the screen."})
	else:
		var tv_row: Dictionary = prefs.video_tv_row("picture.video_policy") if prefs.kind == "video" else prefs.policy_row("picture.tv_policy")
		tv_row["section"] = "TV"
		rows.append(tv_row)
	return rows

## Clears picture changes at the scope being edited.
func picture_reset_row() -> Dictionary:
	var prefs = host.display_settings
	var inheritable: bool = prefs.scope != 2 and not picture_scope_row().is_empty()
	return action("picture.inherit","Use inherited picture settings" if inheritable else "Restore default picture settings",func(): prefs.inherit_picture(); menu.refresh(),"Clears picture and fitting changes for the editing scope shown above. It does not change the TV model.")

const CoreOptions = preload("res://scripts/emulation/core_options.gd")

func core_option_row(system: String, game: String, definition: Array) -> Dictionary:
	var key: String = definition[0]
	var labels: Array = definition[2].duplicate()
	var values: Array = definition[3]
	var per_game := not game.is_empty()
	if per_game: labels[0] = CoreOptions.console_label(system, definition)
	var item := {"id":"core.%s.%s.%s" % [system, game, key], "label":definition[1], "kind":"choice", "choices":labels, "default":0, "visual":false,
		"getter":func(): return CoreOptions.choice_index(system, game, definition),
		"setter":func(value):
			var error := CoreOptions.write_value(system, game, key, values[value])
			if error != OK: host.show_notice("Could not save core settings: " + error_string(error)),
		"help":definition[4] + " Applies next time you load the game."}
	if per_game:
		item["reset_label"] = "Console value"
		item["detail_getter"] = func(): return "From console" if CoreOptions.choice_index(system, game, definition) == 0 else "Game override"
	return item

const CORE_SYSTEMS := ["snes", "nes", "megadrive", "mastersystem", "gamegear", "segacd", "gameboy", "gba", "ngpc", "psx", "n64", "dreamcast"]
## Listed only when their development opt-in is on.
const EXPERIMENTAL_SYSTEMS := ["gamecube", "wii", "ps2", "psp"]
var expanded_core_console := ""
var core_game_context := ""

func toggle_core_console(system: String) -> void:
	expanded_core_console = "" if expanded_core_console == system else system
	menu.refresh()

func core_option_pages() -> Array:
	var emulator = host.emulator
	var playing: String = emulator.system_id if emulator.loaded and emulator.Registry.SYSTEMS.has(emulator.system_id) and (emulator.system_id in CORE_SYSTEMS or emulator.system_id in EXPERIMENTAL_SYSTEMS) else ""
	var context: String = playing + ":" + emulator.rom_hash if not playing.is_empty() else ""
	if context != core_game_context:
		core_game_context = context
		expanded_core_console = playing
		# A new game starts on its own settings.
		game_scope = 0
		menu.memory["settings:10:0"] = {"id":"core.console." + (playing if not playing.is_empty() else "snes"), "scroll":0}
	var systems: Array = CORE_SYSTEMS.duplicate()
	for system in EXPERIMENTAL_SYSTEMS:
		if emulator.Registry.SYSTEMS.has(system): systems.append(system)
	if not playing.is_empty():
		systems.erase(playing)
		systems.push_front(playing)
	var rows: Array = []
	for system in systems:
		var is_open: bool = expanded_core_console == system
		var header := action("core.console." + system, emulator.Registry.SYSTEMS[system].name,
			toggle_core_console.bind(system), "Defaults for all %s games. Select to %s settings." % [emulator.Registry.SYSTEMS[system].name, "hide" if is_open else "show"], false, "Playing" if system == playing else "")
		header["accordion_group"] = system
		header["disclosure"] = "▾" if is_open else "▸"
		header["expanded"] = is_open
		header["compact"] = true
		rows.append(header)
		if is_open:
			var tv_row := {"id":"core.tv."+system,"label":"TV for this console","kind":"choice","choices":["Same as default"] + host.display_settings.TV_POLICY_CHOICES.slice(0,2),"default":0,"visual":true,
				"getter":func(): return ["","standard","wide"].find(host.display_settings.entry("platforms",system).get("screen","")),
				"setter":func(value): host.display_settings.set_platform_screen(system,int(value)); menu.refresh(),
				"help":"Applies immediately. Individual games can choose another TV under Picture → Fit & TV. This does not enable widescreen rendering in the emulator.","accordion_group":system,"accordion_child":true,"skin":"inset"}
			rows.append(tv_row)
			for definition in CoreOptions.definitions(system):
				var child := core_option_row(system, "", definition)
				child["accordion_group"] = system
				child["accordion_child"] = true
				child["skin"] = "inset"
				rows.append(child)
	if not rows.is_empty():
		rows[0]["section"] = "Console defaults"
		rows[0]["section_detail"] = "Applies next time you load a game."
	rows.append(region_row())
	var grouped := toggle("library.group_versions","One row per game",host,"library_group_versions",true,"Lists each game once and plays your region's version, or the one you last played. Pick another version when you start it.",func(): menu.games.list_changed(),false)
	grouped["section"] = "GAME LISTS"
	rows.append(grouped)
	rows.append(toggle("library.hide_extras","Hide betas, demos & hacks",host,"library_hide_extras",false,"Leaves betas, prototypes, demos, hacks and bad dumps out of console lists; translations stay. Favourites and Recently played still show them.",func(): menu.games.list_changed(),false))
	var scope := games_scope()
	if playing.is_empty() or game_scope != 0:
		return [page("Console settings", rows, "Defaults for each console" if playing.is_empty() else "Defaults for every %s game" % console_short(playing), scope)]
	var game_rows: Array = []
	for definition in CoreOptions.definitions(playing): game_rows.append(core_option_row(playing, emulator.rom_hash, definition))
	if not game_rows.is_empty():
		game_rows[0]["section"] = GameTitle.of(emulator.rom_path) + " · " + emulator.Registry.SYSTEMS[playing].name
		game_rows[0]["section_detail"] = "Changes apply next load. Y returns an option to the console setting."
	else:
		game_rows.append(unavailable(action("core.no_options", "No options for this console", func(): pass, "", true, ""), "This console's emulator has no settings to change."))
	return [page("Console settings", game_rows, "", scope)]

func property_row(key: String, caption: String, low: float, high: float, step: float, unit: String, help: String, visual := true) -> Dictionary:
	return number("view."+key,caption.replace(" (m)","").replace(" (seconds)",""),host,key,low,high,step,float(host.SettingsDefaults.slider_default(caption,host)),unit,help,func():
		host.fade_material.set_shader_parameter("fade_width",host.edge_fade),visual)

func picture_fields(fields: Array) -> Array:
	var result: Array = []
	var tips := {
		"gamma":"Lower gamma lightens midtones; it does not change the black level.",
		"beam_softness":"Controls the sharpness of the CRT beam reconstruction.",
		"vignette":"Gently shades the outer edges of the tube.",
		"safe_border":"Leaves room between the complete game frame and the curved aperture.",
		"width":"Limits picture width without cropping the game frame.",
		"height":"Limits picture height without cropping the game frame.",
		"shift_x":"Moves the complete image within the available horizontal border.",
		"shift_y":"Moves the complete image within the available vertical border.",
		"phase_noise":"Composite chroma instability; visible only in a composite signal mode.",
		"signal_motion":"Animated composite interference. The game stays paused while adjusting.",
		"composite_strength":"Blends decoded composite colour with the clean source.",
		"artifact_strength":"Strength of composite colour bleeding and edge artifacts."}
	for field in fields:
		var key: String = field[0]
		var item := {"id":"picture."+key,"label":str(field[1]).replace(" (lower = lighter)","").replace(" (0 = off)",""),"kind":"number","min":field[2],"max":field[3],"step":field[4],"default":field[5],"visual":true,
			"getter":func(): return host.world.picture.values[key],"setter":func(value): host.world.picture.set_value(key,value),
			"help":tips.get(key,"Adjusts the picture immediately. Y restores this option's default.")}
		if key in ["composite_strength","artifact_strength","phase_noise","signal_motion"] and host.world.picture.mode==0:
			item.disabled=true; item.disabled_reason="Available in composite signal mode."
			item.help += " " + item.disabled_reason
		item.unit = "degrees" if key=="hue" else ("" if key in ["gamma","beam_softness"] else "percent")
		result.append(item)
	return result

## Videos → Picture: which picture videos use, and how a video fills the tube.
func video_picture_rows() -> Array:
	var h = host
	return [{"id":"video.default_style","label":"Default framing","kind":"choice","choices":VideoSession.STYLES,"default":0,
			"getter":func(): return h.video_style,"setter":func(value): h.video_style=int(value); h.save_library(),
			"help":"Framing for new videos. Original aspect keeps the source shape. The other options simulate a 4:3 broadcast. Each video remembers its own choice."},
		{"id":"video.lines","label":"Picture lines","kind":"choice","choices":["240 · CRT look","480 · sharper"],"default":0,
			"getter":func(): return 1 if h.video_lines==480 else 0,"setter":func(value): h.video_lines=480 if int(value)==1 else 240; h.save_library(),
			"help":"240 lines shows the CRT's scanline and phosphor texture. 480 is sharper and finer. Applies to the next video."},
		{"id":"video.interlace","label":"Interlaced video","kind":"choice","choices":["Field motion · TV","Blend"],"default":0,
			"getter":func(): return h.video_interlace,"setter":func(value): h.video_interlace=int(value); h.video.set_interlace(h.video_interlace); h.save_library(),
			"help":"Field motion shows 50/60 fields per second for smooth interlaced video. Blend combines the two fields into one picture."}]

## Videos → VCR: the recorder the videos play from.
func vcr_rows() -> Array:
	var h = host
	return [{"id":"video.tape","label":"Tape look","kind":"choice","choices":["Off","VHS","Worn VHS"],"default":0,
			"getter":func(): return h.video_tape,"setter":func(value): h.video_tape=int(value); h.video.set_tape(h.video_tape); h.save_library(),
			"help":"Adds VHS picture wear and noise bars during fast-forward and rewind. Worn VHS adds more wear."},
		{"id":"video.osd","label":"On-screen text","kind":"toggle","default":true,
			"getter":func(): return h.video_osd,"setter":func(value): h.video_osd=bool(value); h.video.osd_enabled=h.video_osd; h.video.update_osd(); h.save_library(),
			"help":"Shows PLAY, PAUSE, FF and REW in green VCR lettering on the picture, like a video recorder."},
		{"id":"video.vcr_sounds","label":"Mechanism sounds","kind":"toggle","default":true,
			"getter":func(): return h.video_vcr_sounds,"setter":func(value): h.video_vcr_sounds=bool(value); h.vcr_sounds.enabled=h.video_vcr_sounds; h.save_library(),
			"help":"The recorder's clunks for play, pause and stop, and its motor whirring while you fast-forward or rewind. They follow the game volume."}]

## Videos → Playback: subtitles, decoding and where the videos are.
func playback_rows() -> Array:
	var h = host
	return [{"id":"video.subtitles_default","label":"Subtitles for new videos","kind":"toggle","default":false,
			"getter":func(): return h.video_subtitles,"setter":func(value): h.video_subtitles=bool(value); h.save_library(),
			"help":"Turns on a video's first subtitles when you open it. A choice you make for a video is remembered for that video."},
		{"id":"video.hardware","label":"Hardware video decoding","kind":"toggle","default":true,
			"getter":func(): return h.video_hardware,"setter":func(value): h.video_hardware=bool(value); h.save_library(),
			"help":"Uses GPU decoding (VA-API on Deck), with automatic software fallback. Applies to the next video."},
		action("video.folder","Video folder",func(): menu.videos.open_video_folder_picker(),"Choose where CRT XR looks for videos. Subfolders are included.",false,h.video_dir)]

## Read-only information uses the same live game and BIOS detection as the emulator.
func emulation_game_info() -> String:
	var em = host.emulator
	if not em.loaded: return "!! No game loaded\nStart a game to see its console, emulator core and game frame rate."
	var spec: Dictionary = em.Registry.SYSTEMS[em.system_id]
	return "## Current game\nGame := %s\nConsole := %s\nEmulator core := %s\nGame frame rate := %.2f fps" % [em.rom_path.get_file(), spec.name, em.core_identity, em.fps]

func emulation_bios_info() -> String:
	var registry = host.emulator.Registry
	var lines: Array[String] = ["BIOS files are detected by filename. Detection does not verify their contents."]
	for id in ["segacd", "atarilynx", "psx"]:
		var spec: Dictionary = registry.SYSTEMS[id]
		var required: bool = spec.has("bios_any")
		var names: Array = spec.get("bios_any", spec.get("bios_optional", []))
		var found: Array[String] = []
		for filename in names:
			if not registry.bios_file(filename).is_empty(): found.append(filename)
		var status := ("Required" if required else "Optional") + (" · none found" if found.is_empty() else " · found: " + ", ".join(found))
		lines.append("!! " + spec.name)
		lines.append(status + (". Sega CD needs the BIOS matching the disc region." if id == "segacd" else (". A real BIOS can improve compatibility." if id == "psx" else ".")))
		if found.is_empty(): lines.append("Expected: " + ", ".join(names))
	lines.append("## Searched folders")
	for folder in registry.bios_sources(): lines.append("- " + folder)
	return "\n".join(lines)

## Scenes & help → System → Updates: opt-in, and only ever a look at GitHub's
## public release list. Nothing is downloaded or installed.
func update_rows() -> Array:
	var h = host
	var u = h.updates
	var auto := {"id":"system.update_auto","label":"Check for updates automatically","kind":"toggle","default":false,"visual":false,"section":"UPDATES",
		"getter":func(): return u.auto,"setter":func(value): u.auto=bool(value); u.save_state(); menu.refresh(),
		"help":"Once a day at start-up, asks GitHub whether a newer CRT XR has been released. Off by default; nothing else is sent."}
	var now := action("system.update_check","Check now",func():
		if u.checking: return
		var done := func(result: Dictionary): menu.notify(str(result.message)); menu.refresh()
		u.finished.connect(done, CONNECT_ONE_SHOT)
		u.check_now(); menu.refresh(),
		"Asks GitHub's public release list for the newest version. Updating is still your choice: download it from github.com/blackalice/CRT-XR/releases.",false,u.summary())
	var result: Array = [auto, now]
	if u.update_available():
		result.append(action("system.update_open","Open the download page",func():
			if OS.shell_open(u.latest_url if not u.latest_url.is_empty() else u.RELEASES_PAGE) != OK: menu.notify("Open github.com/blackalice/CRT-XR/releases on your computer."),
			"Opens the release page in your browser (on the Deck, switch to Desktop Mode to download). Run the new package's installer, or extract it to a new folder on Windows; settings and saves are kept.",false,u.pretty(u.latest_tag)))
	return result

## Tracking rows show what is happening: whether the glasses are tracking, and
## whether the fixed view is in use.
func tracking_status() -> String:
	var provider = host.provider
	if not provider.real: return ""
	return "Tracking" if provider.valid else "Not found"

func tracking_rows() -> Array:
	var h = host
	var unchanged := func(): pass
	var glasses_source: String = "VITURE glasses" if OS.get_name() == "Windows" else "XR Gaming"
	var tracking: Array = [
		{"id":"tracking.source","label":"Tracking source","kind":"choice","choices":[glasses_source,"OpenTrack"],"default":0,
			"getter":func(): return 1 if h.tracking_source == "opentrack" else 0,"setter":func(value): h.set_tracking_source("opentrack" if int(value) == 1 else "glasses"); menu.refresh(),
			"help":"Other glasses can use OpenTrack UDP on 127.0.0.1:4242. Run opentrack, PhoenixHeadTracker or VertoXR; invert axes below if needed."},
		action("tracking.real","Reconnect glasses" if h.provider.real else "Connect glasses",func(): h.use_tracking(true); menu.refresh(),
			"Tracking is running. Select to reconnect if the view stops following your head." if h.provider.real and h.provider.valid else "Connects or retries the glasses' tracking driver.",false,tracking_status()),
		action("tracking.fixed","Use fixed view",func(): h.use_tracking(false); h.recenter(); menu.refresh(),"Keeps the TV still. On desktop, mouse and keyboard can still move the view.",false,"✓ In use" if not h.provider.real else ""),
		action("tracking.recenter","Recentre view",h.recenter,"Points the view straight ahead again. Also on {R3}, without opening the menu.",false,""),
		toggle("tracking.diagnostics","Metrics overlay",h,"metrics_visible",false,"Shows frame rate, pose and tracking details. Off by default for a clean view. F1 also toggles it.",unchanged,false)]
	for axis in ["yaw","pitch","roll"]:
		tracking.append(toggle("tracking."+axis,"Invert "+axis,h.provider,"invert_"+axis,false,"Turn on if the view moves the wrong way when you turn your head.",unchanged,false))
	tracking[tracking.find(tracking.filter(func(row): return row.id == "tracking.yaw")[0])]["section"] = "IF MOVEMENT FEELS REVERSED"
	if OS.get_name() == "Windows" and h.tracking_source != "opentrack":
		var VitureSdk = preload("res://scripts/tracking/viture_sdk.gd")
		var ready: bool = VitureSdk.available()
		tracking.insert(2, action("tracking.sdk", "Set up VITURE SDK" if not ready else "Choose VITURE SDK again", func():
			VitureSdk.choose(func(result: Dictionary):
				menu.notify(str(result.message))
				if result.ok: h.use_tracking(true)
				menu.refresh()),
			"VITURE head tracking needs VITURE's free Windows SDK from viture.com/developer. Choose its ZIP, or glasses.dll inside it; CRT XR copies what it needs into its own settings folder. Opens on your desktop monitor.", false, "✓ Set up" if ready else "Needed"))
	return tracking

## View & glasses → TV placement: where the TV sits, and the right stick that moves it.
func placement_rows() -> Array:
	var h = host
	var rows: Array = [
		property_row("distance","TV distance (m)",1.2,5,.1,"m","Saved separately for each TV and for fixed view or head tracking. Moves the TV and stand closer or farther."),
		property_row("height_offset","TV height (m)",-1.5,1.5,.05,"m","Moves the TV, furniture and floor together vertically."),
		property_row("tv_scale","TV scale",.5,1.6,.05,"percent","Scales the whole set; this is independent of picture fitting."),
		action("view.fit","Fit TV to view",h.fit_tv_to_view,"Fits the physical TV inside your neutral view."),
		action("view.recenter","Recentre view",h.recenter,"Also available on {R3}, without opening the menu."),
		toggle("controls.distance","Right stick moves the TV",h,"right_stick_distance",true,"Stick up brings the TV closer; stick down moves it farther away.",func(): pass,false),
		property_row("distance_speed","Distance adjustment speed",.2,2,.1,"m/s","How fast the right stick moves the TV, in metres per second.",false)]
	rows[5]["section"] = "RIGHT STICK"
	rows[6]["label"] = "Right stick speed"
	return rows

## Flat view's screen: the whole display, or the shape of the TV the game uses.
func flat_shape_row(id: String) -> Dictionary:
	var h = host
	return {"id":id,"label":"Screen shape","kind":"choice","choices":h.FLAT_SHAPES,"default":0,"visual":true,
		"getter":func(): return h.flat_shape,"setter":func(value): h.flat_shape=int(value); h.settings_dirty=true; menu.refresh(),
		"help":"Whole display fits the game to this screen, with the tube's edge at the screen's edge; Fit, Fill and Stretch work against it. TV's shape keeps the standard or wide TV's outline, with black around it."}

## View & glasses → Stereo & comfort. Fullscreen is a desktop window control, so
## the Steam Deck (always fullscreen) does not offer it.
func stereo_rows() -> Array:
	var h = host
	var rows: Array = [
		{"id":"view.flat","label":"Flat screen","kind":"toggle","default":false,"visual":false,
			"getter":func(): return h.flat_screen,"setter":func(value): h.set_flat_screen(bool(value)),
			"help":"Shows the game full-screen without the room or the TV, for playing without glasses. Uses your picture settings. F3 also switches it."},
		unavailable(flat_shape_row("view.flat_shape").merged({"disabled":not h.flat_screen},true),"Turn on Flat screen first."),
		toggle("view.stereo","Side-by-side 3D",h,"stereo",false,"Use with the glasses' own SBS mode. This does not switch the glasses themselves.",func(): h.set_stereo(h.stereo)),
		property_row("edge_fade","Soft view edges",0,.2,.005,"percent","Fades the edges of the glasses' view into black."),
		{"id":"view.scene_msaa","label":"Room edge smoothing","kind":"choice","choices":["Off","2× MSAA","4× MSAA"],"default":0,"visual":true,
			"getter":func(): return h.scene_msaa,"setter":func(value): h.scene_msaa=int(value); h.apply_scene_msaa(),
			"help":"Smooths the room's edges in both eyes. Costs GPU time: try 2×; Off is fastest. Game pixels and emulator resolution stay unchanged."}]
	if not menu.deck_controls:
		rows.append(action("view.fullscreen","Toggle fullscreen",h.toggle_fullscreen,"Switches the window between fullscreen and windowed. F11 also toggles it."))
	return rows

## Stops the programme for the calibration pattern. It asks first and saves the
## game's automatic resume point, so Continue returns to this moment.
func stop_for_test_signal() -> void:
	var h = host
	var subject: String = h.video.path.get_file().get_basename() if h.video.loaded else GameTitle.of(h.emulator.rom_path)
	menu.ask("Stop %s?" % subject, ("Your place in the video is remembered." if h.video.loaded else "An automatic resume point is saved first, so Continue brings you back to this moment.") + " Then the test signal is shown.", func():
		if h.video.loaded:
			h.remember_video_position()
			h.stop_video()
		if h.emulator.loaded:
			if not h.emulator.save_auto():
				menu.show_error("Could not save a resume point, so the game is still running. Check free space and the save folder.")
				return
			h.emulator.stop()
		menu.open_pause())

func calibration_rows() -> Array:
	var h = host
	return [property_row("ipd","IPD (m)",0,.08,.001,"mm","Virtual eye separation; match your interpupillary distance."),
		property_row("convergence","Convergence (m)",1,10,.1,"m","Depth at which the stereo views have zero horizontal disparity."),
		property_row("vertical_fov","Vertical field of view",18,70,.5,"degrees","Advanced camera calibration. The glasses normally use 24 degrees."),
		property_row("smoothing","Smoothing (seconds)",0,.15,.01,"ms","Tracking smoothing; higher values can feel less immediate."),
		property_row("motion_predict","Motion prediction (seconds)",0,.08,.005,"ms","Optional lead for recent head movement. Recommended: 0 ms. Increase only if tracking feels late; too much feels jumpy."),
		unavailable(action("system.signal","Show test signal",stop_for_test_signal,"Stops the game or video and shows the calibration pattern. Asks first, and saves a resume point.",not h.emulator.loaded and not h.video.loaded,""),"Nothing is playing.")]

## Stable category IDs are retained for navigation memory and existing shortcuts.
## The sidebar shows eight task-oriented categories (menu_controller.SETTINGS_ORDER);
## 4 (controls), 5 (saved setups) and 7 (quick settings) remain as aliases.
func pages(category: int) -> Array:
	return category_pages(category)

func tv_effect_rows() -> Array:
	var h = host
	return [toggle("atmosphere.power_on","Power-on warm-up",h.power_on,"enabled",true,"Tube warm-up and switch sound when the TV first appears.",func(): h.power_on.apply(); menu.refresh(),false),
		toggle("atmosphere.channel_change","Channel change",h.tv_effects,"channel_change",true,"A burst of static and a rolling picture when a game or video starts.",menu.refresh,false),
		toggle("atmosphere.power_off","Power-off",h.tv_effects,"power_off_effect",true,"The picture shrinks to a fading dot as CRT XR closes.",menu.refresh,false),
		action("atmosphere.preview","Preview power-on",h.preview_power_on,"Closes settings and replays the warm-up picture and sound.",not h.power_on.enabled)]

## Every volume in one list: the game, music, the menu's music, the room and the TV's own sounds.
func volume_rows() -> Array:
	var h = host
	var music = h.music
	var w = h.world
	var duck_amount = number("music.duck_amount","Lower by",music,"duck_amount",0,1,.05,.5,"percent","How much quieter the game gets while music plays. Fades smoothly.",music.apply,false)
	if not music.duck_game:
		duck_amount.disabled=true; duck_amount.disabled_reason="Turn on Lower the game during music first."
	var ambience_level := number("room.ambience_level","Room sound",w,"ambience_level",0,1,.05,h.Showcase.ROOM.ambience_level,"percent","Kept well under the game or video.",w.apply_room_settings,false)
	if w.ambience==0:
		ambience_level.disabled=true; ambience_level.disabled_reason="Choose a room sound below first."
	var rows: Array = [
		number("music.game_volume","Game",music,"game_volume",0,1,.05,1,"percent","The game's own sound, and videos. Pauses with the game.",music.apply,false),
		toggle("music.duck_game","Lower the game during music",music,"duck_game",false,"Turns the game down while your music is playing; back up when it pauses or stops.",func(): music.apply(); menu.refresh(),false),
		duck_amount,
		number("music.volume","Music & radio",music,"volume",0,1,.05,.45,"percent","Your albums and radio. Carries on while the game is paused.",music.apply,false),
		number("access.menu_music_volume","Menu music",h,"menu_music_volume",0,1,.05,.10,"percent","Background music while menus are open. Zero mutes it.",h.apply_menu_music,false),
		number("atmosphere.power_sound","TV moments",h.power_on,"sound_level",0,1,.05,.60,"percent","The switch, static, degauss and power-off sounds. Zero keeps them silent.",h.power_on.apply,false),
		ambience_level,
		{"id":"room.ambience","label":"Room sound type","kind":"choice","choices":w.room_sound.CHOICES,"default":h.Showcase.ROOM.ambience,"visual":false,
			"getter":func(): return w.ambience,"setter":func(value): w.ambience=value; w.apply_room_settings(); menu.refresh(),
			"help":"Quiet sound for the room around the TV: still air, rain on the window, or rain with a ticking clock."},
		toggle("room.crt_whine","Tube whine",w,"crt_whine",false,"The high-pitched whine of a CRT's line transformer (15.7 kHz). Very quiet, and many people can't hear it at all.",w.apply_room_settings,false)]
	rows[0]["section"] = "GAME"
	rows[3]["section"] = "MUSIC & MENUS"
	rows[5]["section"] = "ROOM & TV"
	return rows

func category_pages(category: int) -> Array:
	var h = host
	var w = h.world
	var refresh := func(): w.picture.refresh()
	var unchanged := func(): pass
	var editing: String = "Editing " + h.display_settings.context_label()
	match category:
		0:
			var status: String = tracking_status()
			return [page("Tracking",tracking_rows(),"Fixed view · the TV stays still" if not h.provider.real else ("Glasses tracking" if status == "Tracking" else "Glasses not found · the view is held still")),
				page("TV placement",placement_rows(),"Placement for the " + ("wide TV" if w.widescreen else "standard TV") + (" · fixed view" if not h.provider.real else " · head tracking")),
				page("Stereo & comfort",stereo_rows(),"Applies to every game and video"),
				page("Calibration",calibration_rows(),"For fine-tuning; most people never need these")]
			# Picture: the look, the tube, colour and signal, and the TV model with fitting.
		1:
			var crt: Array = []
			for field in [["scanlines","Scanlines",.7,.05],["phosphor_mask","Phosphor mask",.5,.05],["phosphor_glow","Phosphor glow",.4,.02],["glass_reflections","Glass reflections",.4,.02],["screen_curvature","Screen curvature (0 = flat)",1,.05]]:
				var key: String = field[0]
				crt.append(number("crt."+key,str(field[1]).replace(" (0 = flat)",""),h,key,0,field[2],field[3],h.SettingsDefaults.PICTURE[key],"strength","Adjusts the tube appearance. Changes are visible immediately.",func():
					w.screen_material.set_shader_parameter("scanlines",h.scanlines)
					w.screen_material.set_shader_parameter("mask_strength",h.phosphor_mask)
					w.screen_material.set_shader_parameter("glow_strength",h.phosphor_glow)
					w.glass_material.set_shader_parameter("reflection_strength",h.glass_reflections)
					w.set_curvature(h.screen_curvature)))
			crt.append_array(picture_fields(w.picture.BEAM_FIELDS))
			crt.append(action("crt.degauss","Degauss",h.degauss,"Like the button on an old set: closes the menu, then the picture wobbles and swirls with colour as the tube's field clears.",false,""))
			var fitting: Array = display_rows()
			var fit_row := {"id":"picture.fitting","label":"Fit","kind":"choice","choices":["Fit","Fill","Stretch"],"default":0,"visual":true,"getter":func(): return w.picture.fit_mode if w.picture.keep_aspect else 2,"setter":func(value): w.picture.keep_aspect=value!=2; w.picture.fit_mode=mini(value,1); refresh.call(); menu.refresh(),"help":"Fit shows the whole picture, with borders where the shapes differ. Fill crops the edges to fill the screen. Stretch fills it by changing the picture's shape."}
			fit_row["section"] = "FITTING"
			fitting.append(fit_row)
			fitting.append({"id":"picture.source_aspect","label":"Game shape","kind":"choice","choices":["Automatic","4:3","16:9"],"default":0,"visual":true,"getter":func(): return w.picture.aspect_override,"setter":func(value): w.picture.aspect_override=value; refresh.call(); menu.refresh(),"help":"Leave on Automatic. Choose 16:9 only if a game's own widescreen mode looks squeezed."})
			fitting.append(fitting_help("picture.fit_help"))
			fitting.append_array(picture_fields(w.picture.FIT_FIELDS))
			fitting.append(toggle("picture.guides","Picture-edge guides",w.picture,"guides",false,"Outlines the game frame so you can check nothing is cut off.",refresh))
			fitting.append(action("picture.restore_fit","Restore full-picture fit",func():
				w.picture.reset_fields(w.picture.FIT_FIELDS); w.picture.keep_aspect=true; w.picture.fit_mode=0; w.picture.aspect_override=0; refresh.call(); menu.refresh(),"Resets the fitting controls; leaves the tube and colour alone."))
			var reset := picture_reset_row()
			reset["section"] = "RESET"
			fitting.append(reset)
			var presets: Array = []
			for pair in [["clean","Clean source","Crisp source pixels; scanlines and phosphor effects off."],["rgb","RGB CRT","Clean RGB colour with a defined CRT beam."],["auto","Auto composite","Composite character matched to the game’s frame rate."],["pal","PAL composite","Soft PAL colour blending and analogue texture."],["ntsc","NTSC composite","NTSC colour bleed and classic composite artefacts."]]:
				var preset: String = pair[0]
				presets.append(action("preset."+preset,pair[1],func(): menu.pictures.apply_preset(preset),pair[2],false,"✓ Active" if menu.pictures.applied_preset()==preset else "Apply"))
			presets[0]["section"] = "BUILT-IN LOOKS"
			if menu.pictures.has_custom_picture():
				presets.append(unavailable(action("preset.custom","Restore my custom picture",menu.pictures.restore_custom_picture,"Brings back the picture you had tuned yourself before choosing a look.",menu.pictures.applied_preset().is_empty()),"Your custom picture is already in use."))
			if menu.pictures.picture_undo!=null: presets.append(action("preset.undo","Undo picture look",menu.pictures.undo_picture_preset,"Restores the picture from before the last look."))
			# Your own looks are linked: give one to games or consoles, edit it once.
			var mine: Array = menu.looks.rows()
			if not h.display_settings.editing_look.is_empty(): presets = mine + presets
			else: presets.append_array(mine)
			var signal_rows: Array = [{"id":"picture.connection","label":"Signal","kind":"choice","choices":["RGB","Composite (NTSC)","Composite (PAL)","Composite (auto)"],"default":0,"visual":true,"getter":func(): return w.picture.mode,"setter":func(value): w.picture.mode=value; refresh.call(); menu.refresh(),"help":"RGB is clean. Composite adds colour bleed and artefacts. Auto picks NTSC or PAL from the game's frame rate."}]
			var colour: Array = picture_fields(w.picture.COLOR_FIELDS.slice(0,6))
			colour[0]["section"] = "COLOUR"
			signal_rows.append_array(colour)
			var composite: Array = picture_fields(w.picture.COLOR_FIELDS.slice(6))
			composite[0]["section"] = "COMPOSITE"
			signal_rows.append_array(composite)
			var scope := picture_scope()
			return [page("Looks",presets,editing,scope),page("Tube",crt,editing,scope),page("Colour & signal",signal_rows,editing,scope),page("Fit & TV",fitting,editing,scope)]
		3:
			var groups := {"Lighting":[],"Materials":[],"Placement":[]}
			var tips := {
				"ambient":"Fills darker areas without casting additional shadows.","key_energy":"Brightness of the warm lamp; does not change the game image.",
				"fill_energy":"Soft front illumination to stop dark plastic losing detail.","warmth":"Balances the room lighting between cooler and warmer tones.",
				"shadow_strength":"Darkness of live shadows on unbaked objects. Baked contact shading stays fixed.",
				"cabinet_ao_strength":"Strength of Blender-baked shading in the TV's joins and recesses.",
				"cabinet_grain_strength":"Subtle static plastic finish. Fine grain fades at distance to avoid shimmer.",
				"spill_strength":"Casts the picture's colours onto the TV and nearby objects.",
				"screen_bloom":"Adds a halo around the tube, most visible in a dark room.",
				"floor_brightness":"","fade_begin":"Distance where the small room island begins fading to black.","fade_end":"Distance where the surroundings become fully black."}
			for field in h.ROOM_FIELDS:
				var key: String = field[0]
				var group := "Materials" if key in ["cabinet_ao_strength","cabinet_grain_strength","floor_brightness"] else ("Placement" if key in ["lamp_height","lamp_side","fade_begin","fade_end"] else "Lighting")
				groups[group].append({"id":"room."+key,"label":str(field[1]).replace(" (lower = lighter)","").replace(" (0 = off)",""),"kind":"number","min":field[2],"max":field[3],"step":field[4],"default":h.SettingsDefaults.ROOM[key],"visual":true,
					"unit":"m" if group=="Placement" else "percent",
					"getter":func(): return w.get(key),"setter":func(value): h.set_room_value(key,value),"help":tips.get(key,"Moves the room lamp while the TV stays stationary.")})
			groups.Lighting.append(toggle("room.shadows","Lamp shadows",w,"shadows",true,"Controls live shadows on unbaked objects. The TV and table keep their soft baked contact shading.",w.apply_room_settings))
			groups.Lighting.append(toggle("room.follow_clock","Follow the time of day",w,"follow_clock",false,"Brighter and cooler by day, warmer in the evening and dimmer late at night, around your own lighting.",w.apply_room_settings))
			# The old Room → Placement tab: the lamp's place and where the room fades out.
			groups.Placement[0]["section"] = "LAMP POSITION & ROOM EDGE"
			groups.Lighting.append_array(groups.Placement)
			var props: Array = [
				toggle("room.clock_radio","Clock radio",w,"show_clock_radio",true,"A clock radio beside the TV showing the time on a dim red display. Music plays from its side of the room.",w.apply_room_settings),
				toggle("room.clock_24_hour","24-hour clock",w,"clock_24_hour",false,"Shows the clock radio and VCR time in 24-hour format.",w.apply_room_settings),
				toggle("room.vcr","VCR",w,"show_vcr",true,"A video recorder on the shelf under the TV. Its display shows the time, or the tape counter while a video plays.",w.apply_room_settings),
				toggle("room.game_boxes","Game boxes",w,"show_game_boxes",true,"",func(): w.apply_room_settings(); menu.refresh()),
				toggle("room.game_cover","Your game on the box",w,"show_game_cover",true,"The top box shows the playing game's cover, from your existing scrapes (covers or box2dfront).",w.apply_room_settings)]
			if w.widescreen:
				for index in [0,3,4]:
					props[index].disabled=true; props[index].disabled_reason="Hidden while the widescreen CRT fills the table."; props[index].help += " " + props[index].disabled_reason
			if not w.show_game_boxes and not props[-1].get("disabled",false):
				props[-1].disabled=true; props[-1].disabled_reason="Show the game boxes first."; props[-1].help += " " + props[-1].disabled_reason
			var furniture: Array = [{"id":"room.floor_style","label":"Floor","kind":"choice","choices":w.FLOOR_STYLES,"default":h.Showcase.ROOM.floor_style,"visual":true,
					"getter":func(): return w.floor_style,"setter":func(value): w.floor_style=value; w.apply_room_settings(),
					"help":"90s confetti carpet, a plain wool carpet with natural wear, or wooden floorboards."},
				{"id":"room.wide_finish","label":"Wide TV finish","kind":"choice","choices":["Silver","Black"],"default":0,"visual":true,
					"getter":func(): return w.wide_finish,"setter":func(value): w.set_wide_finish(value),
					"help":"Silver with dark graphics, or black with off-white graphics. Remembered for the wide TV across games and videos."}]
			props[0]["section"] = "PROPS"
			furniture.append_array(props)
			groups.Materials[0]["section"] = "FINISH"
			furniture.append_array(groups.Materials)
			var presets: Array = []
			var room_now: String = h.rooms.active()
			var room_tips := {"dark":"Only the TV lights the room.","late":"Dim and warm, for late at night.","dim":"A dark room tuned for XR glasses.","warm":"A lamp-lit evening bedroom.","bright":"Even light, to see the TV and the props clearly."}
			for pair in h.rooms.BUILT_IN:
				var room_id: String = pair[0]
				presets.append(action("room.look." + room_id, pair[1], func(): h.rooms.apply(room_id); h.rebuild_settings(), room_tips.get(room_id, ""), false, "✓ Active" if room_now == room_id else "Apply"))
			presets[0]["section"] = "BUILT-IN ROOMS"
			if FileAccess.file_exists(h.rooms.CUSTOM_PATH):
				presets.append(unavailable(action("room.custom", "Restore my custom room", func(): h.rooms.apply(""); h.rebuild_settings(), "Brings back the room you had tuned yourself before choosing a preset.", room_now.is_empty()), "Your custom room is already in use."))
			for i in range(h.rooms.COUNT):
				var index: int = i
				var state := "✓ Active" if h.rooms.active()=="mine.%d" % index else ("Saved" if h.rooms.saved(index) else "Empty")
				var mine := action("room.mine.%d" % index,h.rooms.name(index),func(): menu.open_my_room(index),"Your own room: apply it, save the current room here, rename or delete.",false,state)
				if i == 0: mine["section"] = "MY ROOMS"
				presets.append(mine)
			var shared := "Shared by every game and video"
			return [page("Rooms",presets,shared),page("Lighting",groups.Lighting,shared),page("Furniture & props",furniture,shared),page("TV moments",tv_effect_rows(),"TV effects for games and videos · their volume is in Sound → Volumes")]
		4:
			return [page("Controls",menu.controls.rows(),controls_subtitle(),games_scope())]
		10:
			var input_delay: Dictionary = {"id":"controls.preview","label":"Reduce input delay","kind":"choice","choices":["Off","1 frame","2 frames"],"default":1,"visual":false,"getter":func(): return h.emulator.run_ahead,"setter":func(value): h.emulator.run_ahead=value,"help":"Makes button presses show up sooner by running the game slightly ahead. 2 frames needs more processing power."}
			if h.emulator.loaded and not h.emulator.preview_possible():
				input_delay.disabled=true
				var console: String=h.emulator.Registry.SYSTEMS[h.emulator.system_id].name
				if h.emulator.preview_suspended: input_delay.disabled_reason="Paused for this game: it needs the full frame time. Reload the game to try again."
				elif not h.emulator.Registry.SYSTEMS[h.emulator.system_id].get("preview", true): input_delay.disabled_reason="Input delay reduction is unavailable for %s." % console
				elif h.emulator.separate_preview: input_delay.disabled_reason="The second emulator copy could not start for %s." % console
				else: input_delay.disabled_reason="%s needs Use a second emulator copy: its sound buzzes otherwise." % console
			var separate_preview := toggle("controls.separate_preview","Use a second emulator copy",h.emulator,"separate_preview",true,"Keeps sound clean while reducing input delay. Uses more memory. Not available for PS1 or N64; SNES can work without it.",func(): h.emulator.set_separate_preview(h.emulator.separate_preview); menu.refresh(),false)
			var rewind := toggle("emulation.rewind","Rewind & fast-forward",h.emulator,"rewind_enabled",false,"Hold L2 to rewind, R2 to play three times as fast ([ and ] on a keyboard). For 8- and 16-bit consoles, whose controls leave the triggers free.",func(): h.emulator.clear_rewind(); menu.refresh(),false)
			if h.emulator.loaded and h.emulator.rewind_enabled and not h.emulator.speed_available():
				rewind["help"] += " Not for this game: " + ("its controls use the triggers." if h.emulator.triggers_bound() else ("rewind needs more memory than this console allows." if h.emulator.rewind_unsupported else "this console isn't supported yet."))
			var game_fps := toggle("emulation.game_fps","Show game frame rate",h,"game_fps_visible",false,"Shows the game's own frame rate and speed in the top corner while you play. Unlike Steam's counter, it measures the emulator, not the room.",unchanged,false)
			var result: Array = core_option_pages()
			result.append(page("Controls",menu.controls.rows(),controls_subtitle(),games_scope()))
			result.append(page("Input delay",[input_delay,separate_preview,rewind,game_fps],"For the games you play"))
			result.append(page("Info",[
				action("emulation.game_info","Current game",func(): menu.open_help("Current game",emulation_game_info()),"Console, emulator core and game frame rate.",false,GameTitle.of(h.emulator.rom_path) if h.emulator.loaded else ""),
				action("emulation.bios_info","BIOS status",func(): menu.open_help("BIOS status",emulation_bios_info()),"See detected BIOS files and the folders searched.")],"Read-only"))
			# Last, so the other tabs keep their places whether or not a Dreamcast game is loaded.
			if h.emulator.loaded and h.emulator.system_id == "dreamcast": result.append(vmu_page())
			return result
		5:
			return [saved_setups_page()]
		6:
			return [saved_setups_page(),page("Help",[
				action("system.glasses","Using glasses",func(): menu.open_help("Using glasses",menu.play.glasses_guide()),"How to connect glasses, start in side-by-side 3D and recentre."),
				action("system.controls","Controls",func(): menu.open_help("Controls",CONTROLS_GUIDE),"Controller and keyboard shortcuts."),
				action("system.help","Troubleshooting",func(): menu.open_help("Troubleshooting",TROUBLESHOOTING_GUIDE),"Help with glasses, games, audio and saving."),
				action("system.whats_new","What's new",func(): h.updates.mark_whats_new_seen(); menu.open_help("What's new in " + h.updates.current_version(),h.updates.whats_new_text()),"What changed in this version of CRT XR.",false,h.updates.current_version()),
				action("system.setup","Run setup again",func(): menu.welcome.open(),"The first-run setup: the menu shortcut, your view, console region, game library, videos and music, and comfort options."),
				action("system.version","About CRT XR",func(): menu.open_help("About CRT XR",about_page()),"A little CRT room for your XR glasses. About CRT XR, its maker and website.",false,str(ProjectSettings.get_setting("application/config/version")))],"Guides and setup"),
				page("System",[
				action("system.device","Device status",func(): menu.open_help("Device status","!! "+menu.status_title+"\n"+menu.status_detail),"Current display and tracking status.",false,menu.status_title),
				action("system.diagnostics","Copy diagnostics",func():
					DisplayServer.clipboard_set("CRT XR "+str(ProjectSettings.get_setting("application/config/version"))+" | "+OS.get_name()+" | Godot "+str(Engine.get_version_info().string)+" | "+DisplayServer.get_name()); menu.notify("Version and platform details copied; no ROM or music paths included."),"Copies version and platform details for a bug report."),
				action("system.credits","Credits & licences",func(): menu.open_help("Credits & licences",FileAccess.get_file_as_string("res://THIRD_PARTY.md")),"Godot, libretro, and the artists and developers behind CRT XR."),
				action("system.reset","Reset all settings",menu.confirm_reset,"Restores defaults without deleting games or saves.")]+update_rows(),"Version " + str(ProjectSettings.get_setting("application/config/version")))]
		9:
			return [page("Accessibility",[
				toggle("access.large","Larger menu text",h,"menu_large_text",false,"Larger text and taller rows; lists scroll to keep focus visible.",menu.apply_accessibility,false),
				toggle("access.contrast","Stronger menu contrast",h,"menu_high_contrast",false,"Brighter text and clearer borders on a dark background.",menu.apply_accessibility,false),
				toggle("access.motion","Reduced animation",h,"menu_reduced_motion",false,"Instant focus changes and no TV warm-up animation.",menu.apply_accessibility,false),
				advanced_row(),
				toggle("access.clean_feed","Plain picture behind menus",h,"menu_clean_feed",true,"On: menus stay plain and readable in every game. Off: they take the game's own colour, signal and CRT effects.",unchanged,false),
				],"How the menus look and move"),page("Layout",[
				{"id":"access.game_columns","label":"Game list columns","kind":"choice","choices":["1 column", "2 columns", "3 columns"],"default":0,"visual":false,
					"getter":func(): return h.game_list_columns - 1,"setter":func(value): h.game_list_columns=int(value)+1,
					"help":"Choose the layout for console, recent and favourite game lists. Left and right move between games in multi-column views."},
				{"id":"access.menu_shortcut","label":"Menu shortcut","kind":"choice","choices":["L1 + R1 + Start","Also hold Select"],"default":0,"visual":false,
					"getter":func(): return 1 if h.emulator.gamepad.menu_hold_select else 0,"setter":func(value): h.emulator.gamepad.menu_hold_select=int(value)==1; h.settings_dirty=true; menu.refresh(),
					"help":"L1 + R1 + Start always opens the menu. Also hold Select lets you hold Select (View) for just over half a second instead; a quick press still goes to the game."},
				toggle("access.tv","Menu on the TV",h,"menu_on_tv",true,"Shows the menu on the TV. Off floats it in front of the TV; adjusting with preview always floats.",func(): menu.refresh(),false),
				unavailable(toggle("access.depth","Floating menu depth",h,"menu_depth",true,"In side-by-side 3D, places a floating menu in front of the TV and dims the room. Off gives a flat menu.",func(): menu.refresh(),false).merged({"disabled":h.menu_on_tv and not h.flat_screen},true),"Only when the menu floats: turn off Menu on the TV."),
				],"Where the menu appears"),page("Screensaver",[
				toggle("access.screensaver","Screensaver",h,"menu_screensaver",true,"When the menu is left alone, the page gives way to the logo drifting across space. Any button brings the menu straight back.",func(): menu.refresh(),false),
				unavailable({"id":"access.screensaver_style","label":"Style","kind":"choice","choices":["Drifting logo","Switch the TV off"],"default":0,"visual":false,"disabled":not h.menu_screensaver,
					"getter":func(): return h.menu_screensaver_style,"setter":func(value): h.menu_screensaver_style=int(value),
					"help":"The drifting logo, or the TV switching off with its power-down effect, leaving the room dark until you press something."},"Turn on Screensaver first."),
				unavailable({"id":"access.screensaver_delay","label":"Start after","kind":"choice","choices":["30 seconds","1 minute","2 minutes","5 minutes","10 minutes","15 minutes"],"default":2,"visual":false,"disabled":not h.menu_screensaver,
					"getter":func(): return maxi(0,h.SCREENSAVER_DELAYS.find(h.menu_screensaver_delay)),"setter":func(value): h.menu_screensaver_delay=h.SCREENSAVER_DELAYS[int(value)],
					"help":"How long the menu waits without input before the screensaver starts."},"Turn on Screensaver first."),
				],"When the menu is left alone"),page("Vibration",[
				toggle("access.haptics","Menu vibration",h,"menu_haptics",false,"A light tick as the selection moves and a firmer one when you confirm.",func(): menu.refresh(),false),
				unavailable(number("access.haptic_strength","Vibration strength",h,"haptic_strength",0.1,1.0,0.1,0.8,"percent","How strong the ticks feel. The Steam Deck passes on only part of it, so it may need to be higher there.",func(): h.menu_vibrate(1.0, 0.07),false).merged({"disabled":not h.menu_haptics},true),"Turn on Menu vibration first.")],"Controller feedback in the menus")]
		8:
			if not menu.videos.videos_shown():
				return [page("Videos",[action("videos.setup","Set up videos",menu.videos.open_videos,"Set up video playback and choose your video folder.",false,"›")],"Video playback is not set up yet")]
			return [page("Picture",[h.display_settings.video_tv_row("picture.video_policy")]+video_picture_rows(),"For every video · each video remembers its own framing"),page("VCR",vcr_rows(),"The recorder the videos play from"),page("Playback",playback_rows(),"Subtitles, decoding and your video folder")]
		7:
			var quick: Array = []
			# Through page() first, so the copies carry its markings (flat screen mode).
			for source in page("TV placement",placement_rows(),"",{},false).rows:
				if source.id in ["view.distance","view.height_offset","view.recenter"]:
					var copy: Dictionary=source.duplicate(); copy.id="quick."+source.id; quick.append(copy)
			# Custom restores your own tuned picture; saved looks follow the built-in ones.
			var preset_ids: Array = [""]+menu.pictures.PRESET_IDS
			var preset_names: Array = ["Custom"]+menu.pictures.PRESET_NAMES
			for i in range(menu.pictures.MY_PRESET_COUNT):
				if menu.pictures.my_preset_saved(i): preset_ids.append("mine.%d" % i); preset_names.append(menu.pictures.my_preset_name(i))
			quick.append({"id":"quick.preset","label":"Picture look","kind":"choice","choices":preset_names,"getter":func(): return maxi(0,preset_ids.find(menu.pictures.applied_preset())),"setter":func(value):
				var id: String=preset_ids[value]
				if id.is_empty(): menu.pictures.restore_custom_picture()
				elif id.begins_with("mine."): menu.pictures.apply_my_preset(int(id.get_slice(".",1)))
				else: menu.pictures.apply_preset(id),"help":"Choose a look. Custom brings back your own tuned picture; save your own in Picture → Looks.","visual":true})
			quick.append(menu.room_choice("quick.room"))
			quick.append(number("quick.game_volume","Game volume",h.music,"game_volume",0,1,.05,1,"percent","",h.music.apply,false))
			# The TV and its fit as two quick choices; each keeps the other as it is.
			var prefs = h.display_settings
			quick.append({"id":"quick.tv","label":"TV","kind":"choice","choices":["Standard","Wide"],"visual":false,
				"getter":func(): return 1 if prefs.display_choice() >= 3 else 0,
				"setter":func(value): prefs.choose_display(int(value) * 3 + prefs.display_choice() % 3); menu.refresh(),
				"help":"The TV for this game or video. Either one shows any picture shape; Fit decides how it fills the screen."})
			quick.append({"id":"quick.fit","label":"Fit","kind":"choice","choices":["Fit","Fill","Stretch"],"visual":false,
				"getter":func(): return prefs.display_choice() % 3,
				"setter":func(value): prefs.choose_display((prefs.display_choice() / 3) * 3 + int(value)); menu.refresh(),
				"help":"Fit shows the whole picture; Fill crops it to fill the screen; Stretch changes its shape. Saved for this game or video."})
			return [page("Everyday",quick)]
		2:
			var audio = h.emulator.tv_audio
			var audio_rows: Array=[
				{"id":"audio.mode","label":"Sound mode","kind":"choice","choices":["Original","TV speakers","TV in the room"],"default":2,"visual":false,"getter":func(): return audio.mode,"setter":func(value): audio.mode=value; audio.apply(); menu.refresh(),"help":"Original has no processing. TV speakers adds cabinet character. TV in the room adds reflections and keeps the sound with the TV as you turn."},
				number("audio.room_amount","Room reflections",audio,"room_amount",0,.25,.01,audio.DEFAULTS.room_amount,"percent","Adds short reflections around the TV.",audio.apply,false),
				number("audio.speaker_character","Speaker character",audio,"speaker_character",0,1,.05,audio.DEFAULTS.speaker_character,"percent","Narrows stereo and softens bass and treble.",audio.apply,false),
				number("audio.directional_strength","Stays with the TV",audio,"directional_strength",0,1,.05,audio.DEFAULTS.directional_strength,"percent","Keeps the sound towards the TV as your head turns.",audio.apply,false)]
			for index in [1,2,3]:
				if (index==2 and audio.mode==0) or (index!=2 and audio.mode!=2):
					audio_rows[index].disabled=true
					audio_rows[index].disabled_reason="Only with TV speakers or TV in the room." if index==2 else "Only in TV in the room mode."
			audio_rows.append(action("audio.preview","Preview sound",audio.preview_sample,"Plays a short sample through the selected sound mode while the game stays paused."))
			var music = h.music
			var visualiser: Array = [
				{"id":"visualiser.preset","label":"Visualiser preset","kind":"choice","choices":h.visualizer.preset_names(),"default":0,"getter":func(): return h.visualizer.preset_index,"setter":h.visualizer.select_preset,"help":"Three bundled presets, then your own: put projectM or MilkDrop .milk files in a folder called Visualiser presets inside your music folder.","visual":false},
				toggle("visualiser.automatic","Automatic presets",h.visualizer,"automatic",true,"Change preset every 30 seconds. Reduced motion keeps the current preset.",h.visualizer.save_preferences,false),
				number("visualiser.brightness","Visualiser brightness",h.visualizer,"brightness",0.3,1.5,0.1,1.0,"percent","Independent brightness for music visuals.",h.visualizer.save_preferences,false)]
			visualiser[0]["section"] = "VISUALISER"
			var music_rows: Array = [
				toggle("music.loop","Repeat album",music,"loop",true,"Starts the folder again after its last track. Off stops at the album's end.",music.apply,false),
				number("music.reverb","Room reverb",music,"reverb",0,.3,.01,.12,"percent","Short, subtle reflections from the room; zero turns it off.",music.apply,false),
				number("music.directional","Stays beside the TV",music,"directional",0,1,.05,.8,"percent","Music stays put as you turn your head. Zero keeps normal stereo.",music.apply,false),
				number("music.side","Radio position",music,"side",-2,2,.1,-1.1,"m","Left or right of the TV, independent of the game's sound.",music.apply,false)]
			music_rows.append_array(visualiser)
			music_rows.append({"id":"music.sleep","label":"Sleep timer","kind":"choice","choices":h.SLEEP_CHOICES.map(func(m): return "Off" if m == 0 else "%d minutes" % m),"default":0,"visual":false,"section":"SLEEP",
					"getter":func(): return maxi(0,h.SLEEP_CHOICES.find(h.sleep_minutes)),"setter":func(value): h.set_sleep_timer(h.SLEEP_CHOICES[int(value)]); menu.refresh(),
					"detail_getter":func(): return ("%d min left" % ceili(h.sleep_left / 60.0)) if h.sleep_left > 0.0 else "",
					"help":"Stops the music, pauses the game or video (saving its resume point) and switches the TV off after this long. For this session only."})
			var menu_rows: Array = [
				toggle("access.menu_music","Menu music",h,"menu_music_enabled",true,"Quiet background music while menus are open. Waits for the boot sound to tail off and yields to your own music. Its volume is on Volumes.",h.apply_menu_music,false),
				toggle("access.boot_sound","Boot sound",h,"menu_boot_sound",true,"Plays the startup sound when the boot screen appears. Turn off for a quiet launch.",h.apply_boot_sound,false),
				toggle("access.sounds","Menu clicks",h,"menu_sounds",false,"Quiet feedback for focus and confirmation.",unchanged,false)]
			return [page("Volumes",volume_rows(),"Every level in one place"),page("TV speakers",audio_rows,"How the game sounds from the TV"),page("Music",music_rows,"Music preferences · play albums and radio from the music browser"),page("Menu sounds",menu_rows,"Sounds the menu itself makes")]
	return []

## Scenes (saved setups): three slots holding the view, the room and the picture together.
func saved_setups_page() -> Dictionary:
	var h = host
	var slots: Array = []
	for i in range(3):
		var slot := i
		var config = h.settings_store.read("user://presets/slot-%d.cfg" % i)
		var saved: bool = config.has_section("view")
		slots.append(action("slot.%d" % i,str(config.get_value("meta","name",h.PROFILE_NAMES[i])),func(): menu.open_slot(slot),"A scene is a whole mood: where the TV sits, the room and the picture. Games with their own picture or look keep it; input delay stays as it is.",false,"Saved" if saved else "Empty"))
	if h.profile_undo!=null: slots.append(action("setups.undo","Undo last scene load",h.undo_profile,"Restore the view, room and picture from before the last scene load."))
	return page("Scenes",slots,"A look, a room and your view, saved together")

## Games → Consoles: console names and icons as they were sold in your region.
func region_row() -> Dictionary:
	var h = host
	return {"id":"access.region","label":"Console names & icons","kind":"choice","choices":Array(h.emulator.Registry.REGION_LABELS),"default":0,"visual":false,"section":"NAMES",
		"getter":func(): return maxi(0,h.emulator.Registry.REGIONS.find(h.console_region)),
		"setter":func(value): h.apply_console_region(h.emulator.Registry.REGIONS[int(value)]); menu.refresh(),
		"help":"Shows console names and icons as they were sold in your region. Games and saves are not affected."}

func controls_subtitle() -> String:
	var em = host.emulator
	if not em.loaded: return "Start a game to change its controls"
	return em.Registry.SYSTEMS[em.system_id].name + " controls"

func vmu_page() -> Dictionary:
	var vmu = host.vmu_display
	var vmu_rows: Array = [toggle("vmu.enabled","Floating VMU display",vmu,"enabled",true,"Shows player one's VMU LCD below the TV during Dreamcast games. Look down to see it. The panel stays anchored in the room.",vmu.apply_layout)]
	for spec in [["horizontal","Horizontal position",-1.5,1.5,0.05],["vertical","Vertical position",-1.5,-0.1,0.05],["forward","Distance in front of TV",0.2,1.5,0.05],["width","Display width",0.2,0.8,0.02]]:
		vmu_rows.append(number("vmu."+spec[0],spec[1],vmu,spec[0],spec[2],spec[3],spec[4],vmu.DEFAULTS[spec[0]],"m","Relative to the TV. Changes apply immediately and are saved with your settings.",vmu.apply_layout))
	return page("Dreamcast VMU",vmu_rows,"While a Dreamcast game is loaded")
