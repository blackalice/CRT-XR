extends SceneTree
var app
func _initialize(): call_deferred("run")
func capture(name: String):
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	# Only the shared 2D menu viewport is captured and inspected.
	app.menu_view.get_texture().get_image().save_png("res://build/menu-review/library-"+name+".png")
func run():
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); app.use_tracking(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/menu-review"))
	app.default_rom_dir="/SD/Emulation/roms"
	app.play_history.recent.assign(["/SD/Emulation/roms/snes/Star Runner.sfc","/SD/Emulation/roms/nes/Moon Garden.nes"])
	app.play_history.favourites.assign([app.play_history.recent[0]])
	app.menu.open_library(); app.menu.rom_index.cancel(); app.menu.rom_index.message=""
	for system in app.emulator.Registry.SYSTEMS:
		var games: Array=[]
		for i in range({"snes":24,"nes":17,"megadrive":42,"mastersystem":9,"gamegear":6}[system]):
			games.append({"path":"/SD/Emulation/roms/"+system+"/Star Runner %02d." % i+app.emulator.Registry.SYSTEMS[system].extensions[0],"label":"Star Runner %02d" % i})
		app.menu.rom_index.games[system]=games
	app.menu.render(); app.menu.select("library.system.snes"); await capture("home")
	app.menu.select("library.system.gamegear"); await capture("lower-shelf")
	app.menu.open_system("snes"); await capture("games")
	app.menu.back(); app.menu.select("library.locations"); app.menu.activate(); await capture("locations")
	app.menu.back(); app.menu.rom_index.games.clear(); app.menu.rom_index.message="ROM folder unavailable. Reconnect its SD card or choose another library folder."; app.menu.render(); await capture("missing-card")
	app.free(); quit()
