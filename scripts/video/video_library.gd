extends RefCounted
## The user's video folder: listings, lengths and per-file resume points and
## display styles. Files are only read, never moved or changed.
const SettingsStore = preload("res://scripts/ui/settings_store.gd")
const EXTENSIONS := ["mp4", "m4v", "mkv"]
const RESUME_PATH := "user://video_resume.cfg"
## Positions this close to either end are not worth offering to resume.
const RESUME_MIN_SECONDS := 10.0
const RESUME_END_SECONDS := 30.0
const COUNT_LIMIT := 999
const SEARCH_LIMIT := 100
const THUMBNAILS := "user://video_thumbnails"
const THUMBNAIL_SIZE := Vector2i(128, 96)
## A thumbnail was made (or failed: no texture) in the background.
signal thumbnail_ready(path: String, texture: Texture2D)
var thumbnails: Dictionary = {}
var thumbnail_queue: Array[String] = []
var thumbnail_thread: Thread
var resume_path := RESUME_PATH
var resume := ConfigFile.new()
var durations: Dictionary = {}
var counts: Dictionary = {}

func _init(path := RESUME_PATH) -> void:
	resume_path = path
	resume = SettingsStore.new().read(resume_path)

static func is_video(path: String) -> bool:
	return path.get_extension().to_lower() in EXTENSIONS

static func clock(seconds: float) -> String:
	var whole := maxi(0, int(seconds))
	if whole >= 3600: return "%d:%02d:%02d" % [whole / 3600, whole / 60 % 60, whole % 60]
	return "%d:%02d" % [whole / 60, whole % 60]

## Visible subfolders, then videos, each in natural order ("Episode 2" before "Episode 10").
func list(folder: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(folder)
	if directory == null: return result
	var natural := func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0
	var folders := Array(directory.get_directories())
	folders.sort_custom(natural)
	for name in folders:
		if not str(name).begins_with(".") and not str(name).begins_with("$"):
			result.append({"path": folder.path_join(name), "label": name, "folder": true})
	var files := Array(directory.get_files()).filter(is_video)
	files.sort_custom(natural)
	for name in files:
		result.append({"path": folder.path_join(name), "label": str(name).get_basename(), "folder": false})
	return result

## Videos in the folder and its subfolders, for the library card; capped so a
## huge drive never stalls the menu. Cached until refresh().
func count(folder: String) -> int:
	if not counts.has(folder): counts[folder] = _count(folder, 0, 0)
	return counts[folder]

func _count(folder: String, depth: int, found: int) -> int:
	var directory := DirAccess.open(folder)
	if directory == null or depth > 3: return found
	found += Array(directory.get_files()).filter(is_video).size()
	for name in directory.get_directories():
		if found >= COUNT_LIMIT: break
		if not str(name).begins_with("."): found = _count(folder.path_join(name), depth + 1, found)
	return mini(found, COUNT_LIMIT)

func refresh() -> void:
	counts.clear()
	durations.clear()

## Videos anywhere under `folder` whose names contain `query`, in natural order.
func search(folder: String, query: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	_search(folder, query.to_lower(), 0, found)
	found.sort_custom(func(a, b): return str(a.label).naturalnocasecmp_to(str(b.label)) < 0)
	return found

func _search(folder: String, query: String, depth: int, found: Array[Dictionary]) -> void:
	if depth > 4 or found.size() >= SEARCH_LIMIT: return
	for item in list(folder):
		if found.size() >= SEARCH_LIMIT: return
		if item.folder: _search(item.path, query, depth + 1, found)
		elif str(item.label).to_lower().contains(query): found.append(item)

## A small picture from about a tenth of the way in, made once and cached. Null
## until it is ready; thumbnail_ready announces it.
func thumbnail(path: String) -> Texture2D:
	if thumbnails.has(path): return thumbnails[path]
	var cached := ProjectSettings.globalize_path(THUMBNAILS).path_join(key(path) + ".png")
	if FileAccess.file_exists(cached):
		var image := Image.load_from_file(cached)
		thumbnails[path] = ImageTexture.create_from_image(image) if image != null else null
		return thumbnails[path]
	thumbnails[path] = null
	thumbnail_queue.append(path)
	_next_thumbnail()
	return null

func _next_thumbnail() -> void:
	if thumbnail_queue.is_empty() or (thumbnail_thread != null and thumbnail_thread.is_alive()): return
	if thumbnail_thread != null: thumbnail_thread.wait_to_finish()
	thumbnail_thread = Thread.new()
	thumbnail_thread.start(_make_thumbnail.bind(thumbnail_queue.pop_front()))

## Runs on the thumbnail thread: decode one frame, shrink it, cache it.
func _make_thumbnail(path: String) -> void:
	var image: Image = null
	if ClassDB.class_exists("VideoDecoder"):
		var decoder = ClassDB.instantiate("VideoDecoder")
		var details: Dictionary = decoder.open(ProjectSettings.globalize_path(path), 240, 2, false)
		if not details.is_empty():
			var length := float(details.duration)
			if length > 2.0: decoder.seek(minf(length * 0.1, 120.0))
			var started := Time.get_ticks_msec()
			while Time.get_ticks_msec() - started < 4000 and not decoder.update(1.0e9): OS.delay_msec(5)
			var bytes: PackedByteArray = decoder.frame()
			if bytes.size() == int(details.width) * int(details.height) * 4:
				image = Image.create_from_data(int(details.width), int(details.height), false, Image.FORMAT_RGBA8, bytes)
				image.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_BILINEAR)
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THUMBNAILS))
				image.save_png(ProjectSettings.globalize_path(THUMBNAILS).path_join(key(path) + ".png"))
		decoder.close()
	_thumbnail_done.call_deferred(path, image)

