extends SceneTree
## PlayStation discs without the core: telling PS1 discs from PS2 and Sega CD
## ones, eboots, playlists, listing each game once, zipped discs unpacked in the
## background, BIOS names in any case, and the sticks and triggers.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Archive = preload("res://scripts/content/rom_archive.gd")
const RomIndex = preload("res://scripts/content/rom_index.gd")
const Folders = preload("res://scripts/content/console_folders.gd")
const Gamepad = preload("res://scripts/emulation/gamepad_input.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")

func write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_buffer(bytes); file.close()

func put(bytes: PackedByteArray, offset: int, text: String) -> void:
	var ascii := text.to_ascii_buffer()
	for i in ascii.size(): bytes[offset + i] = ascii[i]

## A small disc image: an ISO 9660 volume naming PLAYSTATION at sector 16, a root
## directory at sector 18 holding SYSTEM.CNF, whose text is at sector 19.
func disc(sector_size: int, data_offset: int, boot: String, serial: String) -> PackedByteArray:
	var bytes := PackedByteArray(); bytes.resize(20 * sector_size)
	var volume := 16 * sector_size + data_offset
	bytes[volume] = 1; put(bytes, volume + 1, "CD001"); put(bytes, volume + 8, "PLAYSTATION")
	bytes.encode_u32(volume + 156 + 2, 18); bytes.encode_u32(volume + 156 + 10, 2048)
	var root := 18 * sector_size + data_offset
	var name := "SYSTEM.CNF;1"
	bytes[root] = 33 + name.length() + 1; bytes.encode_u32(root + 2, 19); bytes[root + 32] = name.length()
	put(bytes, root + 33, name)
	put(bytes, 19 * sector_size + data_offset, "%s = cdrom:\\%s;1\r\n" % [boot, serial])
	return bytes

func eboot(magic: String) -> PackedByteArray:
	var bytes := PackedByteArray(); bytes.resize(0x40)
	bytes[1] = 0x50; bytes[2] = 0x42; bytes[3] = 0x50
	bytes.encode_u32(0x24, 0x28); put(bytes, 0x28, magic)
	return bytes

