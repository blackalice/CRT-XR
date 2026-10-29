extends SceneTree
## Games in ZIP archives and CHD discs: identification, scanning, playing from
## the unpacked cache, and saves shared with the same game unzipped.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Archive = preload("res://scripts/content/rom_archive.gd")
const RomIndex = preload("res://scripts/content/rom_index.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")

func pack(path: String, files: Dictionary) -> void:
	var packer := ZIPPacker.new()
	packer.open(ProjectSettings.globalize_path(path))
	for name in files:
		packer.start_file(name); packer.write_file(files[name]); packer.close_file()
	packer.close()

func touch(path: String, bytes := PackedByteArray([0, 1, 2, 3])) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_buffer(bytes); file.close()

func run() -> void:
	var base := "user://archives"
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base)): OS.move_to_trash(ProjectSettings.globalize_path(base))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base + "/roms/snes"))
	var snes := FileAccess.get_file_as_bytes("res://build/crt-xr-probe.sfc")
	var md := FileAccess.get_file_as_bytes("res://build/crt-xr-probe.md")
	var gba := FileAccess.get_file_as_bytes("res://build/crt-xr-probe.gba")
	pack(base + "/roms/snes/Probe (USA).zip", {"readme.txt": "Not a game".to_utf8_buffer(), "Probe (USA).sfc": snes})
	pack(base + "/roms/Sega Probe.zip", {"Sega Probe.bin": md})
	pack(base + "/roms/Advance.zip", {"Advance.gba": gba})
	pack(base + "/roms/notes.zip", {"notes.txt": "Nothing to play".to_utf8_buffer(), "manual.md": "# Manual".to_utf8_buffer()})
	var cd := PackedByteArray(); cd.resize(0x200)
	var tag := "SEGADISCSYSTEM".to_ascii_buffer()
	for i in tag.size(): cd[0x100 + i] = tag[i]
	pack(base + "/roms/Disc.zip", {"Disc.cue": "FILE \"Disc.bin\" BINARY".to_utf8_buffer(), "Disc.bin": cd})
	touch(base + "/roms/broken.zip", "PK not really a zip".to_utf8_buffer())
	# A ZIP comment moves the end record away from the last 22 bytes.
	pack(base + "/roms/Commented.zip", {"Commented.nes": FileAccess.get_file_as_bytes("res://build/crt-xr-probe.nes")})
	var commented := FileAccess.get_file_as_bytes(base + "/roms/Commented.zip")
	var comment := "Scene release, made with care".to_utf8_buffer()
	commented.encode_u16(commented.size() - 2, comment.size()); commented.append_array(comment)
	touch(base + "/roms/Commented.zip", commented)

	var entries := Archive.entries(base + "/roms/snes/Probe (USA).zip")
	check(entries.size() == 2 and entries.any(func(e): return e.name == "Probe (USA).sfc" and e.size == snes.size()), "The ZIP directory lists names and sizes without unpacking")
	check(Registry.identify(base + "/roms/snes/Probe (USA).zip") == "snes", "A ZIP is identified by the cartridge inside, past other files")
	check(Registry.identify(base + "/roms/Sega Probe.zip") == "megadrive", "A .bin inside a ZIP is identified by its Sega header")
	check(Registry.identify(base + "/roms/Advance.zip") == "gba", "GBA in a ZIP")
	check(Registry.identify(base + "/roms/Commented.zip") == "nes", "A ZIP with a comment is still read")
	check(Registry.identify(base + "/roms/notes.zip").is_empty(), "A ZIP of documents is not a game")
	check(Registry.identify(base + "/roms/Disc.zip").is_empty(), "Discs are not unpacked from ZIPs")
	check(Registry.identify(base + "/roms/broken.zip").is_empty(), "A damaged ZIP is skipped without an error")

	touch(base + "/roms/segacd/Sonic CD (USA).chd")
	touch(base + "/roms/megacd/USA/Popful Mail.chd")
	touch(base + "/roms/psx/Final Fantasy VII.chd")
	touch(base + "/roms/Loose.chd")
	check(Registry.identify(base + "/roms/segacd/Sonic CD (USA).chd") == "segacd", "A CHD in a Sega CD folder is a Sega CD disc")
	check(Registry.identify(base + "/roms/megacd/USA/Popful Mail.chd") == "segacd", "A CHD in a region folder inside Mega-CD is too")
	check(Registry.identify(base + "/roms/psx/Final Fantasy VII.chd") == "psx", "A CHD in a PlayStation folder is a PlayStation disc")
	check(Registry.identify(base + "/roms/Loose.chd").is_empty(), "CHDs elsewhere are not offered")

	# A disc's identity comes from its header (which carries the disc's own
	# SHA-1), never from reading hundreds of megabytes on the main thread.
	var big := PackedByteArray(); big.resize(64 * 1024 * 1024); big.encode_u32(0, 0x4d436f6d)
	touch(base + "/roms/segacd/Big Disc.chd", big)
	var started := Time.get_ticks_msec()
	var disc_hash := Registry.content_hash(base + "/roms/segacd/Big Disc.chd")
	check(disc_hash.length() == 64 and Time.get_ticks_msec() - started < 50, "A CHD is named by its header, without reading the whole disc")
	var plain_rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.gba")
	check(Registry.content_hash(plain_rom) == FileAccess.get_sha256(plain_rom), "A plain game is named by its file's SHA-256")
	check(Registry.hash_cache.has(plain_rom), "A plain game's hash is remembered for menu redraws")

	var index := RomIndex.new()
	index.start(ProjectSettings.globalize_path(base + "/roms"))
	for i in range(2000):
		if index.step(): break
	var labels := {}
	for system in index.games:
		for game in index.games[system]: labels[game.label] = system
	check(labels.get("Probe (USA)") == "snes" and labels.get("Sega Probe") == "megadrive" and labels.get("Advance") == "gba" and labels.get("Commented") == "nes", "The library scan lists zipped games under their own names")
	check(labels.get("Sonic CD (USA)") == "segacd" and labels.get("Popful Mail") == "segacd" and labels.get("Final Fantasy VII") == "psx" and not labels.has("Loose"), "The library scan lists CHDs under their console folder's system")
	check(not labels.has("notes") and not labels.has("broken") and not labels.has("Disc"), "Non-games stay out of the library")
	var library = load("res://scripts/ui/rom_library.gd").new()
	library.show_folder(ProjectSettings.globalize_path(base + "/roms/snes"))
	check(library.entries.any(func(e): return e.label == "Probe (USA).zip" and e.system == "SNES"), "The folder browser offers zipped games")

	var session = load("res://scripts/emulation/emulation_session.gd").new()
	root.add_child(session)
	session.set_process(false)
	var plain := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
	var zipped := ProjectSettings.globalize_path(base + "/roms/snes/Probe (USA).zip")
	check(session.auto_path_for(zipped) == session.auto_path_for(plain), "A zipped game resumes from the same automatic save as the plain file")
	check(session.load_rom(zipped) and session.system_id == "snes", "A zipped SNES game plays")
	check(session.rom_path == zipped and session.content_path.get_file() == "Probe (USA).sfc", "The game is known by its ZIP; the core opens the unpacked cartridge")
	check(session.rom_hash == FileAccess.get_sha256(plain), "Battery saves and states are shared with the unzipped game")
	var ran := true
	for i in range(60): ran = session.core.run_frame(0) and ran
	check(ran and session.core.info().width > 0, "The zipped game runs")
	check(session.save_state() and session.load_state(), "States round-trip for a zipped game")
	check(session.auto_path() == session.auto_path_for(zipped), "The loaded game's resume point matches the one the menu looks up")
	session.preview_frame(0, 1)
	check(session.preview_copy == "ready", "The input preview copy opens the unpacked cartridge")
	check(session.load_rom(ProjectSettings.globalize_path(base + "/roms/Sega Probe.zip")) and session.system_id == "megadrive", "A zipped Mega Drive .bin plays")
	var cached := DirAccess.get_files_at(ProjectSettings.globalize_path(Archive.CACHE))
	check(cached.size() == 1 and cached[0] == "Sega Probe.bin", "The cache holds only the game being played")
	check(not session.load_rom(ProjectSettings.globalize_path(base + "/roms/notes.zip")) and session.system_id == "megadrive" and session.loaded, "A ZIP without a game is refused and the running game continues")
	session.stop(); session.queue_free()
	await process_frame
	print("ARCHIVE CHECKS COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)

