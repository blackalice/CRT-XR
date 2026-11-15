extends SceneTree
## The demo shelf: shown only with an empty library, read from its own folder,
## never mixed into Recent.
const DemoShelf = preload("res://scripts/content/demo_shelf.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(text); f.close()
func run():
	var root := ProjectSettings.globalize_path("user://demo-test")
	check(DemoShelf.games(root).is_empty() and not DemoShelf.visible(0, root), "No demo folder, no shelf")
	write(root.path_join("nes/Free Game.nes"), "NES")
	write(root.path_join("demo.json"), JSON.stringify({"games": [
		{"system": "nes", "file": "nes/Free Game.nes", "title": "Free Game", "author": "A. Maker", "licence": "CC BY 4.0"},
		{"system": "nes", "file": "nes/Missing.nes", "title": "Missing"},
		{"system": "nes", "file": "../outside.nes", "title": "Escape"},
		{"system": "toaster", "file": "nes/Free Game.nes", "title": "Unknown console"}]}))
	var games := DemoShelf.games(root)
	check(games.size() == 1 and games[0].title == "Free Game", "Only present games on known consoles, inside the demo folder, are listed")
	check(DemoShelf.credit(games[0]) == "By A. Maker · CC BY 4.0", "Each demo credits its author and licence")
	check(DemoShelf.visible(0, root) and not DemoShelf.visible(12, root), "The shelf shows only while your own library is empty")
	check(DemoShelf.is_demo(games[0].path, root) and not DemoShelf.is_demo("/home/deck/roms/nes/Free Game.nes", root), "Demo games are told apart from yours")
	print("DEMO SHELF: %d failures" % failures)
	quit(1 if failures else 0)
