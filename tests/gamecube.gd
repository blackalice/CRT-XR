extends SceneTree
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Folders = preload("res://scripts/content/console_folders.gd")
const Layouts = preload("res://scripts/emulation/controller_layouts.gd")
const Options = preload("res://scripts/emulation/core_options.gd")
const Support = preload("res://scripts/emulation/dolphin_support.gd")
var failures := 0
var base := "user://fixtures/gamecube-" + str(Time.get_ticks_usec())

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)

func disc(container := "", wii := false) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(0xd8)
	var offset := 0
	if not container.is_empty():
		for index in range(3): bytes[index] = container.to_ascii_buffer()[index]
		bytes[3] = 1
		bytes[0x4b] = 2 if wii else 1
		offset = 0x58
	var magic := PackedByteArray([0x5d, 0x1c, 0x9e, 0xa3]) if wii else PackedByteArray([0xc2, 0x33, 0x9f, 0x3d])
	for index in range(4): bytes[offset + (0x18 if wii else 0x1c) + index] = magic[index]
	return bytes

func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not Folders.gamecube_enabled():
		check(not Registry.SYSTEMS.has("gamecube") and Folders.unsupported("gc"), "GameCube stays out of release discovery without the development opt-in")
		print("GameCube release gate: ", failures, " failures")
		quit(failures); return
	check(Registry.SYSTEMS.has("gamecube"), "Experimental GameCube registration")
	for alias in ["gc", "ngc", "Nintendo GameCube", "gamecube"]:
		check(Folders.system(alias) == "gamecube" and not Folders.unsupported(alias), "Folder alias: " + alias)
	for extension in ["iso", "gcm", "rvz", "wia"]:
		var container: String = extension.to_upper() if extension in ["rvz", "wia"] else ""
		var path := base.path_join("Disc." + extension)
		write(path, disc(container))
		check(Registry.identify(path) == "gamecube", "GameCube header detection: " + extension)
		write(base.path_join("Wii." + extension), disc(container, true))
		check(Registry.identify(base.path_join("Wii." + extension)).is_empty(), "Wii is excluded: " + extension)
	write(base.path_join("Broken.gcm"), PackedByteArray([1, 2, 3]))
	check(Registry.identify(base.path_join("Broken.gcm")).is_empty(), "Truncated images are excluded")
	write(base.path_join("Wrong.rvz"), disc())
	check(Registry.identify(base.path_join("Wrong.rvz")).is_empty(), "RVZ extension requires a container header")
	write(base.path_join("Game.m3u"), "Disc.iso\nDisc.rvz\nDisc.gcm\nDisc.wia\n".to_utf8_buffer())
	check(Registry.identify(base.path_join("Game.m3u")) == "gamecube", "Multidisc playlist identifies GameCube")
	write(base.path_join("Mixed.m3u"), "Disc.iso\nWii.iso\n".to_utf8_buffer())
	check(Registry.identify(base.path_join("Mixed.m3u")).is_empty(), "Mixed GameCube/Wii playlists are excluded")
	var index = load("res://scripts/content/rom_index.gd").new()
	index.start(ProjectSettings.globalize_path(base))
	while index.scanning: index.step(10000)
	check(index.games.gamecube.size() == 1 and index.games.gamecube[0].path.ends_with("Game.m3u"), "Library groups GameCube discs under one playlist")
	check(Registry.content_hash(base.path_join("Disc.gcm")) != Registry.content_hash(base.path_join("Broken.gcm")), "Disc hashes distinguish content")
	var layout := Layouts.standard("gamecube", Registry.SYSTEMS.gamecube)
	check(Layouts.valid(layout) and layout.buttons.south == Layouts.A and layout.buttons.west == Layouts.B and layout.buttons.r1 == Layouts.R, "Deck layout places A on bottom, B on left and Z on R1")
	check(layout.left_stick == "analog" and layout.right_stick == "analog" and layout.buttons.l2 == Layouts.L2, "Control stick, C-stick and analog triggers stay available")
	check(not Registry.SYSTEMS.gamecube.preview and Registry.SYSTEMS.gamecube.options.dolphin_efb_scale == "1", "Deck starts at native resolution without input preview")
	check(Options.definitions("gamecube").size() == 3, "GameCube options use the existing settings system")
	OS.set_environment("CRT_XR_DOLPHIN_SYS", ProjectSettings.globalize_path(base.path_join("Sys")))
	check(not Support.available(), "Missing Dolphin data is detected before boot")
	for name in Support.REQUIRED: write(base.path_join("Sys/" + name), "redistributable fixture".to_utf8_buffer())
	write(base.path_join("save/User/GC/card.raw"), "preserve save".to_utf8_buffer())
	check(Support.stage(ProjectSettings.globalize_path(base.path_join("save"))) == OK, "Dolphin data stages to the host system directory")
	check(FileAccess.file_exists(base.path_join("save/dolphin-emu/Sys/GC/dsp_rom.bin")), "Staged Sys layout matches Dolphin's expectations")
	check(FileAccess.get_file_as_string(base.path_join("save/User/GC/card.raw")) == "preserve save", "System data staging preserves memory cards")
	OS.set_environment("CRT_XR_DOLPHIN_SYS", "")
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.emulator.system_id = "gamecube"; app.emulator.loaded = true; app.emulator.rom_path = "fixture.iso"
	var pages: Array = app.menu.catalog.pages(10)
	check(pages[0].rows[0].id == "core.console.gamecube" and pages[0].rows[0].expanded, "Playing GameCube opens its existing console accordion")
	check(pages[1].rows.size() == 3 and pages[1].rows[0].section.contains("GameCube"), "Per-game settings keep the existing page layout")
	app.emulator.loaded = false
	app.queue_free()
	await process_frame
	print("GameCube foundation: ", failures, " failures")
	quit(1 if failures else 0)
