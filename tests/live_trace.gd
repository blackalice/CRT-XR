extends SceneTree
## The opt-in play trace: off without its flag file; with it, room frames and
## context reach a JSONL file written off the room thread.
var failures := 0
func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")

func traces() -> PackedStringArray:
	return DirAccess.get_files_at("user://traces") if DirAccess.dir_exists_absolute("user://traces") else PackedStringArray()

func run() -> void:
	const LiveTrace = preload("res://scripts/diagnostics/live_trace.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LiveTrace.FLAG))
	for name in traces(): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://traces/" + name))
	check(not LiveTrace.requested(), "Ordinary launches do not trace")
	FileAccess.open(LiveTrace.FLAG, FileAccess.WRITE).close()
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(90): await process_frame
	await create_timer(1.2).timeout # context is recorded once a second
	var trace: Node = null
	for child in app.get_children():
		if child.get_script() == LiveTrace: trace = child
	check(trace != null, "The flag file starts a trace")
	if trace != null:
		var start := Time.get_ticks_msec()
		trace.flush()
		check(Time.get_ticks_msec() - start < 20, "Handing lines to the writer does not wait for the disk")
	app.queue_free()
	await process_frame
	await process_frame
	var files := traces()
	check(files.size() == 1, "One trace file per session")
	if files.size() == 1:
		var text := FileAccess.get_file_as_string("user://traces/" + files[0])
		check(text.contains('"k":"tick"') and text.contains('"k":"context"') and text.contains('"k":"start"'), "Room frames, context and the session start are recorded")
		var valid := true
		for line in text.split("\n", false): valid = valid and JSON.parse_string(line) != null
		check(valid, "Every line is JSON")
		var contexts: Array=[]
		for line in text.split("\n",false):
			var entry=JSON.parse_string(line)
			if entry is Dictionary and entry.get("k","")=="context":contexts.append(entry)
		check(contexts.any(func(entry):return entry.has("timestamp") and entry.has("draws") and entry.has("camera_degrees") and entry.has("tracking_status") and entry.has("msaa")),"Trace correlates drawing, tracking and AA with wall-clock time")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LiveTrace.FLAG))
	print("LIVE TRACE COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
