extends Node
## Optional box art download from the libretro-thumbnails collection, for games
## your own scrapes don't cover. Only runs when you choose Download missing box
## art; needs no account. Matching is by No-Intro / Redump name: the file name
## when it carries a region ("Game (USA).sfc"), else the name CRT XR gives the
## game from its contents. Art is saved in CRT XR's own folder
## (user://boxart/<console folder>/<ROM name>.png), never beside your ROMs.

signal progress(done: int, total: int, found: int)
signal finished(found: int, missing: int)

const BASE_URL := "https://thumbnails.libretro.com"
const FOLDER := "user://boxart"
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

var queue: Array = [] # [system, rom_path, name, save_path]
var total := 0
var done := 0
var found := 0
var running := false
var request: HTTPRequest

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

## Where downloaded art for a ROM is kept: its console folder's name, as
## box_art.gd looks it up.
static func save_path(folder_name: String, rom_path: String) -> String:
	return ProjectSettings.globalize_path(FOLDER).path_join(folder_name).path_join(rom_path.get_file().get_basename() + ".png")

## Queues the games that have no art yet. `games` holds [system, rom_path,
## name, console folder name]. Returns how many were queued.
func start(games: Array) -> int:
	if running: return 0
	queue.clear()
	for game in games:
		var url := url_for(game[0], game[1], game[2])
		if url.is_empty(): continue
		var target := save_path(game[3], game[1])
		if FileAccess.file_exists(target): continue
		queue.append([url, target])
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
		finished.emit(found, done - found)

func _next() -> void:
	if queue.is_empty():
		running = false
		finished.emit(found, done - found)
		return
	var job: Array = queue.front()
	DirAccess.make_dir_recursive_absolute(str(job[1]).get_base_dir())
	request.download_file = str(job[1]) + ".part"
	if request.request(str(job[0])) != OK:
		queue.pop_front(); done += 1
		_next.call_deferred()

func _on_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var job: Array = queue.pop_front() if not queue.is_empty() else []
	done += 1
	if not job.is_empty():
		var part := str(job[1]) + ".part"
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and Image.load_from_file(part) != null:
			DirAccess.rename_absolute(part, str(job[1]))
			found += 1
		elif FileAccess.file_exists(part):
			DirAccess.remove_absolute(part)
	progress.emit(done, total, found)
	_next()
