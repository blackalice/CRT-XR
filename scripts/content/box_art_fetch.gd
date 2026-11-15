extends Node
## Optional box art download from the libretro-thumbnails collection, for games
## your own scrapes don't cover. Only runs when you ask (Get box art, or the
## automatic option); needs no account. Matching is by No-Intro / Redump name:
## each game offers a few spellings (its file name, the name identified from
## its contents, GoodTools codes written out) and the first the collection has
## is kept. Art is saved in CRT XR's own folder (user://boxart/<console
## folder>/<ROM name>.png), never beside your ROMs. Games the collection
## doesn't have are remembered, so they aren't asked for again every time.

signal progress(done: int, total: int, found: int)
signal finished(found: int, missing: int)

const BASE_URL := "https://thumbnails.libretro.com"
const FOLDER := "user://boxart"
const MISSES := "user://boxart/not-found.cfg"
## libretro playlist names, by CRT XR console id.
const SYSTEMS := {
	"nes": "Nintendo - Nintendo Entertainment System",
	"snes": "Nintendo - Super Nintendo Entertainment System",
	"megadrive": "Sega - Mega Drive - Genesis",
	"mastersystem": "Sega - Master System - Mark III",
	"gamegear": "Sega - Game Gear",
	"segacd": "Sega - Mega-CD - Sega CD",
	"gameboy": "Nintendo - Game Boy",
	"gba": "Nintendo - Game Boy Advance",
	"pcengine": "NEC - PC Engine - TurboGrafx 16",
	"psx": "Sony - PlayStation",
	"n64": "Nintendo - Nintendo 64",
	"atari2600": "Atari - 2600",
	"atarilynx": "Atari - Lynx",
	"ngpc": "SNK - Neo Geo Pocket Color",
	"vectrex": "GCE - Vectrex",
	"dreamcast": "Sega - Dreamcast",
	"gamecube": "Nintendo - GameCube",
	"wii": "Nintendo - Wii",
	"ps2": "Sony - PlayStation 2",
	"psp": "Sony - PlayStation Portable",
}
## GoodTools region codes, as No-Intro writes them.
const GOOD_REGIONS := {"U": "USA", "E": "Europe", "J": "Japan", "W": "World", "UE": "USA, Europe", "JU": "Japan, USA",
	"JUE": "Japan, USA", "EU": "USA, Europe", "UK": "UK", "F": "France", "G": "Germany", "S": "Spain", "I": "Italy",
	"A": "Australia", "B": "Brazil", "K": "Korea", "C": "China"}

var queue: Array = [] # [[url, …], target, miss key]
var total := 0
var done := 0
var found := 0
var running := false
var request: HTTPRequest
var misses := ConfigFile.new()
var misses_loaded := false

## The libretro playlist a ROM belongs to: Game Boy Color and Neo Geo Pocket
## (mono) have their own, though CRT XR plays them on one console entry.
static func playlist(system: String, rom_path: String) -> String:
	var extension := rom_path.get_extension().to_lower()
	if system == "gameboy" and extension == "gbc": return "Nintendo - Game Boy Color"
	if system == "ngpc" and extension == "ngp": return "SNK - Neo Geo Pocket"
	return str(SYSTEMS.get(system, ""))

## libretro-thumbnails replaces these characters in names with "_".
static func thumbnail_name(name: String) -> String:
	var result := name
	for character in ["&", "*", "/", ":", "`", "<", ">", "?", "\\", "|", "\""]: result = result.replace(character, "_")
	return result

static func url_for(system: String, rom_path: String, name: String) -> String:
	var list := playlist(system, rom_path)
	if list.is_empty() or name.is_empty(): return ""
	return "%s/%s/Named_Boxarts/%s.png" % [BASE_URL, list.uri_encode(), thumbnail_name(name).uri_encode()]

## A GoodTools name ("Kirby's Dream Land (UE) [!]") as No-Intro writes it
## ("Kirby's Dream Land (USA, Europe)"); "" when it has no GoodTools region.
static func from_goodtools(name: String) -> String:
	var title := name
	var bracket := title.find("[")
	if bracket > 0: title = title.substr(0, bracket)
	var parts := title.split("(")
	if parts.size() < 2: return ""
	var base := parts[0].strip_edges()
	for i in range(1, parts.size()):
		var code := parts[i].get_slice(")", 0).strip_edges()
		if GOOD_REGIONS.has(code): return "%s (%s)" % [base, GOOD_REGIONS[code]]
	return ""

