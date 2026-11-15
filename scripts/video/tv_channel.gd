extends RefCounted
## Saturday Morning TV: your video folder as a channel that is always on.
##
## Each day has its own running order, a shuffle seeded by the date, and the
## broadcast starts at 06:00. Tuning in lands wherever that day's schedule has
## reached, mid-programme, like switching on a real TV. When a programme ends,
## the next follows after a channel change; Up and Down on the D-pad move to the
## next or previous programme. Watching anything else leaves the channel.
var host: Node
var active := false
var schedule: Array[String] = []
var index := 0
## Set while the channel itself starts a programme, so play_video keeps it on.
var switching := false
const BROADCAST_START_HOUR := 6
const MAX_FILES := 500
const MAX_DEPTH := 4
const EXTENSIONS := ["mp4", "m4v", "mkv"]

## Every video in the folder and its subfolders (up to MAX_FILES), sorted.
static func collect(folder: String) -> Array[String]:
	var found: Array[String] = []
	_collect(folder, 0, found)
	return found

static func _collect(folder: String, depth: int, found: Array[String]) -> void:
	if depth > MAX_DEPTH or found.size() >= MAX_FILES or folder.is_empty(): return
	var directory := DirAccess.open(folder)
	if directory == null: return
	var files := Array(directory.get_files())
	files.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	for name in files:
		if str(name).get_extension().to_lower() in EXTENSIONS and found.size() < MAX_FILES: found.append(folder.path_join(name))
	var folders := Array(directory.get_directories())
	folders.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	for name in folders:
		if str(name).begins_with(".") or str(name).begins_with("$"): continue
		_collect(folder.path_join(name), depth + 1, found)

## The day's running order: the same all day, different tomorrow.
static func running_order(videos: Array[String], day: String) -> Array[String]:
	var order: Array[String] = videos.duplicate()
	var random := RandomNumberGenerator.new()
	random.seed = hash(day)
	for i in range(order.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var swap := order[i]; order[i] = order[j]; order[j] = swap
	return order

## Where the broadcast is `seconds_in` after it began: [index, offset seconds].
## `length` gives a programme's duration (≤ 0 when unknown: counted as 25 min).
static func position_at(order: Array[String], seconds_in: float, length: Callable) -> Array:
	if order.is_empty(): return [0, 0.0]
	var remaining := maxf(0.0, seconds_in)
	var total := 0.0
	# One pass to learn the loop's length, stopping as soon as we're inside it.
	for i in range(order.size()):
		var duration := float(length.call(order[i]))
		if duration <= 0.0: duration = 25.0 * 60.0
		if remaining < duration: return [i, remaining]
		remaining -= duration
		total += duration
	# Past the end of the list: the channel loops.
	remaining = fmod(maxf(0.0, seconds_in), total)
	for i in range(order.size()):
		var duration := float(length.call(order[i]))
		if duration <= 0.0: duration = 25.0 * 60.0
		if remaining < duration: return [i, remaining]
		remaining -= duration
	return [0, 0.0]

static func seconds_since_start(now: Dictionary) -> float:
	var seconds := float(int(now.hour) * 3600 + int(now.minute) * 60 + int(now.second))
	var start := float(BROADCAST_START_HOUR * 3600)
	return seconds - start if seconds >= start else seconds + 86400.0 - start

## Tunes in. Returns false (with a message on the host) when there is nothing to show.
func tune_in() -> bool:
	var videos := collect(host.video_dir)
	if videos.is_empty():
		host.show_notice("Saturday Morning TV needs videos in your video folder.")
		return false
	var now := Time.get_datetime_dict_from_system()
	# Before 06:00 it is still yesterday's broadcast.
	var day := Time.get_date_string_from_system()
	if int(now.hour) < BROADCAST_START_HOUR: day = Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	schedule = running_order(videos, day + "|" + str(host.video_dir))
	var where: Array = position_at(schedule, seconds_since_start(now), host.video_library.duration)
	index = int(where[0])
	active = true
	# A minute before the end would only show the credits: start the next one.
	var offset: float = where[1]
	var length: float = host.video_library.duration(schedule[index])
	if length > 0.0 and offset > length - 60.0:
		index = (index + 1) % schedule.size(); offset = 0.0
	return show(index, offset)

func show(at: int, offset := 0.0) -> bool:
	if schedule.is_empty(): return false
	index = posmod(at, schedule.size())
	switching = true
	var ok: bool = host.play_video(schedule[index], offset)
	switching = false
	if not ok:
		active = false
		return false
	host.tv_effects.play("channel")
	host.flash_video_bar("SATURDAY MORNING TV · " + schedule[index].get_file().get_basename())
	return true

## The programme finished: the next one follows.
func programme_ended() -> void:
	if active: show(index + 1, 0.0)

func next_programme(step: int) -> void:
	if active: show(index + step, 0.0)

## Anything else played leaves the channel.
func leave() -> void:
	if not switching: active = false
