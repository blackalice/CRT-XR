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
	resume.set_value(section, "style", display_style)
	if seconds >= RESUME_MIN_SECONDS and (length <= 0.0 or seconds <= length - RESUME_END_SECONDS):
		resume.set_value(section, "position", snappedf(seconds, 0.1))
	elif resume.has_section_key(section, "position"):
		resume.erase_section_key(section, "position")
	return SettingsStore.write(resume_path, resume)
