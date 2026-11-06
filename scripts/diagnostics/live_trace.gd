extends Node
## Opt-in timing trace of real play: active only when user://frame-trace.on
## exists at startup (created for a diagnosis session; ordinary launches never
## trace). Records every room frame's interval and draw time, the emulator's
## per-frame metrics, and once a second what is on screen. Lines are buffered
## and appended to user://traces/<start time>.jsonl by a worker task every few
## seconds, so file writes never block a room frame.
const FLAG := "user://frame-trace.on"
const FLUSH_SECONDS := 5.0
var app: Node
var path := ""
var lines := PackedStringArray()
var last_tick := 0
var last_draw := 0
var flush_elapsed := 0.0
var context_elapsed := 0.0
var task := -1

static func requested() -> bool:
	return FileAccess.file_exists(FLAG)

func start(host: Node) -> void:
	app = host
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://traces"))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	path = ProjectSettings.globalize_path("user://traces/%s.jsonl" % stamp)
	app.emulator.profile_frames = true
	app.emulator.frame_profiled.connect(_emulation)
	RenderingServer.frame_post_draw.connect(_drawn)
	add("start", {"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"refresh": DisplayServer.screen_get_refresh_rate(), "window": str(DisplayServer.window_get_size())})
	print("Live frame trace: ", path)

func add(kind: String, data: Dictionary) -> void:
	data["k"] = kind
	data["t"] = Time.get_ticks_usec()
	lines.append(JSON.stringify(data))

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if last_tick > 0: lines.append('{"k":"tick","t":%d,"gap":%d}' % [now, now - last_tick])
	last_tick = now
	context_elapsed += delta
	if context_elapsed >= 1.0:
		context_elapsed = 0.0
		var emulator: Node = app.emulator
		var context: Dictionary={"game": emulator.rom_path.get_file() if emulator.loaded else "",
			"system": emulator.system_id if emulator.loaded else "", "paused": emulator.paused,
			"menu": app.settings_panel != null and app.settings_panel.visible, "card": not app.loading_path.is_empty(),
			"stereo": app.stereo, "room_fps": Engine.get_frames_per_second(), "game_fps": emulator.game_fps,
			"target_fps": emulator.fps, "refresh": DisplayServer.screen_get_refresh_rate()}
		context.merge(app.display_runtime_report(),true)
		add("context",context)
	flush_elapsed += delta
	if flush_elapsed >= FLUSH_SECONDS:
		flush_elapsed = 0.0
		flush()

func _drawn() -> void:
	var now := Time.get_ticks_usec()
	if last_draw > 0: lines.append('{"k":"draw","t":%d,"gap":%d}' % [now, now - last_draw])
	last_draw = now

func _emulation(metrics: Dictionary) -> void:
	var cores := PackedInt32Array()
	for step in metrics.get("steps", []): cores.append(int(step.get("core_us", 0)))
	add("emu", {"mode": metrics.get("mode", ""), "shown": metrics.get("shown", false),
		"dropped": metrics.get("dropped", 0), "steps": cores, "ages": metrics.get("picture_ages_us", PackedInt32Array()),
		"queued": metrics.get("audio_queued", 0), "reserve": metrics.get("reserve", 0),
		"recoveries": metrics.get("audio_recoveries", 0), "skips": metrics.get("audio_skips", 0),
		"process": metrics.get("process_us", 0), "fps": metrics.get("fps", 0.0)})

## Hands buffered lines to a worker. A write still running keeps the buffer
## for the next flush rather than waiting for it.
func flush() -> void:
	if lines.is_empty(): return
	if task >= 0:
		if not WorkerThreadPool.is_task_completed(task): return
		WorkerThreadPool.wait_for_task_completion(task)
		task = -1
	var batch := lines
	lines = PackedStringArray()
	task = WorkerThreadPool.add_task(write.bind(path, batch))

static func write(target: String, batch: PackedStringArray) -> void:
	var file := FileAccess.open(target, FileAccess.READ_WRITE) if FileAccess.file_exists(target) else FileAccess.open(target, FileAccess.WRITE)
	if file == null: return
	file.seek_end()
	file.store_string("\n".join(batch) + "\n")
	file.close()

func _exit_tree() -> void:
	if task >= 0: WorkerThreadPool.wait_for_task_completion(task)
	task = -1
	if not lines.is_empty(): write(path, lines)
	lines = PackedStringArray()
