extends SceneTree
class ClockCore extends RefCounted:
 func info(): return {"fps":59.9453,"width":1,"height":1,"video_changed":true}
 func frame(): return PackedByteArray([0,0,0,255])
func _initialize():
 var session = load("res://scripts/emulation/emulation_session.gd").new()
 session.core = ClockCore.new()
 session.fps = 59.827
 session.update_texture(true)
 var ok := is_equal_approx(session.fps,59.9453)
 print("Live core refresh rate follows post-boot timing: ",ok)
 session.core = null
 session.free()
 quit(0 if ok else 1)