func _thumbnail_done(path: String, image: Image) -> void:
	var texture: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	thumbnails[path] = texture
	thumbnail_ready.emit(path, texture)
	_next_thumbnail()

## Waits for the thumbnail thread, so nothing runs after the scene is gone.
func stop_thumbnails() -> void:
	thumbnail_queue.clear()
	if thumbnail_thread != null: thumbnail_thread.wait_to_finish()

func duration(path: String) -> float:
	if not durations.has(path):
		durations[path] = float(ClassDB.class_call_static("VideoDecoder", "probe_duration", ProjectSettings.globalize_path(path))) if ClassDB.class_exists("VideoDecoder") else -1.0
	return durations[path]

## Resume points follow the file itself: a moved or replaced file starts fresh.
static func key(path: String) -> String:
	var size := FileAccess.get_size(path) if FileAccess.file_exists(path) else 0
	return ("%s|%d|%d" % [path, size, FileAccess.get_modified_time(path)]).md5_text()

func position(path: String) -> float:
	return float(resume.get_value(key(path), "position", 0.0))

func style(path: String) -> int:
	return int(resume.get_value(key(path), "style", -1))

func remember(path: String, seconds: float, length: float, display_style: int) -> Error:
	var section := key(path)
	resume.set_value(section, "file", path.get_file())
	resume.set_value(section, "path", path)
	resume.set_value(section, "watched", int(Time.get_unix_time_from_system()))
	resume.set_value(section, "style", display_style)
	if seconds >= RESUME_MIN_SECONDS and (length <= 0.0 or seconds <= length - RESUME_END_SECONDS):
		resume.set_value(section, "position", snappedf(seconds, 0.1))
	elif resume.has_section_key(section, "position"):
		resume.erase_section_key(section, "position")
	return SettingsStore.write(resume_path, resume)

## Videos left part-way through, most recently watched first. Only files still
## present and unchanged qualify (the key covers size and modification time).
func continue_watching(limit := 5) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for section in resume.get_sections():
		var file := str(resume.get_value(section, "path", ""))
		if file.is_empty() or not resume.has_section_key(section, "position") or not FileAccess.file_exists(file) or key(file) != section: continue
		found.append({"path": file, "position": float(resume.get_value(section, "position")), "watched": int(resume.get_value(section, "watched", 0))})
	found.sort_custom(func(a, b): return a.watched > b.watched)
	return found.slice(0, limit)

## The subtitle choice remembered for a file: an option name, "" for off, or
## null when nothing has been chosen yet.
func subtitle(path: String) -> Variant:
	# A null default counts as none, so ask first rather than log an error.
	return resume.get_value(key(path), "subtitle") if resume.has_section_key(key(path), "subtitle") else null

func set_subtitle(path: String, name: String) -> Error:
	resume.set_value(key(path), "subtitle", name)
	return SettingsStore.write(resume_path, resume)

## Subtitle files beside a video: Film.srt, Film.en.srt, Film.English.srt.
static func subtitle_files(path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var stem := path.get_file().get_basename()
	for name in DirAccess.get_files_at(path.get_base_dir()):
		if name.get_extension().to_lower() == "srt" and (name.get_basename() == stem or name.begins_with(stem + ".")):
			found.append(path.get_base_dir().path_join(name))
	found.sort()
	return found

static func srt_time(text: String) -> float:
	var parts := text.strip_edges().replace(".", ",").split(":")
	if parts.size() != 3: return -1.0
	return int(parts[0]) * 3600.0 + int(parts[1]) * 60.0 + float(parts[2].replace(",", "."))

## SubRip cues as {start, end, text}, with <i>/<b>/<font> and {\an8} styling removed.
static func parse_srt(source: String) -> Array:
	var cues: Array = []
	var tags := RegEx.create_from_string("<[^>]*>|\\{\\\\[^}]*\\}")
	for block in source.replace("\r\n", "\n").replace("\r", "\n").split("\n\n", false):
		var lines := block.strip_edges().split("\n")
		var timing := -1
		for i in range(lines.size()):
			if lines[i].contains("-->"): timing = i; break
		if timing < 0: continue
		var start := srt_time(lines[timing].get_slice("-->", 0))
		var end := srt_time(lines[timing].get_slice("-->", 1).strip_edges().get_slice(" ", 0))
		if start < 0.0 or end <= start: continue
		var text := "\n".join(lines.slice(timing + 1))
		cues.append({"start": start, "end": end, "text": tags.sub(text, "", true).strip_edges()})
	return cues
