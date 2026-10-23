extends SceneTree
var app
func _initialize(): call_deferred("run")
func capture(label: String):
	for i in range(5): await process_frame
	RenderingServer.force_draw(false)
	# Inspect only the shared 2D menu; exclude the licensed cabinet and scene.
	app.menu_view.get_texture().get_image().save_png("res://build/menu-review/qol-"+label+".png")
func run():
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.use_tracking(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/menu-review"))
	app.play_history.recent.assign(["/SD/roms/snes/Super long descriptive game title (Europe) (Rev 1).sfc","/SD/roms/nes/Example Adventure.nes"])
	app.play_history.favourites.assign([app.play_history.recent[0]])
	app.menu.games.open_library(); await capture("library")
	app.menu.games.open_history("recent"); await capture("recent")
	app.menu.games.open_history("favourites"); await capture("favourites")
	app.menu.games.launch_path=app.play_history.recent[0]; app.menu.mode="launch"; app.menu.render()
	await capture("continue")
	app.menu.ask("Load manual save?","Current progress will be replaced. Example Adventure • Slot 0 • 2026-10-15 18:00:00 UTC",func():pass)
	await capture("load-confirmation")
	app.free(); quit()