func run() -> void:
	var base := "user://disc-checks"
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base)): OS.move_to_trash(ProjectSettings.globalize_path(base))
	var roms := base + "/roms"

	write(roms + "/loose/Raw.bin", disc(2352, 24, "BOOT", "SLUS_000.01"))
	write(roms + "/loose/Plain.iso", disc(2048, 0, "BOOT", "SLUS_000.02"))
	write(roms + "/loose/Second.bin", disc(2352, 24, "BOOT2", "SLUS_200.01"))
	write(roms + "/loose/Unrelated.bin", PackedByteArray([1, 2, 3, 4]))
	check(Registry.identify(roms + "/loose/Raw.bin") == "psx", "A raw PlayStation disc image is recognised")
	check(Registry.identify(roms + "/loose/Plain.iso") == "psx", "A 2048-byte PlayStation ISO is recognised")
	check(Registry.identify(roms + "/loose/Second.bin").is_empty(), "A PS2 disc (BOOT2) is not offered as PlayStation")
	check(Registry.identify(roms + "/loose/Unrelated.bin").is_empty(), "An unrelated .bin stays hidden")
	write(roms + "/loose/Raw.cue", 'FILE "Raw.bin" BINARY\n  TRACK 01 MODE2/2352\n'.to_utf8_buffer())
	check(Registry.identify(roms + "/loose/Raw.cue") == "psx", "A PlayStation cue sheet resolves its data track")

	write(roms + "/loose/Eboot.pbp", eboot("PSISOIMG0000"))
	write(roms + "/loose/Multi.pbp", eboot("PSTITLEIMG00"))
	write(roms + "/loose/Portable.pbp", eboot("NPUMDIMG"))
	check(Registry.identify(roms + "/loose/Eboot.pbp") == "psx" and Registry.identify(roms + "/loose/Multi.pbp") == "psx", "PS1 eboots are recognised")
	check(Registry.identify(roms + "/loose/Portable.pbp").is_empty(), "A PSP eboot is not offered")

	# A two-disc game: the playlist stands for its cues, and the cues for their tracks.
	var game := roms + "/psx/Saga"
	for number in [1, 2]:
		write(game + "/Saga (Disc %d).bin" % number, disc(2352, 24, "BOOT", "SLUS_100.0%d" % number))
		write(game + "/Saga (Disc %d).cue" % number, ('FILE "Saga (Disc %d).bin" BINARY\n  TRACK 01 MODE2/2352\n' % number).to_utf8_buffer())
	write(game + "/Saga (Disc 1) (Track 2).bin", PackedByteArray([0, 0, 0, 0]))
	write(game + "/Saga.m3u", "# Saga\nSaga (Disc 1).cue\n\nSaga (Disc 2).cue\n".to_utf8_buffer())
	check(Registry.identify(game + "/Saga.m3u") == "psx", "An .m3u playlist of PlayStation discs is recognised")
	check(Registry.playlist_files(game + "/Saga.m3u").size() == 2, "Playlist comments and blank lines are skipped")
	var index := RomIndex.new()
	index.start(ProjectSettings.globalize_path(game))
	for i in range(200):
		if index.step(): break
	var listed: Array = index.games.psx.map(func(entry): return entry.label)
	check(listed == ["Saga"], "A multi-disc game is listed once, by its playlist: %s" % [listed])
	var browser = load("res://scripts/ui/rom_library.gd").new()
	check(browser.show_folder(ProjectSettings.globalize_path(game)) and browser.entries.filter(func(entry): return not entry.folder).map(func(entry): return entry.label) == ["Saga.m3u"], "The folder browser lists the playlist alone")

	check(Folders.system("PS1") == "psx" and Folders.system("PlayStation") == "psx" and not Folders.unsupported("psx"), "PlayStation folder names are recognised")
	write(roms + "/psx/Loose.chd", PackedByteArray([0, 1, 2, 3]))
	check(Registry.identify(roms + "/psx/Loose.chd") == "psx", "A CHD in a PlayStation folder is a PlayStation disc")

	# Zipped discs: Redump-style ZIPs of a cue and its track, in a PlayStation folder.
	var track := disc(2352, 24, "BOOT", "SLUS_300.01")
	var cue := 'FILE "Zipped (USA).bin" BINARY\n  TRACK 01 MODE2/2352\n'.to_utf8_buffer()
	var packer := ZIPPacker.new()
	packer.open(ProjectSettings.globalize_path(roms + "/psx/Zipped (USA).zip"))
	for entry in [["Zipped (USA).cue", cue], ["Zipped (USA).bin", track]]:
		packer.start_file(entry[0]); packer.write_file(entry[1]); packer.close_file()
	packer.close()
	DirAccess.copy_absolute(ProjectSettings.globalize_path(roms + "/psx/Zipped (USA).zip"), ProjectSettings.globalize_path(roms + "/loose/Zipped (USA).zip"))
	var zipped := roms + "/psx/Zipped (USA).zip"
	check(Registry.identify(zipped) == "psx", "A zipped disc in a PlayStation folder is recognised")
	check(Registry.identify(roms + "/loose/Zipped (USA).zip").is_empty(), "A zipped disc elsewhere is not guessed at")
	check(Registry.needs_unpacking(zipped) and Registry.content_file(zipped).is_empty(), "A zipped disc must be unpacked before play")
	var hash := Registry.content_hash(zipped)
	check(hash.length() == 64 and hash == Registry.content_hash(zipped), "A zipped disc has a stable save name from its track checksums")
	var reports := []
	var error := Archive.unpack_disc(zipped, func(done: int, total: int): reports.append([done, total]), func(): return false)
	check(error.is_empty() and not reports.is_empty() and reports.back()[0] == reports.back()[1], "The disc unpacks with progress: " + error)
	var unpacked := Registry.content_file(zipped)
	check(unpacked.ends_with("Zipped (USA).cue") and not Registry.needs_unpacking(zipped), "The unpacked cue is ready to play")
	check(FileAccess.get_file_as_bytes(unpacked.get_base_dir().path_join("Zipped (USA).bin")) == track, "The unpacked track matches the original byte for byte")
	check(Archive.unpack_disc(zipped, func(_done, _total): pass, func(): return true) == "Cancelled." and Registry.needs_unpacking(zipped), "Cancelling leaves no half-unpacked disc behind")

	# EmuDeck-style BIOS folder with an upper-case dump name.
	write(base + "/bios/SCPH5501.BIN", PackedByteArray([1, 2, 3]))
	var previous: String = Registry.library_root
	Registry.library_root = ProjectSettings.globalize_path(roms)
	check(Registry.bios_file("scph5501.bin").to_lower().ends_with("disc-checks/bios/scph5501.bin"), "BIOS files are found whatever their case")
	check(Registry.bios_satisfied("psx"), "PlayStation plays without a BIOS (the core has its own)")
	var staged := ProjectSettings.globalize_path(base + "/staged")
	DirAccess.make_dir_recursive_absolute(staged)
	Registry.stage_bios("psx", staged)
	check(FileAccess.file_exists(staged.path_join("scph5501.bin")), "An optional BIOS is staged under the name the core looks for")
	Registry.library_root = previous

	# The session unpacks on a worker thread and reports progress, then the outcome.
	var session = load("res://scripts/emulation/emulation_session.gd").new()
	root.add_child(session)
	session.set_process(false)
	var progress := []
	var outcome := []
	session.unpack_progress.connect(func(_path, done, total): progress.append([done, total]))
	session.unpack_finished.connect(func(path, message): outcome.append([path, message]))
	check(session.needs_unpacking(zipped) and session.unpack_disc(zipped) and session.unpack_disc(zipped), "A disc unpacks in the background; choosing it again joins the same unpack")
	for i in range(600):
		if not outcome.is_empty(): break
		await process_frame
	check(outcome == [[zipped, ""]] and not progress.is_empty() and progress.back()[0] == progress.back()[1], "The session reports progress and a finished disc")
	check(not session.needs_unpacking(zipped) and session.unpacking.is_empty(), "The unpacked disc is ready and the worker is free")
	check(session.memory_card_name("Saga (USA) (Disc 2).zip") == "Saga (USA)" and session.memory_card_name("Saga (USA) (Disc 1).cue") == "Saga (USA)"
		and session.memory_card_name("Saga (USA).m3u") == "Saga (USA)", "A game's discs and playlist share one memory card")
	session.queue_free()

	# Sticks and triggers.
	var pad = Gamepad.new()
	for motion in [[JOY_AXIS_LEFT_X, 1.0], [JOY_AXIS_RIGHT_Y, -1.0], [JOY_AXIS_TRIGGER_LEFT, 1.0], [JOY_AXIS_TRIGGER_RIGHT, 0.2]]:
		var event := InputEventJoypadMotion.new()
		event.device = 3; event.axis = motion[0]; event.axis_value = motion[1]
		pad.handle_event(event)
	var sticks: PackedInt32Array = pad.analog()
	check(sticks[0] == 32767 and sticks[1] == 0 and sticks[2] == 0 and sticks[3] == -32767, "Sticks reach the full Libretro range")
	check(pad.mask() & (1 << 12) and not pad.mask() & (1 << 13), "A pressed trigger is L2; a light touch is not R2")
	check(pad.mask() & (1 << 7) and not pad.mask(false) & (1 << 7), "The left stick works the D-pad only for consoles without sticks")
	check(pad.view_distance_axis() != 0.0, "The right stick moves the TV for consoles without sticks")
	pad.right_stick_game = true
	check(pad.view_distance_axis() == 0.0, "The right stick is the game's on consoles with sticks")
	pad.set_menu_active(true)
	check(pad.analog() == PackedInt32Array([0, 0, 0, 0]), "Sticks are released to the game only outside the menu")

	print("PLAYSTATION CHECKS COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
