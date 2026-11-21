extends SceneTree
## Saturday Morning TV: a daily running order and tuning in mid-programme.
const Channel = preload("res://scripts/video/tv_channel.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	var videos: Array[String] = []
	for i in range(8): videos.append("/v/show %d.mkv" % i)
	var monday := Channel.running_order(videos, "2026-11-16|/v")
	check(monday == Channel.running_order(videos, "2026-11-16|/v"), "A day's running order stays the same all day")
	check(monday != Channel.running_order(videos, "2026-11-17|/v") and monday.size() == 8, "The next day has another order of the same programmes")
	var half_hour := func(_path): return 1800.0
	check(Channel.position_at(videos, 0.0, half_hour) == [0, 0.0], "At 6 am the first programme starts")
	check(Channel.position_at(videos, 4500.0, half_hour) == [2, 900.0], "At 7:15 the third programme is a quarter of an hour in")
	check(Channel.position_at(videos, 8 * 1800.0 + 60.0, half_hour) == [0, 60.0], "After the last programme the channel loops")
	check(Channel.position_at(videos, 1600.0, func(_p): return -1.0) == [1, 100.0], "Unknown lengths count as 25 minutes")
	check(is_equal_approx(Channel.seconds_since_start({"hour": 6, "minute": 30, "second": 0}), 1800.0), "6:30 is half an hour into the broadcast")
	check(is_equal_approx(Channel.seconds_since_start({"hour": 2, "minute": 0, "second": 0}), 20.0 * 3600.0), "2 am is late in the previous day's broadcast")
	var folder := ProjectSettings.globalize_path("user://channel-videos")
	DirAccess.make_dir_recursive_absolute(folder.path_join("Cartoons"))
	for name in ["b.mp4", "a.mkv", "notes.txt", "Cartoons/c.m4v"]:
		var f := FileAccess.open(folder.path_join(name), FileAccess.WRITE); f.store_string("x"); f.close()
	var found := Channel.collect(folder)
	check(found.size() == 3 and found[0].ends_with("a.mkv") and found[2].ends_with("Cartoons/c.m4v"), "Videos in the folder and its subfolders are on the channel: %s" % [found])
	print("TV CHANNEL: %d failures" % failures)
	quit(1 if failures else 0)
