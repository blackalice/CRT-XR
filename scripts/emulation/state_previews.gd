extends Node
signal ready_for(path: String)
const Store = preload("res://scripts/emulation/state_store.gd")
var pending: Array[String] = []
var attempted := {}
var thread: Thread
var active := ""
var stamp: Array

func request(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path) or not Store.metadata(path).is_empty(): return
	if active == path or path in pending or attempted.get(path) == Store.fingerprint(path): return
	if pending.size() < 16: pending.append(path)

func _process(_delta: float) -> void:
	if thread != null:
		if thread.is_alive(): return
		thread.wait_to_finish()
		thread = null
		attempted[active] = stamp
		var finished := active
		active = ""
		ready_for.emit(finished)
	if pending.is_empty(): return
	active = pending.pop_front()
	stamp = Store.fingerprint(active)
	var path := active
	thread = Thread.new()
	if thread.start(func(): return Store.ensure_metadata(path)) != OK:
		attempted[active] = stamp
		active = ""
		thread = null

func _exit_tree() -> void:
	if thread != null and thread.is_started(): thread.wait_to_finish()
