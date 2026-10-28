extends Node
## Box art from scrapes the player already has: ES-DE / EmuDeck / RetroDECK
## "downloaded_media" folders, and media folders beside the ROMs. Nothing is
## downloaded. Images load on a background thread; art_ready announces each.
const Platform = preload("res://scripts/platform/platform.gd")
signal art_ready(rom_path: String, texture: Texture2D)
## A printed front cover for the box on the table (see cover()).
signal cover_ready(rom_path: String, texture: Texture2D)
const MEDIA_TYPES := ["covers", "box2dfront", "3dboxes", "miximages", "screenshots"]
## Folders some scrapers put beside the ROMs, best first.
const BESIDE := ["media/box2dfront", "media/covers", "media/boxart", "media/images", "boxart", "covers", "images"]
## Only flat front covers can be printed on a box: no 3D renders or screenshots.
const COVER_TYPES := ["covers", "box2dfront"]
const COVER_BESIDE := ["media/box2dfront", "media/covers", "media/boxart", "boxart", "covers"]
const EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const MAX_HEIGHT := 160
## The box on the table is seen up close, so its cover loads larger.
const COVER_HEIGHT := 512

var rom_root := ""
var found: Dictionary = {}
var textures: Dictionary = {}
var listings: Dictionary = {}
## Loads waiting for the thread: [cache key, ROM path, file, height].
var queue: Array = []
var thread: Thread

## Starts again for a (new) ROM folder.
func set_root(path: String) -> void:
	if path == rom_root: return
	rom_root = path
	found.clear(); listings.clear()

## Where ES-DE style scrapes keep their media, most likely first.
func media_roots() -> Array[String]:
	var roots: Array[String] = []
	var home := Platform.home_folder()
	if not rom_root.is_empty():
		roots.append(rom_root.get_base_dir().path_join("tools/downloaded_media")) # EmuDeck: Emulation/roms → Emulation/tools
		roots.append(rom_root.get_base_dir().path_join("ES-DE/downloaded_media"))
		roots.append(rom_root.path_join("downloaded_media"))
	if not home.is_empty():
		for relative in ["ES-DE/downloaded_media", "retrodeck/ES-DE/downloaded_media", ".emulationstation/downloaded_media"]:
			roots.append(home.path_join(relative))
	return roots

## Lower-case file name without extension → real file name, for one folder.
func listing(folder: String) -> Dictionary:
	if listings.has(folder): return listings[folder]
	var names := {}
	if DirAccess.dir_exists_absolute(folder):
		for file in DirAccess.get_files_at(folder):
			if file.get_extension().to_lower() in EXTENSIONS: names[file.get_basename().to_lower()] = file
	listings[folder] = names
	return names

func match_in(folder: String, base: String) -> String:
	var names := listing(folder)
	return folder.path_join(names[base]) if names.has(base) else ""

## The box art file for a ROM, or "" when the player has none. `kinds` and
## `beside` narrow the search, as cover() does for printable front covers.
func find(rom_path: String, kinds: Array = MEDIA_TYPES, beside_folders: Array = BESIDE) -> String:
	var cache_key := rom_path if kinds == MEDIA_TYPES else rom_path + "|cover"
	if found.has(cache_key): return found[cache_key]
	var result := ""
	var base := rom_path.get_file().get_basename().to_lower()
	var folder := rom_path.get_base_dir()
	# The console folder and any subfolders below it, as ES-DE mirrors them.
	var relative := ""
	var system_folder := folder
	if not rom_root.is_empty() and folder.begins_with(rom_root):
		var inside := folder.substr(rom_root.length()).trim_prefix("/").trim_prefix("\\")
		var parts := inside.replace("\\", "/").split("/", false)
		if not parts.is_empty():
			system_folder = rom_root.path_join(parts[0])
			relative = "/".join(parts.slice(1))
	var system := system_folder.get_file()
	for root in media_roots():
		for kind in kinds:
			result = match_in(root.path_join(system).path_join(kind).path_join(relative), base)
			if result.is_empty() and not relative.is_empty(): result = match_in(root.path_join(system).path_join(kind), base)
			if not result.is_empty(): break
		if not result.is_empty(): break
	if result.is_empty():
		for beside in beside_folders:
			result = match_in(folder.path_join(beside), base)
			if result.is_empty(): result = match_in(folder.path_join(beside), base + "-image")
			if not result.is_empty(): break
	found[cache_key] = result
	return result

## The art as a texture, or null until it has loaded (art_ready follows).
func texture(rom_path: String) -> Texture2D:
	return _request(rom_path, rom_path, find(rom_path), MAX_HEIGHT)

## A flat front cover, larger, for the box on the table; null until it has
## loaded (cover_ready follows) or when the scrapes have none.
func cover(rom_path: String) -> Texture2D:
	return _request(rom_path + "|cover", rom_path, find(rom_path, COVER_TYPES, COVER_BESIDE), COVER_HEIGHT)

func _request(key: String, rom_path: String, file: String, height: int) -> Texture2D:
	if textures.has(key): return textures[key]
	if file.is_empty(): return null
	textures[key] = null
	queue.append([key, rom_path, file, height])
	_next()
	return null

func _next() -> void:
	if queue.is_empty() or (thread != null and thread.is_alive()): return
	if thread != null: thread.wait_to_finish()
	thread = Thread.new()
	var job: Array = queue.pop_front()
	thread.start(_load.bind(job))

## On the loading thread: decode and shrink one image, with mipmaps for the
## table cover, which is seen at an angle.
func _load(job: Array) -> void:
	var height: int = job[3]
	var image := Image.load_from_file(job[2])
	if image != null and image.get_height() > height:
		image.resize(maxi(1, image.get_width() * height / image.get_height()), height, Image.INTERPOLATE_BILINEAR)
	if image != null and height == COVER_HEIGHT: image.generate_mipmaps()
	_loaded.call_deferred(job, image)

func _loaded(job: Array, image: Image) -> void:
	var art: Texture2D = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	textures[job[0]] = art
	if str(job[0]).ends_with("|cover"): cover_ready.emit(job[1], art)
	else: art_ready.emit(job[1], art)
	_next()

func _exit_tree() -> void:
	queue.clear()
	if thread != null: thread.wait_to_finish()
