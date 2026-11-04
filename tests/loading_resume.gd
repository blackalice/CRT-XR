extends SceneTree
## Continue restores the resume point behind the loading card. The game is then
## mid-play: its next picture takes the card down, dark or not, without the
## fresh-boot hold (which covers a disc's boot and shader compiles).
var failures := 0
func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var black := Image.create(256, 224, false, Image.FORMAT_RGBA8)
	app.show_loading("Disc.iso")
	app.loading_hold = 3000
	check(not app.picture_started(black), "A fresh boot keeps the card up through its hold")
	app.loading_started -= 3001
	check(not app.picture_started(black), "After the hold a fresh boot still waits for a picture")
	app.resume_ready("Disc.iso")
	check(app.loading_hold == 0 and app.picture_started(black), "A restored game's next picture shows at once, even a dark one")
	check(not app.picture_started(Image.new()), "An empty frame does not count")
	app.end_loading()
	check(not app.loading_resumed, "Taking the card down clears the resume state")
	app.show_loading("Disc.iso")
	app.resume_ready("Another.iso")
	check(not app.loading_resumed, "Another game's resume cannot release this card")
	app.show_loading("Next.iso")
	check(not app.loading_resumed, "A new card starts without the previous game's resume")
	app.end_loading()
	app.game_fps_visible = true
	app.update_game_fps(0)
	check(not app.game_fps_labels[0].visible, "The game frame rate stays hidden without a game")
	app.queue_free()
	await process_frame
	print("LOADING RESUME CHECKS COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
