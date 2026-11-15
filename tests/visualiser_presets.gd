extends SceneTree
## Your own projectM presets join the bundled three.
const Session = preload("res://scripts/audio/visualizer_session.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	var v = Session.new()
	check(v.preset_names() == Session.PRESETS, "Without a presets folder, the three bundled presets")
	var folder := ProjectSettings.globalize_path(Session.USER_FOLDER)
	DirAccess.make_dir_recursive_absolute(folder)
	for name in ["Zebra.milk", "aurora.milk", "notes.txt"]:
		var f := FileAccess.open(folder.path_join(name), FileAccess.WRITE); f.store_string("[preset00]\n// " + name); f.close()
	v.scanned_at = -100000
	var names: Array = v.preset_names()
	check(names.size() == 5 and names[3] == "aurora" and names[4] == "Zebra", "Your .milk files follow the bundled ones, by name: %s" % [names])
	v.preset_index = 4
	check(v.preset_data().contains("Zebra.milk"), "A preset of yours is loaded from its file")
	v.preset_index = 0
	check(v.preset_data().begins_with("[preset00]") or not v.preset_data().is_empty(), "Bundled presets still load")
	check(Session.preset_folders("/music").has("/music/Visualiser presets"), "A Visualiser presets folder in your music folder is read too")
	v.free()
	print("VISUALISER PRESETS: %d failures" % failures)
	quit(1 if failures else 0)
