extends Node
## Opt-in picture recorder for diagnosing glitches no trace can show: active
## only when user://frame-record.on exists at startup. Keeps every game picture
## of the last few seconds, exactly as the core delivered it (before the CRT
## processing), and when the game is paused writes them as numbered PNGs to
## user://traces/frames-<time>/, so a glitch is caught by pausing right after it.
## Memory: SECONDS × 60 pictures of the core's size (about 400 MB at 640×448).
const FLAG := "user://frame-record.on"
const SECONDS := 6
var app: Node
var ring: Array = []
var stamps := PackedInt64Array()
var next := 0
var count := 0
var was_paused := false
var task := -1

static func requested() -> bool:
	return FileAccess.file_exists(FLAG)

func start(host: Node) -> void:
	app = host
	ring.resize(SECONDS * 60)
	stamps.resize(SECONDS * 60)
	app.emulator.frame_presented.connect(_frame)
	print("Frame recorder: last %d s, saved on pause" % SECONDS)

func _frame(image: Image) -> void:
	if task >= 0: return # saving: the ring is being read
	# The session refills one Image each frame, so keep a copy.
	ring[next] = [image.get_width(), image.get_height(), image.get_data()]
	stamps[next] = Time.get_ticks_usec()
	next = (next + 1) % ring.size()
	count = mini(count + 1, ring.size())

func _process(_delta: float) -> void:
	if task >= 0 and WorkerThreadPool.is_task_completed(task):
		WorkerThreadPool.wait_for_task_completion(task)
		task = -1
		count = 0
		print("Frame recorder: saved")
	var paused: bool = app.emulator.loaded and app.emulator.paused
	if paused and not was_paused and count > 0 and task < 0:
		var stamp := Time.get_datetime_string_from_system(true).replace(":", "-")
		var folder := ProjectSettings.globalize_path("user://traces/frames-%s" % stamp)
		DirAccess.make_dir_recursive_absolute(folder)
		var order: Array = []
		for i in count: order.append((next - count + i + ring.size()) % ring.size())
		task = WorkerThreadPool.add_task(save.bind(folder, ring, stamps, order))
		print("Frame recorder: saving %d pictures to %s" % [count, folder])
	was_paused = paused

## Names carry the picture's ticks_usec, matching the live trace's "t".
static func save(folder: String, pictures: Array, times: PackedInt64Array, order: Array) -> void:
	for n in order.size():
		var entry: Array = pictures[order[n]]
		var image := Image.create_from_data(entry[0], entry[1], false, Image.FORMAT_RGBA8, entry[2])
		image.save_png(folder.path_join("%04d-%d.png" % [n, times[order[n]]]))

func _exit_tree() -> void:
	if task >= 0: WorkerThreadPool.wait_for_task_completion(task)
	task = -1
