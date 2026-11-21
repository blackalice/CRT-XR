extends RefCounted
## The Looks manager: named pictures that games and consoles link to.
##
## Picture → Looks lists the built-in looks (applied as a copy, as before) and
## your own looks. Your own looks are linked, not copied: a look used by "all
## Mega Drive games" or by a hand-picked set of games changes all of them when
## you edit it. Each look's page applies it to this game or its console, picks
## games and consoles from the library, edits, renames, duplicates, shares as a
## code, or deletes it. Data lives in display_preferences.gd (see "Looks").
var host: Node
var menu: Control
## The look whose page is open.
var look := ""
## Choose games: "" lists consoles; otherwise that console's games.
var choose_system := ""
var choose_page := 0
const PAGE_SIZE := 50

func prefs():
	return host.display_settings

func catalog():
	return menu.catalog

## Old "My looks" slots become linked looks once, keeping their names.
func migrate_presets() -> void:
	var p = prefs()
	if bool(p.data.get("looks_migrated", false)): return
	p.data["looks_migrated"] = true
	var names: Dictionary = {"mask":"phosphor_mask","glow":"phosphor_glow","glass":"glass_reflections","curvature":"screen_curvature","connection":"mode"}
	for index in range(menu.pictures.MY_PRESET_COUNT):
		if not menu.pictures.my_preset_saved(index): continue
		var config: ConfigFile = host.SettingsStore.new().read(menu.pictures.my_preset_path(index))
		var values := {}
		for section in ["crt", "picture"]:
			if not config.has_section(section): continue
			for field in config.get_section_keys(section):
				values[section + "." + str(names.get(field, field))] = config.get_value(section, field)
		values = p.look_values_from(values)
		if not values.is_empty(): p.create_look(menu.pictures.my_preset_name(index), values)

## Short "where it's used" text for a look.
func usage_text(id: String) -> String:
	var p = prefs()
	var used: Dictionary = p.look_usage(id)
	var parts: Array = []
	for system in used.consoles: parts.append("All " + catalog().console_short(system))
	if int(used.games) > 0: parts.append(menu.count_caption(int(used.games), "game"))
	return ", ".join(parts) if not parts.is_empty() else "Not used yet"

func in_use_here(id: String) -> String:
	var p = prefs()
	if not host.emulator.loaded: return ""
	if p.look_for_game(p.content, host.emulator.rom_path) == id: return "✓ This game"
	if p.look_for_console(host.emulator.system_id) == id: return "✓ This console"
	return ""

## Picture → Looks: the rows after the built-in looks.
func rows() -> Array:
	migrate_presets()
	var c = catalog()
	var p = prefs()
	var result: Array = []
	if not p.editing_look.is_empty():
		var done: Dictionary = c.action("look.finish", "Finish editing “%s”" % p.look_name(p.editing_look), func(): p.end_look_edit(); menu.refresh(); menu.notify("Look saved · every game using it is updated"),
			"Your changes are already saved in the look. This returns the Picture tabs to the game you're playing.", false, "Done")
		done["section"] = "EDITING A LOOK"
		done["emphasis"] = "primary"
		result.append(done)
	if host.emulator.loaded:
		var current: String = p.look_for_game(p.content, host.emulator.rom_path)
		var console_look: String = p.look_for_console(host.emulator.system_id)
		var here := "This game uses “%s”" % p.look_name(current) if not current.is_empty() else ("All %s games use “%s”" % [c.console_short(host.emulator.system_id), p.look_name(console_look)] if not console_look.is_empty() else "")
		if not here.is_empty():
			var row: Dictionary = c.unavailable(c.action("look.here", here, func(): pass, "", true, ""), "Open the look below to edit it or stop using it.")
			row["section"] = "THIS GAME"
			result.append(row)
		# Why does this game look different? Its own changes, and a way to clear them.
		var own: int = own_changes()
		if own > 0:
			var clear: Dictionary = c.action("look.clear_game", "Clear this game's own changes", clear_game_changes,
				"This game has %s of its own on top of %s. Clearing them keeps any look it uses and its fitting." % [menu.count_caption(own, "picture change"), ("its look" if not current.is_empty() else ("the console's look" if not console_look.is_empty() else "your defaults"))], false, menu.count_caption(own, "change"))
			if here.is_empty(): clear["section"] = "THIS GAME"
			result.append(clear)
	var first := true
	for pair in p.look_list():
		var id: String = pair[0]
		var item: Dictionary = c.action("look.open." + id, pair[1], func(): open(id), usage_text(id) + ". Open to apply it, choose its games, edit, share or delete it.", false, in_use_here(id) if not in_use_here(id).is_empty() else "›")
		if first: item["section"] = "MY LOOKS"; first = false
		result.append(item)
	var create: Dictionary = c.action("look.new", "New look from this picture", create_from_current,
		"Keeps the picture on screen now (tube, colour and signal) as a look you can give to any games or consoles. Fitting stays with each game.", false, "+")
	if first: create["section"] = "MY LOOKS"
	result.append(create)
	result.append(c.action("look.paste", "Add a shared look", paste_look, "Paste a look someone shared (a CRTXR-LOOK1 code) from the clipboard.", false, "›"))
	return result

