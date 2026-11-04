extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session = preload("res://scripts/emulation/emulation_session.gd").new()
	root.add_child(session)
	session.set_process(false)
	if not session.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")):
		print("FAIL diagnostic ROM"); quit(1); return
	var records: Array = []
	session.frame_profiled.connect(func(record): records.append(record))
	session.skip_delta = false
	session.profile_frames = true
	session._process(0.1)
	var ok: bool = records.size() == 1 and records[0].steps.size() >= 5
	if ok:
		for step in records[0].steps:
			ok = ok and step.wall_us >= step.core_us and step.core_us >= step.readback_us
		ok = ok and records[0].process_us >= records[0].present_us
	session.profile_frames = false
	session._process(0.1)
	ok = ok and records.size() == 1
	session.stop()
	print("%s complete catch-up-frame trace, disabled by default" % ["PASS" if ok else "FAIL"])
	quit(0 if ok else 1)
