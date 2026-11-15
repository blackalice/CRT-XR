extends SceneTree
## Rewind and fast-forward: who gets them, the state ring and its budget.
const Session = preload("res://scripts/emulation/emulation_session.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")

class FakeCore extends RefCounted:
	var frame := 0
	var size := 1000
	func save_state() -> PackedByteArray:
		var bytes := PackedByteArray(); bytes.resize(size); bytes.encode_u32(0, frame); return bytes
	func load_state(state: PackedByteArray) -> bool:
		frame = state.decode_u32(0); return true
	func run_frame(_buttons: int) -> bool:
		frame += 1; return true

func run():
	var session = Session.new()
	session.loaded = true; session.system_id = "snes"
	var fake := FakeCore.new()
	session.core = fake
	check(not session.speed_available(), "Off by default")
	session.rewind_enabled = true
	check(session.speed_available(), "On for SNES when turned on")
	session.system_id = "psx"
	check(not session.speed_available(), "Not for PlayStation, whose controls use the triggers")
	session.system_id = "n64"
	check(not session.speed_available(), "Not for streamed consoles")
	session.system_id = "snes"
	session.controls = {"buttons": {"r2": 11}}
	check(not session.speed_available() and session.triggers_bound(), "Not when this game's layout puts a button on a trigger")
	session.controls = {}
	for i in range(30):
		fake.frame += 1
		session.record_rewind()
	check(session.rewind_states.size() == 10, "A state is kept every %d frames" % Session.REWIND_EVERY)
	var newest: int = session.rewind_states[-1].decode_u32(0)
	fake.frame = 999
	var state: PackedByteArray = session.rewind_states.pop_back(); session.rewind_bytes -= state.size()
	fake.load_state(state)
	check(fake.frame == newest, "Rewinding restores the newest kept frame")
	# Budget: oldest states are dropped.
	session.clear_rewind()
	fake.size = 40 * 1024 * 1024
	for i in range(Session.REWIND_EVERY * 3): session.record_rewind()
	check(session.rewind_unsupported and session.rewind_states.is_empty(), "A state over the per-state limit turns rewind off for the game")
	session.rewind_unsupported = false
	fake.size = 3 * 1024 * 1024
	for i in range(Session.REWIND_EVERY * 40): fake.frame += 1; session.record_rewind()
	check(session.rewind_bytes <= Session.REWIND_BYTES and session.rewind_states.size() == Session.REWIND_BYTES / (3 * 1024 * 1024), "Memory stays within the rewind budget, oldest first out")
	session.clear_rewind()
	check(session.rewind_states.is_empty() and session.rewind_bytes == 0, "Clearing empties the ring")
	session.free()
	print("REWIND: %d failures" % failures)
	quit(1 if failures else 0)