## Picture changes (not fitting) saved for the loaded game alone.
func own_changes() -> int:
	var p = prefs()
	if p.content.is_empty() or not p.editing_look.is_empty(): return 0
	var patch = p.data.pictures.get(p.kind + "." + p.screen_id() + ".content." + p.content, {})
	if not patch is Dictionary: return 0
	var fields: Array = p.look_fields()
	return patch.keys().filter(func(key): return key in fields).size()

func clear_game_changes() -> void:
	menu.ask("Clear this game's changes?", "Its picture goes back to its look or defaults. Its fitting stays.", func():
		var p = prefs()
		p.commit()
		var key: String = p.kind + "." + p.screen_id() + ".content." + p.content
		var patch = p.data.pictures.get(key, {})
		if patch is Dictionary:
			for field in p.look_fields(): patch.erase(field)
			if patch.is_empty(): p.data.pictures.erase(key)
		p.applied.clear(); p.resolve_picture()
		host.settings_dirty = true
		menu.mode = "settings"; menu.render(); menu.notify("This game's picture changes are cleared"), "", "Clear")

func create_from_current() -> void:
	var p = prefs()
	var id: String = p.create_look("My look %d" % (p.look_list().size() + 1))
	host.settings_dirty = true
	open(id)
	menu.notify("New look saved · rename it, then choose its games")

func paste_look() -> void:
	var id: String = prefs().import_look(DisplayServer.clipboard_get())
	if id.is_empty():
		menu.notify("Copy a CRTXR-LOOK1 code first, then choose Add a shared look.")
		return
	host.settings_dirty = true
	open(id)
	menu.notify("Added · " + prefs().look_name(id))

func open(id: String) -> void:
	menu.remember(); menu.clear_input()
	look = id; menu.mode = "look"; menu.render()

func heading() -> String:
	return prefs().look_name(look)

func subtitle() -> String:
	return "Look · " + usage_text(look)

## One look's page.
func items() -> Array:
	var c = catalog()
	var p = prefs()
	var id := look
	if not p.look_exists(id): return [c.action("look.gone", "This look was deleted", menu.back, "", false, "")]
	var result: Array = []
	if host.emulator.loaded:
		var system: String = host.emulator.system_id
		var game_key: String = p.game_link_key()
		var for_game: bool = p.look_for_game(p.content, host.emulator.rom_path) == id
		var game_row: Dictionary = c.action("look.this_game", "Stop using for this game" if for_game else "Use for this game", func():
			p.link_look(game_key, "" if for_game else id)
			p.link_look("path." + host.emulator.rom_path, "")
			host.settings_dirty = true; menu.refresh(),
			"Links this game to the look. Your own tweaks to this game still apply on top; clear them in Picture → Fit & TV.", game_key.is_empty(), "✓" if for_game else "")
		game_row["section"] = "THIS GAME"
		result.append(game_row)
		var for_console: bool = p.look_for_console(system) == id
		result.append(c.action("look.this_console", ("Stop using for all %s games" if for_console else "Use for all %s games") % c.console_short(system), func():
			p.link_look("platform." + system, "" if for_console else id)
			host.settings_dirty = true; menu.refresh(),
			"Every %s game starts from this look. A game with its own look keeps it." % c.console_short(system), false, "✓" if for_console else ""))
	var choose: Dictionary = c.action("look.choose", "Choose games and consoles…", func(): open_chooser(""), "Tick the consoles and games from your library that should use this look.", false, usage_text(id))
	choose["section"] = "USED BY"
	result.append(choose)
	var edit: Dictionary = c.action("look.edit", "Edit this look", func(): edit_look(id),
		"Opens the Picture tabs on the look itself. Every game and console using it changes with it.", false, "›")
	edit["section"] = "THIS LOOK"
	result.append(edit)
	result.append(c.action("look.rename", "Rename", func(): menu.rename_look = id; menu.rename_room = -1; menu.rename_preset = -1; menu.mode = "rename"; menu.entry_initialized = false; menu.clear_input(); menu.render(); menu.keys.focus_entry(), "Use the on-screen keys or a physical keyboard.", false, "›"))
	result.append(c.action("look.duplicate", "Duplicate", func():
		var copy: String = p.duplicate_look(id)
		host.settings_dirty = true
		open(copy); menu.notify("Copied · " + p.look_name(copy)), "A new look starting from this one, used by nothing yet.", false, ""))
	result.append(c.action("look.share", "Copy share code", func():
		DisplayServer.clipboard_set(p.look_share_code(id))
		menu.notify("Share code copied · paste it anywhere; others add it with Add a shared look"), "Copies a short text holding this look's name and picture settings, nothing else.", false, ""))
	result.append(c.action("look.delete", "Delete", func(): delete(id), "Removes the look. Games and consoles that used it go back to their own picture.", false, ""))
	return result

