extends Node
## What CRT XR can tell you about one game, for the game's info page.
##
## First from what you already have: your ES-DE / EmuDeck / RetroDECK
## gamelist.xml (description, year, genre, players, developer, publisher), and
## the name in the file. Then, only when you ask (or turn on online look-ups),
## a short description from Wikipedia: its free API needs no account. Results
## are kept in user://game-info, so each game is looked up once.

signal looked_up(rom_path: String, info: Dictionary)

const GameList = preload("res://scripts/content/game_list.gd")
const CACHE := "user://game-info"
const SEARCH := "https://en.wikipedia.org/w/rest.php/v1/search/page?limit=6&q="
const SUMMARY := "https://en.wikipedia.org/api/rest_v1/page/summary/"
## Words Wikipedia uses in a game article's short description.
const GAME_WORDS := ["video game", "game for", "game developed", "game published", "platform game", "role-playing", "shooter", "racing game", "puzzle game", "fighting game"]

var request: HTTPRequest
var busy := ""
var pending: Array = [] # [rom_path, query, console words]

static func cache_path(rom_path: String) -> String:
	return ProjectSettings.globalize_path(CACHE).path_join(rom_path.md5_text() + ".json")

## A description saved earlier for this game, or {}.
static func cached(rom_path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(cache_path(rom_path))
	if text.is_empty(): return {}
	var data = JSON.parse_string(text)
	return data if data is Dictionary else {}

## The game's gamelist.xml entry, description included: read when the page
## opens (the library scan skips descriptions to stay quick).
static func from_gamelist(rom_path: String, rom_root: String) -> Dictionary:
	var folder := rom_path.get_base_dir()
	var system_folder := folder
	if not rom_root.is_empty() and folder.begins_with(rom_root):
		var parts := folder.substr(rom_root.length()).trim_prefix("/").trim_prefix("\\").replace("\\", "/").split("/", false)
		if not parts.is_empty(): system_folder = rom_root.path_join(parts[0])
	var wanted := GameList.key(rom_path)
	for candidate in GameList.candidates(rom_root, system_folder, folder):
		var found := read_entry(str(candidate[0]), str(candidate[1]), rom_root, wanted)
		if not found.is_empty(): return found
	return {}

## One game's entry from a gamelist file, with its description.
static func read_entry(file: String, base: String, rom_root: String, wanted: String) -> Dictionary:
	if not FileAccess.file_exists(file): return {}
	var parser := XMLParser.new()
	if parser.open(file) != OK: return {}
	var game: Dictionary = {}
	var field := ""
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := parser.get_node_name()
				if parser.is_empty(): continue
				if tag == "game": game = {}; field = ""
				elif tag in ["path", "desc"] or tag in GameList.FIELDS: field = tag
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if not field.is_empty(): game[field] = str(game.get(field, "")) + parser.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "game":
					var path := GameList.resolve(str(game.get("path", "")).strip_edges(), base, rom_root)
					if not path.is_empty() and GameList.key(path) == wanted:
						var tidy := GameList.tidy(game)
						var desc := str(game.get("desc", "")).xml_unescape().strip_edges()
						if not desc.is_empty(): tidy["description"] = desc
						return tidy
					game = {}
				field = ""
	return {}

## Picks the game's article from Wikipedia search results: the first whose
## short description says it is a game, preferring one naming the console.
static func pick(pages: Array, console_words: Array) -> Dictionary:
	var games: Array = pages.filter(func(page): return page is Dictionary and is_game(str(page.get("description", ""))))
	for page in games:
		var description := str(page.get("description", "")).to_lower()
		if console_words.any(func(word): return description.contains(str(word).to_lower())): return page
	return games[0] if not games.is_empty() else {}

static func is_game(description: String) -> bool:
	var lower := description.to_lower()
	return GAME_WORDS.any(func(word): return lower.contains(word))

static func user_agent() -> String:
	return "CRT-XR/%s (+https://github.com/blackalice/CRT-XR)" % str(ProjectSettings.get_setting("application/config/version", "dev"))

## Looks a game up on Wikipedia. `title` is the game's clean name; console words
## ("SNES", "Super Nintendo") help choose between same-named articles.
## looked_up follows with {description, source, url, title} or {error}.
func look_up(rom_path: String, title: String, console_words: Array) -> void:
	if not busy.is_empty():
		pending.append([rom_path, title, console_words]); return
	busy = rom_path
	if request == null:
		request = HTTPRequest.new(); request.timeout = 15.0; add_child(request)
	var headers := PackedStringArray(["User-Agent: " + user_agent(), "Accept: application/json"])
	if request.request(SEARCH + (title + " video game").uri_encode(), headers) != OK: finish({"error": "Couldn't start the look-up."}); return
	var answer: Array = await request.request_completed
	if int(answer[0]) != HTTPRequest.RESULT_SUCCESS or int(answer[1]) != 200: finish({"error": "Couldn't reach Wikipedia. Check the internet connection and try again."}); return
	var found = JSON.parse_string((answer[3] as PackedByteArray).get_string_from_utf8())
	var page := pick(found.get("pages", []) if found is Dictionary else [], console_words)
	if page.is_empty(): finish({"error": "Wikipedia has no article that looks like this game.", "missing": true}); return
	if request.request(SUMMARY + str(page.get("key", "")).uri_encode(), headers) != OK: finish({"error": "Couldn't start the look-up."}); return
	answer = await request.request_completed
	if int(answer[0]) != HTTPRequest.RESULT_SUCCESS or int(answer[1]) != 200: finish({"error": "Couldn't read the Wikipedia article. Try again later."}); return
	var summary = JSON.parse_string((answer[3] as PackedByteArray).get_string_from_utf8())
	if not summary is Dictionary or str(summary.get("extract", "")).is_empty(): finish({"error": "The Wikipedia article had no summary.", "missing": true}); return
	var info := {"description": str(summary.extract), "source": "Wikipedia", "title": str(summary.get("title", page.get("title", ""))),
		"url": str(summary.get("content_urls", {}).get("desktop", {}).get("page", "")), "licence": "CC BY-SA 4.0", "fetched": int(Time.get_unix_time_from_system())}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE))
	var file := FileAccess.open(cache_path(rom_path), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(info)); file.close()
	finish(info)

func finish(info: Dictionary) -> void:
	var path := busy
	busy = ""
	looked_up.emit(path, info)
	if not pending.is_empty():
		var next: Array = pending.pop_front()
		look_up.call_deferred(next[0], next[1], next[2])
