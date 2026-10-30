extends SceneTree
## The loading card for disc games: choosing a zipped disc goes back to the room,
## the TV shows the spinning disc with unpack progress, the card stays through
## the console's black boot frames, and the game's picture replaces it once it
## shows something. Stopping the game takes the card down.
const Archive = preload("res://scripts/content/rom_archive.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")

func put(bytes: PackedByteArray, offset: int, text: String) -> void:
	var ascii := text.to_ascii_buffer()
	for i in ascii.size(): bytes[offset + i] = ascii[i]

## A tiny raw disc whose volume names PLAYSTATION; enough to be listed and unpacked.
func disc() -> PackedByteArray:
	var bytes := PackedByteArray(); bytes.resize(40 * 2352)
	var volume := 16 * 2352 + 24
	bytes[volume] = 1; put(bytes, volume + 1, "CD001"); put(bytes, volume + 8, "PLAYSTATION")
	return bytes

func run() -> void:
	var folder := ProjectSettings.globalize_path("user://disc-loading/psx")
	DirAccess.make_dir_recursive_absolute(folder)
	var zipped := folder.path_join("Spinner (USA).zip")
	var packer := ZIPPacker.new()
	packer.open(zipped)
	packer.start_file("Spinner (USA).cue"); packer.write_file('FILE "Spinner (USA).bin" BINARY\n  TRACK 01 MODE2/2352\n'.to_utf8_buffer()); packer.close_file()
	packer.start_file("Spinner (USA).bin"); packer.write_file(disc()); packer.close_file()
	packer.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Archive.CACHE).path_join(Archive.DISC_MARKER))

	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	await process_frame
	await process_frame
	app.menu_on_tv = false # the card and game take the tube; the menu floats over them
	if not app.menu.visible: app.toggle_settings()
	var progress := []
	app.emulator.unpack_progress.connect(func(_path, done, total): progress.append(float(done) / total))
	app.menu.games.launch_game(zipped, false)
	check(not app.menu.visible, "Choosing a zipped disc goes back to the room")
	check(app.loading_path == zipped and app.loading_screen.visible and not app.pattern.visible, "The TV shows the loading card, not the test signal")
	check(app.world.picture.source_texture == app.card_view.get_texture(), "The card is the picture on the tube")
	for i in range(600):
		if app.emulator.loaded or app.loading_path.is_empty(): break
		await process_frame
	check(not progress.is_empty() and is_equal_approx(progress.back(), 1.0), "Unpack progress reaches the card's bar")
	# A disc without a program is refused by the core; the card must not stay up.
	check(not app.emulator.loaded and app.loading_path.is_empty() and not app.loading_screen.visible, "A disc that fails to load takes the card down")
	# Holding and handing over do not depend on the console: a cartridge stands in
	# for a booting disc behind the card.
	app.show_loading(zipped)
	app.loading_game = true
	var started: bool = app.emulator.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc"))
	app.loading_game = false
	check(started and app.loading_path == zipped and app.loading_screen.progress < 0.0, "A game starts behind the card")
	var black := Image.create(256, 224, false, Image.FORMAT_RGBA8)
	app.emulator.frame_presented.emit(black)
	check(app.loading_screen.visible and app.world.picture.source_texture == app.card_view.get_texture(), "Black boot frames keep the card up")
	await create_timer(0.5).timeout
	check(app.world.picture.source_texture == app.card_view.get_texture() or app.loading_path.is_empty(), "The card stays the picture until the game shows something")
	var lit := Image.create(256, 224, false, Image.FORMAT_RGBA8)
	lit.fill(Color("4060c0"))
	app.emulator.frame_presented.emit(lit)
	check(app.loading_path.is_empty() and not app.loading_screen.visible, "A frame with picture takes the card down")
	check(app.world.picture.source_texture == app.emulator.texture, "The game's picture replaces the card")
	app.show_loading(zipped)
	app.emulator.stop()
	check(app.loading_path.is_empty() and app.pattern.visible, "Stopping the game takes the card down for the test signal")
	app.show_loading(zipped)
	app.loading_started -= app.LOADING_TIMEOUT_MSEC + 1
	check(app.picture_started(black), "A game still black after the timeout is shown anyway")
	app.end_loading()
	check(app.loading_screen.short_title("Final Fantasy VII (USA) (Disc 1)") == "Final Fantasy VII (Disc 1)", "The card keeps the disc number and drops the region")
	app.queue_free()
	await process_frame
	print("DISC LOADING CHECKS COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