func edit_look(id: String) -> void:
	prefs().begin_look_edit(id)
	menu.open_settings_section(1, "Tube")
	menu.notify("Editing “%s” · changes apply to every game using it" % prefs().look_name(id))

func delete(id: String) -> void:
	var name: String = prefs().look_name(id)
	menu.ask("Delete this look?", "Remove “%s”? Games and consoles using it go back to their own picture." % name, func():
		prefs().delete_look(id)
		host.settings_dirty = true
		menu.mode = "settings"; menu.render(); menu.notify("Deleted · " + name))

# ── Choose games and consoles ───────────────────────────────────────────────

func open_chooser(system: String) -> void:
	menu.remember(); menu.clear_input()
	choose_system = system; choose_page = 0
	menu.mode = "look_games"; menu.render()

func chooser_heading() -> String:
	return "Use “%s”" % prefs().look_name(look)

func chooser_subtitle() -> String:
	if choose_system.is_empty(): return "Consoles and their games · " + usage_text(look)
	return str(host.emulator.Registry.SYSTEMS.get(choose_system, {}).get("name", choose_system)) + " · A ticks a game"

func chooser_items() -> Array:
	var c = catalog()
	var p = prefs()
	var id := look
	var result: Array = []
	var Registry = host.emulator.Registry
	if choose_system.is_empty():
		for system in Registry.SYSTEMS:
			var found: Array = menu.rom_index.games.get(system, [])
			if found.is_empty(): continue
			var linked := 0
			for game in found:
				if str(p.look_links().get("path." + str(game.path), "")) == id: linked += 1
			var whole: bool = p.look_for_console(system) == id
			var row: Dictionary = c.action("look_games.system." + system, str(Registry.SYSTEMS[system].name), func(): open_chooser(system),
				"All its games, or pick some.", false, "All games" if whole else (("%d of %d" % [linked, found.size()]) if linked > 0 else "›"))
			result.append(row)
		if result.is_empty():
			result.append(c.unavailable(c.action("look_games.empty", "No games in your library yet", func(): pass, "", true, ""), "Set up your library in Game Library first."))
		return result
	var system := choose_system
	var whole: bool = p.look_for_console(system) == id
	var all: Dictionary = c.action("look_games.all", "All %s games" % c.console_short(system), func():
		p.link_look("platform." + system, "" if whole else id)
		host.settings_dirty = true; menu.refresh(),
		"Every game on this console starts from this look, now and as you add more. A game with its own look keeps it.", false, "✓" if whole else "")
	all["section"] = "THE WHOLE CONSOLE"
	result.append(all)
	var games: Array = menu.rom_index.games.get(system, [])
	var start := choose_page * PAGE_SIZE
	var first := true
	for game in games.slice(start, start + PAGE_SIZE):
		var path := str(game.path)
		var key := "path." + path
		var linked: bool = str(p.look_links().get(key, "")) == id
		var other: String = str(p.look_links().get(key, ""))
		var row: Dictionary = c.action("look_games.game:" + path, str(game.get("label", path.get_file())), func():
			p.link_look(key, "" if linked else id)
			host.settings_dirty = true; menu.refresh(),
			("Uses “%s” now; ticking switches it to this look." % p.look_name(other)) if not other.is_empty() and other != id else "A ticks or unticks this game.", false, "✓" if linked else "")
		if first: row["section"] = "GAMES" + (" (page %d of %d)" % [choose_page + 1, ceili(games.size() / float(PAGE_SIZE))] if games.size() > PAGE_SIZE else ""); first = false
		result.append(row)
	if games.size() > start + PAGE_SIZE:
		result.append(c.action("look_games.next", "Next page", func(): menu.remember(); choose_page += 1; menu.render(), "", false, "›"))
	if choose_page > 0:
		result.append(c.action("look_games.previous", "Previous page", func(): menu.remember(); choose_page -= 1; menu.render(), "", false, "‹"))
	return result

func chooser_back() -> void:
	if not choose_system.is_empty(): open_chooser("")
	else: menu.mode = "look"; menu.render()
