extends RefCounted
## Names and details from the player's own EmulationStation / ES-DE / RetroDECK
## gamelist.xml files: beside the ROMs, or in ES-DE's gamelists folder. Nothing
## is downloaded. Unscraped lists only repeat the file name, so every name still
## goes through GameTitle.

## Fields kept per game, as gamelist.xml names them.
const FIELDS := ["name", "releasedate", "genre", "players", "publisher", "developer"]
## Gamelists larger than this are skipped rather than stall the scan.
const MAX_BYTES := 64 * 1024 * 1024

## Where gamelists for one console folder may be, most specific first:
## [gamelist file, folder its "./" paths are relative to].
static func candidates(rom_root: String, system_folder: String, folder: String) -> Array:
	var result: Array = [[folder.path_join("gamelist.xml"), folder]]
	if system_folder.is_empty(): return result
	# A console folder's list also names games in its subfolders ("./Europe/x.sfc").
	if system_folder != folder: result.append([system_folder.path_join("gamelist.xml"), system_folder])
	var system := system_folder.get_file()
	var roots: Array[String] = []
	if not rom_root.is_empty():
		roots.append(rom_root.get_base_dir().path_join("ES-DE/gamelists")) # Windows portable ES-DE, EmuDeck
		roots.append(rom_root.get_base_dir().path_join("tools/gamelists"))
	var home := OS.get_environment("USERPROFILE") if OS.get_name() == "Windows" else OS.get_environment("HOME")
	if not home.is_empty():
		for relative in ["ES-DE/gamelists", "retrodeck/ES-DE/gamelists", ".emulationstation/gamelists"]:
			roots.append(home.path_join(relative))
	for root in roots: result.append([root.path_join(system).path_join("gamelist.xml"), system_folder])
	return result

## Reads one gamelist: absolute ROM path (see key()) -> {name, year, genre, ...}.
static func read(file: String, base: String, rom_root := "") -> Dictionary:
	var result: Dictionary = {}
	if not FileAccess.file_exists(file): return result
	var size := FileAccess.open(file, FileAccess.READ)
	if size == null or size.get_length() > MAX_BYTES: return result
	size.close()
	var parser := XMLParser.new()
	if parser.open(file) != OK: return result
	var game: Dictionary = {}
	var field := ""
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := parser.get_node_name()
				if parser.is_empty(): continue
				if tag == "game": game = {}; field = ""
				elif tag == "desc": parser.skip_section()
				elif tag == "path" or tag in FIELDS: field = tag
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if not field.is_empty(): game[field] = str(game.get(field, "")) + parser.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "game":
					var path := resolve(str(game.get("path", "")).strip_edges(), base, rom_root)
					if not path.is_empty(): result[key(path)] = tidy(game)
					game = {}
				field = ""
	return result

## A gamelist path as an absolute path: "./x.sfc", "%ROMPATH%/snes/x.sfc" or absolute.
static func resolve(path: String, base: String, rom_root: String) -> String:
	if path.is_empty(): return ""
	path = path.xml_unescape().replace("\\", "/")
	if path.begins_with("%ROMPATH%"):
		if rom_root.is_empty(): return ""
		return rom_root.path_join(path.trim_prefix("%ROMPATH%").trim_prefix("/")).simplify_path()
	if path.begins_with("./"): return base.path_join(path.substr(2)).simplify_path()
	if path.is_absolute_path() or path.begins_with("//"): return path.simplify_path()
	return base.path_join(path).simplify_path()

## Paths compare without case on Windows and with either slash.
static func key(path: String) -> String:
	var normal := path.replace("\\", "/").simplify_path()
	return normal.to_lower() if OS.get_name() == "Windows" else normal

## Trimmed fields, the release year, and nothing empty.
static func tidy(game: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in FIELDS:
		var value := str(game.get(field, "")).xml_unescape().strip_edges()
		if value.is_empty(): continue
		if field == "releasedate":
			if value.left(4).is_valid_int() and int(value.left(4)) > 1950: result["year"] = value.left(4)
		else: result[field] = value
	return result