## The spellings to try for a ROM, most likely first.
static func names_for(file_name: String, identified: String) -> Array:
	var names: Array = []
	var base := file_name.get_basename()
	for candidate in [base, identified, from_goodtools(base)]:
		var clean := str(candidate).strip_edges()
		if not clean.is_empty() and not clean in names: names.append(clean)
	# Without the extra tags (languages, revisions), as a last try.
	if names.size() > 0:
		var first := str(names[0])
		var at := first.find(") (")
		if at > 0 and not first.substr(0, at + 1) in names: names.append(first.substr(0, at + 1))
	return names

## Where downloaded art for a ROM is kept: its console folder's name, as
## box_art.gd looks it up.
static func save_path(folder_name: String, rom_path: String) -> String:
	return ProjectSettings.globalize_path(FOLDER).path_join(folder_name).path_join(rom_path.get_file().get_basename() + ".png")

func load_misses() -> void:
	if misses_loaded: return
	misses_loaded = true
	misses.load(MISSES)

## True when the collection had nothing for this ROM last time.
func known_missing(rom_path: String) -> bool:
	load_misses()
	return misses.has_section_key("missing", rom_path.md5_text())

func forget_misses() -> void:
	load_misses()
	misses.clear()
	misses.save(MISSES)

## Queues the games that have no art yet. `games` holds [system, rom_path,
## [names…], console folder name]. Known misses are skipped unless `retry`.
func start(games: Array, retry := false) -> int:
	if running: return 0
	load_misses()
	queue.clear()
	for game in games:
		var urls: Array = []
		for name in game[2]:
			var url := url_for(game[0], game[1], str(name))
			if not url.is_empty() and not url in urls: urls.append(url)
		if urls.is_empty(): continue
		var target := save_path(game[3], game[1])
		if FileAccess.file_exists(target): continue
		var key := str(game[1]).md5_text()
		if not retry and misses.has_section_key("missing", key): continue
		queue.append([urls, target, key])
	total = queue.size(); done = 0; found = 0
	if total == 0:
		finished.emit(0, 0)
		return 0
	running = true
	if request == null:
		request = HTTPRequest.new()
		request.timeout = 20.0
		add_child(request)
		request.request_completed.connect(_on_completed)
	_next()
	return total

func cancel() -> void:
	queue.clear()
	if request != null: request.cancel_request()
	if running:
		running = false
		misses.save(MISSES)
		finished.emit(found, done - found)

func _next() -> void:
	if queue.is_empty():
		running = false
		misses.save(MISSES)
		finished.emit(found, done - found)
		return
	var job: Array = queue.front()
	DirAccess.make_dir_recursive_absolute(str(job[1]).get_base_dir())
	request.download_file = str(job[1]) + ".part"
	if request.request(str(job[0][0])) != OK:
		_finish_job(false)

## A real picture? Read from the bytes: the .part name says nothing of its format.
static func valid_image(path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 8: return false
	var image := Image.new()
	return image.load_png_from_buffer(bytes) == OK or image.load_jpg_from_buffer(bytes) == OK or image.load_webp_from_buffer(bytes) == OK

func _on_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if queue.is_empty(): return
	var job: Array = queue.front()
	var part := str(job[1]) + ".part"
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and valid_image(part):
		if FileAccess.file_exists(str(job[1])): DirAccess.remove_absolute(str(job[1]))
		DirAccess.rename_absolute(part, str(job[1]))
		_finish_job(true)
		return
	if FileAccess.file_exists(part): DirAccess.remove_absolute(part)
	# Not under this name: try the next spelling, if any.
	var urls: Array = job[0]
	urls.pop_front()
	if not urls.is_empty() and result == HTTPRequest.RESULT_SUCCESS:
		_next.call_deferred()
		return
	_finish_job(false, result == HTTPRequest.RESULT_SUCCESS and code == 404)

func _finish_job(ok: bool, missing := false) -> void:
	var job: Array = queue.pop_front() if not queue.is_empty() else []
	done += 1
	if ok: found += 1
	elif missing and not job.is_empty(): misses.set_value("missing", str(job[2]), true)
	progress.emit(done, total, found)
	_next.call_deferred()
