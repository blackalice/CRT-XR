extends Node
## Box art from scrapes the player already has: ES-DE / EmuDeck / RetroDECK
## "downloaded_media" folders, and media folders beside the ROMs. Nothing is
## downloaded. Images load on a background thread; art_ready announces each.
signal art_ready(rom_path: String, texture: Texture2D)
const MEDIA_TYPES := ["covers", "box2dfront", "3dboxes", "miximages", "screenshots"]
## Folders some scrapers put beside the ROMs, best first.
const BESIDE := ["media/box2dfront", "media/covers", "media/boxart", "media/images", "boxart", "covers", "images"]
const EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const MAX_HEIGHT := 160

var rom_root := ""
var found: Dictionary = {}
var textures: Dictionary = {}
var listings: Dictionary = {}
var queue: Array[String] = []
var thread: Thread

## Starts again for a (new) ROM folder.
func set_root(path: String) -> void:
	if path == rom_root: return
	rom_root = path
	found.clear(); listings.clear()

## Where ES-DE style scrapes keep their media, most likely first.
func media_roots() -> Array[String]:
	var roots: Array[String] = []
	var home := OS.get_environment("HOME") if OS.get_name() != "Windows" else OS.get_environment("USERPROFILE")
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

## The box art file for a ROM, or "" when the player has none.
func find(rom_path: String) -> String:
	if found.has(rom_path): return found[rom_path]
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
		for kind in MEDIA_TYPES:
			result = match_in(root.path_join(system).path_join(kind).path_join(relative), base)
			if result.is_empty() and not relative.is_empty(): result = match_in(root.path_join(system).path_join(kind), base)
			if not result.is_empty(): break
		if not result.is_empty(): break
	if result.is_empty():
		for beside in BESIDE:
			result = match_in(folder.path_join(beside), base)
			if result.is_empty(): result = match_in(folder.path_join(beside), base + "-image")
			if not result.is_empty(): break
	found[rom_path] = result
	return result

## The art as a texture, or null until it has loaded (art_ready follows).
func texture(rom_path: String) -> Texture2D:
	if textures.has(rom_path): return textures[rom_path]
	if find(rom_path).is_empty(): return null
	textures[rom_path] = null
	queue.append(rom_path)
	_next()
	return null

func _next() -> void:
	if queue.is_empty() or (thread != null and thread.is_alive()): return
	if thread != null: thread.wait_to_finish()
	thread = Thread.new()
	var rom: String = queue.pop_front()
	thread.start(_load.bind(rom, find(rom)))

## On the loading thread: decode and shrink one image.
func _load(rom_path: String, file: String) -> void:
	var image := Image.load_from_file(file)
	if image != null and image.get_height() > MAX_HEIGHT:
		image.resize(maxi(1, image.get_width() * MAX_HEIGHT / image.get_height()), MAX_HEIGHT, Image.INTERPOLATE_BILINEAR)
	_loaded.call_deferred(rom_path, image)

func _loaded(rom_path: String, image: Image) -> void:
	var art: Texture2D = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	textures[rom_path] = art
	art_ready.emit(rom_path, art)
	_next()

func _exit_tree() -> void:
	queue.clear()
	if thread != null: thread.wait_to_finish()
