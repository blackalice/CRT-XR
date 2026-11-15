extends SceneTree
## Y takes a video off Continue watching; it then starts from the beginning.
const VideoLibrary = preload("res://scripts/video/video_library.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	var folder := ProjectSettings.globalize_path("user://cw")
	DirAccess.make_dir_recursive_absolute(folder)
	var video := folder.path_join("Episode.mkv")
	var f := FileAccess.open(video, FileAccess.WRITE); f.store_string("x"); f.close()
	var library = VideoLibrary.new("user://cw-resume.cfg")
	library.remember(video, 300.0, 1500.0, 2)
	check(library.continue_watching().size() == 1, "A video watched part-way is on Continue watching")
	check(library.forget_position(video) == OK and library.continue_watching().is_empty(), "Removing it takes it off the list")
	check(library.position(video) == 0.0 and library.style(video) == 2, "It starts from the beginning; its picture shape is kept")
	var reloaded = VideoLibrary.new("user://cw-resume.cfg")
	check(reloaded.continue_watching().is_empty(), "The removal is saved")
	print("CONTINUE WATCHING: %d failures" % failures)
	quit(1 if failures else 0)
