extends RefCounted
## The demo shelf: a few freely licensed games shipped with CRT XR, so a new
## player sees the TV working before they have set up a ROM folder.
##
## The demos live in their own read-only folder beside the app (demo/, or
## res://demo when running from the editor), described by demo/demo.json:
##   {"games": [{"system": "nes", "file": "nes/Game.nes", "title": "Game",
##     "author": "Name", "licence": "CC BY 4.0", "url": "https://…"}]}
## They are never scanned into, copied into or written beside your ROM folder,
## and the shelf disappears as soon as your own library has games. With no
## demo folder (as in builds that ship none), nothing is shown at all.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const MANIFEST := "demo.json"

static func folder() -> String:
	if OS.has_feature("editor"): return ProjectSettings.globalize_path("res://demo")
	return OS.get_executable_path().get_base_dir().path_join("demo")

## The demo games that are present and playable: dictionaries with system,
## path, title, author, licence and url.
static func games(root := "") -> Array:
	var base := root if not root.is_empty() else folder()
	var text := FileAccess.get_file_as_string(base.path_join(MANIFEST))
	if text.is_empty(): return []
	var data = JSON.parse_string(text)
	if not data is Dictionary or not data.get("games") is Array: return []
	var result: Array = []
	for entry in data.games:
		if not entry is Dictionary: continue
		var system := str(entry.get("system", ""))
		var file := str(entry.get("file", "")).simplify_path()
		# Stay inside the demo folder, on a console CRT XR plays.
		if file.is_empty() or file.begins_with("..") or file.is_absolute_path() or not Registry.SYSTEMS.has(system): continue
		var path := base.path_join(file)
		if not FileAccess.file_exists(path): continue
		result.append({"system": system, "path": path, "title": str(entry.get("title", file.get_file().get_basename())),
			"author": str(entry.get("author", "")), "licence": str(entry.get("licence", "")), "url": str(entry.get("url", ""))})
	return result

## Shown only while your own library is empty.
static func visible(library_games: int, root := "") -> bool:
	return library_games == 0 and not games(root).is_empty()

## True for a path inside the demo folder: such games are not kept in Recent
## or offered for Favourites, so they never mix with your own.
static func is_demo(path: String, root := "") -> bool:
	var base := (root if not root.is_empty() else folder()).simplify_path()
	return not path.is_empty() and path.simplify_path().begins_with(base + "/")

## A credit line for the shelf.
static func credit(game: Dictionary) -> String:
	var parts: Array = []
	if not str(game.author).is_empty(): parts.append("By " + str(game.author))
	if not str(game.licence).is_empty(): parts.append(str(game.licence))
	return " · ".join(parts)
