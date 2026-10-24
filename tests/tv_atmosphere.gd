extends SceneTree
## Atmosphere: the playing game's cover on the table box, the channel change,
## degauss and power-off on the tube, room sound, the time-of-day room and the
## bloom around the tube in the dark.
## With a screen (not --headless) it also saves pictures to build/tv-atmosphere.
const World = preload("res://scripts/rendering/crt_world.gd")
var failures := 0
var app

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func settle(frames := 6) -> void:
	for i in range(frames): await process_frame

func capture(title: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle(4)
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/tv-atmosphere"))
	root.get_texture().get_image().save_png("res://build/tv-atmosphere/" + title + ".png")

## A cover whose orientation can be read: red top, blue bottom, green left edge.
func cover_picture(path: String, size: Vector2i) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(Color("e8d8b0"))
	image.fill_rect(Rect2i(0, 0, size.x, size.y / 4), Color("c0392b"))
	image.fill_rect(Rect2i(0, size.y * 3 / 4, size.x, size.y / 4), Color("2c5fb8"))
	image.fill_rect(Rect2i(0, 0, size.x / 8, size.y), Color("27ae60"))
	image.save_png(path)

func run() -> void:
	var base := ProjectSettings.globalize_path("user://atmosphere-test/Emulation")
	var roms := base.path_join("roms")
	var probe := FileAccess.get_file_as_bytes("res://build/crt-xr-probe.sfc")
	for game in ["snes/Covered Game.sfc", "snes/Screenshot Only.sfc"]:
		DirAccess.make_dir_recursive_absolute(roms.path_join(game).get_base_dir())
		var file := FileAccess.open(roms.path_join(game), FileAccess.WRITE); file.store_buffer(probe); file.close()
	cover_picture(base.path_join("tools/downloaded_media/snes/covers/Covered Game.png"), Vector2i(600, 840))
	cover_picture(base.path_join("tools/downloaded_media/snes/screenshots/Screenshot Only.png"), Vector2i(640, 480))

	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	await settle()
	app.default_rom_dir = roms
	app.box_art.set_root(roms)
	var world = app.world
	var boxes: ShaderMaterial = world.game_boxes.material_override

	# 1. The playing game's cover on the top box.
	check(app.box_art.find(roms.path_join("snes/Screenshot Only.sfc"), app.box_art.COVER_TYPES, app.box_art.COVER_BESIDE).is_empty(), "A screenshot is never printed on the box")
	check(not app.box_art.find(roms.path_join("snes/Screenshot Only.sfc")).is_empty(), "The menu still shows the screenshot")
	check(app.load_game(roms.path_join("snes/Covered Game.sfc")), "A game with a scraped cover loads")
	for i in range(120):
		if boxes.get_shader_parameter("game_cover_on"): break
		await process_frame
	check(boxes.get_shader_parameter("game_cover_on") == true, "Its cover is printed on the top box")
	var cover: Texture2D = boxes.get_shader_parameter("game_cover")
	check(cover != null and cover.get_height() == app.box_art.COVER_HEIGHT, "The table cover loads larger than the menu's art")
	check(absf(float(boxes.get_shader_parameter("game_cover_aspect")) - 600.0 / 840.0) < 0.01, "A portrait cover is known to be portrait, so it lies turned")
	var tint: Color = boxes.get_shader_parameter("game_cover_tint")
	check(tint.r > 0.4 and tint.r < 0.9, "The box's spine takes the cover's average colour")
	app.close_settings()
	await capture("cover-on-box")
	world.show_game_cover = false; world.apply_room_settings()
	check(boxes.get_shader_parameter("game_cover_on") == false, "Switching the cover off brings back the box's own print")
	world.show_game_cover = true; world.apply_room_settings()
	check(app.load_game(roms.path_join("snes/Screenshot Only.sfc")) and boxes.get_shader_parameter("game_cover_on") == false, "A game without a cover leaves the box's own print")

	# 2-3. Channel change, degauss and power-off on the tube.
	var effects = app.tv_effects
	var screen: ShaderMaterial = world.screen_material
	check(effects.play("channel") and float(screen.get_shader_parameter("channel_static")) > 0.9, "A channel change starts on static")
	check(float(screen.get_shader_parameter("picture_roll")) > 0.3, "The picture rolls as it settles")
	effects.set_process(false); effects._process(0.25)
	await capture("channel-change")
	effects._process(0.25)
	check(float(screen.get_shader_parameter("channel_static")) == 0.0 and float(screen.get_shader_parameter("picture_roll")) == 0.0 and not effects.is_processing(), "The channel change clears in under half a second")
	effects.channel_change = false
	check(not effects.play("channel"), "The channel change can be switched off")
	effects.channel_change = true
	app.toggle_settings(); app.degauss()
	check(not app.settings_panel.visible and effects.effect == "degauss" and float(screen.get_shader_parameter("degauss")) > 0.9, "Degauss closes the menu and starts on the picture")
	effects.set_process(false); effects._process(0.3)
	await capture("degauss")
	effects._process(2.0)
	check(float(screen.get_shader_parameter("degauss")) == 0.0, "The degauss fades out completely")
	effects.reduced_motion = true; effects.play("degauss")
	check(screen.get_shader_parameter("degauss_wobble") == false and float(screen.get_shader_parameter("degauss")) <= 0.5, "Reduced motion keeps the colour, without the wobble")
	effects.clear(); effects.reduced_motion = false
	if DisplayServer.get_name() == "headless":
		check(not effects.play("power_off"), "Without a screen, closing skips the power-off")
	else:
		check(effects.play("power_off"), "The power-off plays as CRT XR closes")
		effects.set_process(false)
		for step in [0.2, 0.45, 0.66, 0.72]:
			effects.elapsed = 0.0; effects._process(step * 0.75)
			await capture("power-off-%d" % int(step * 100))
		effects.clear()

	# 4. Room sound.
	check(world.room_sound.ambience == 0 and not world.crt_whine, "Room sound and the tube whine are off by default")
	world.ambience = 3; world.ambience_level = 0.3; world.crt_whine = true; world.apply_room_settings()
	check(world.room_sound.ambience == 3 and is_equal_approx(world.room_sound.level, 0.3) and world.room_sound.whine, "Room sound follows the room settings")
	check(world.room_sound.bed.playing == (DisplayServer.get_name() != "headless"), "The rain plays when there is sound to hear")

	# 5. Time of day.
	var noon: Array = World.time_of_day(13.0)
	var small_hours: Array = World.time_of_day(3.0)
	var evening: Array = World.time_of_day(20.0)
	check(noon[0] > evening[0] and evening[0] > small_hours[0], "Brighter by day than in the evening, dimmest in the small hours")
	check(noon[2] < 0.0 and evening[2] > 0.0, "Cooler by day, warmer in the evening")
	check(is_equal_approx(World.time_of_day(0.0)[0], World.time_of_day(24.0)[0]), "Midnight is the same either side")
	world.follow_clock = false; world.apply_room_settings()
	check(is_equal_approx(world.screen_light.room_energy, world.ambient), "Off, the room uses your lighting exactly")
	world.follow_clock = true; world.apply_room_settings()
	var now := Time.get_time_dict_from_system()
	var mood: Array = World.time_of_day(float(now.hour) + float(now.minute) / 60.0)
	check(is_equal_approx(world.screen_light.room_energy, world.ambient * mood[0]), "On, the room shifts around your lighting by the hour")

	world.follow_clock = false

	# 6. Bloom around the tube, only in a dark room.
	var light = world.screen_light
	app.room_preset("dark")
	check(is_equal_approx(light.bloom, world.screen_bloom) and light.halo != null, "Lights off shows the full bloom")
	app.room_preset("bright")
	check(light.bloom == 0.0, "A lit room has no bloom")
	app.room_preset("late")
	check(light.bloom > 0.4 * world.screen_bloom, "Late night keeps most of it")
	world.screen_bloom = 0.0; world.apply_room_settings()
	check(light.bloom == 0.0 and not light.halo.visible, "Bloom can be switched off")
	world.screen_bloom = 0.5; world.set_spill_strength(0.0); world.apply_room_settings()
	check(light.is_processing() and light.lights[0].light_energy == 0.0, "With the glow off the bloom still follows the picture")
	world.set_spill_strength(0.5)
	# The picture's bounce: a faint fill in its colour, on top of the room's own.
	var white := Image.create(64, 48, false, Image.FORMAT_RGB8); white.fill(Color.WHITE)
	light.set_image(white); light.power_level = 1.0 # the TV is on
	for i in range(30): light._process(1.0 / 30.0)
	check(world.room_environment.ambient_light_energy > light.room_energy + 0.1, "A bright picture adds its bounce to the room's ambient light")
	for part in ["LowerShelf", "VideoRecorder"]:
		var node: Node = world.television.find_child(part, true, false)
		check(node != null and not (node.layers & light.RECEIVER_LAYER), part + " under the tabletop is not lit through it")
	world.follow_clock = true

	# Settings round-trip, and they belong to the room (presets save them).
	world.show_game_cover = false; world.screen_bloom = 0.8
	var config: ConfigFile = app.capture_settings()
	world.screen_bloom = 0.5
	world.ambience = 0; world.ambience_level = 0.5; world.crt_whine = false; world.follow_clock = false; world.show_game_cover = true
	effects.channel_change = false; effects.power_off_effect = false
	app.apply_settings(config)
	check(world.ambience == 3 and is_equal_approx(world.ambience_level, 0.3) and world.crt_whine and world.follow_clock and not world.show_game_cover, "Room sound, whine, time of day and the cover setting are saved")
	check(is_equal_approx(world.screen_bloom, 0.8), "Screen bloom is saved")
	check(effects.channel_change and effects.power_off_effect, "The channel change and power-off settings are saved")
	check(app.rooms.room_only().get_value("room", "ambience") == 3, "Room presets include the room sound")
	# A long game title with the battery beside it must not widen the menu.
	app.menu.heading.text = "Donkey Kong Country (Europe) (En,Fr,De) (Rev 1) - an even longer title"
	app.menu.status_line.label.text = "76% · 14:04"
	var header: Control = app.menu.heading.get_parent()
	check(header.get_combined_minimum_size().x <= app.menu.size.x, "A long title shortens instead of widening the menu")
	app.menu.open_settings(); app.menu.category = 3
	var titles: Array = app.menu.catalog.pages(3).map(func(page): return page.title)
	check("Sound" in titles, "Room has a Sound page")
	app.free()
	await settle()
	print("TV ATMOSPHERE CHECKS COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
