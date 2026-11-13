extends SceneTree
## Naming games from their contents: disc IDs and serials against the lists the
## cores ship, cartridge checksums against No-Intro, and the cache between scans.
const Identity = preload("res://scripts/content/game_identity.gd")
const Index = preload("res://scripts/content/rom_index.gd")
const Archive = preload("res://scripts/content/rom_archive.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")

func write(path: String, bytes: PackedByteArray) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_buffer(bytes); file.close()
	return path

func ascii(text: String) -> PackedByteArray:
	return text.to_ascii_buffer()

## A minimal ISO 9660 volume: system name at sector 16, a root directory at
## sector 20 holding one file, whose first sector (21) holds `content`.
func iso(system_name: String, file_name: String, content: String) -> PackedByteArray:
	var image := PackedByteArray(); image.resize(2048 * 22)
	var volume := 16 * 2048
	image[volume] = 1
	for i in range(5): image[volume + 1 + i] = "CD001".unicode_at(i)
	for i in range(system_name.length()): image[volume + 8 + i] = system_name.unicode_at(i)
	image.encode_u32(volume + 156 + 2, 20)
	image.encode_u32(volume + 156 + 10, 2048)
	var record := 20 * 2048
	var name := file_name + ";1"
	image[record] = 33 + name.length() + (1 if name.length() % 2 == 0 else 0)
	image.encode_u32(record + 2, 21)
	image.encode_u32(record + 10, content.length())
	image[record + 32] = name.length()
	for i in range(name.length()): image[record + 33 + i] = name.unicode_at(i)
	for i in range(content.length()): image[21 * 2048 + i] = content.unicode_at(i)
	return image

func run():
	var folder := ProjectSettings.globalize_path("user://identity")
	# GameCube ISO and Wii RVZ: the game ID in the disc header, GameTDB's title.
	var gamecube := PackedByteArray(); gamecube.resize(0x40)
	for i in range(6): gamecube[i] = "GALE01".unicode_at(i)
	gamecube.encode_u32(0x1c, 0x3d9f33c2)
	var gc_path := write(folder.path_join("gamecube/melee.iso"), gamecube)
	check(Identity.fingerprint("gamecube", gc_path) == "GALE01", "GameCube ISO gives its game ID")
	check(Identity.lookup("gamecube", "GALE01") == "Super Smash Bros. Melee (USA)", "GameTDB's title, with the ID's region")
	var rvz := PackedByteArray(); rvz.resize(0x100)
	for i in range(4): rvz[i] = [0x52, 0x56, 0x5a, 1][i]
	for i in range(6): rvz[0x58 + i] = "RSBP01".unicode_at(i)
	var rvz_path := write(folder.path_join("wii/brawl.rvz"), rvz)
	check(Identity.fingerprint("wii", rvz_path) == "RSBP01" and Identity.lookup("wii", "RSBP01").begins_with("Super Smash Bros. Brawl"), "RVZ keeps the disc header uncompressed")
	# PS2: SYSTEM.CNF's BOOT2 serial, PCSX2's GameIndex.
	var ps2_path := write(folder.path_join("ps2/game.iso"), iso("PLAYSTATION", "SYSTEM.CNF", "BOOT2 = cdrom0:\\SLES_529.68;1\r\nVER = 1.00\r\n"))
	check(Identity.fingerprint("ps2", ps2_path) == "SLES-52968", "PS2 serial from SYSTEM.CNF")
	check(Identity.lookup("ps2", "SLES-52968") == "Burnout 2 - Point of Impact (Europe)", "PCSX2's GameIndex names the serial")
	# PSP: UMD_DATA.BIN's serial, PPSSPP's redump.csv.
	var psp_path := write(folder.path_join("psp/umd.iso"), iso("PSP GAME", "UMD_DATA.BIN", "ULUS-10020|0001|G"))
	check(Identity.fingerprint("psp", psp_path) == "ULUS-10020", "PSP serial from UMD_DATA.BIN")
	check(Identity.lookup("psp", "ULUS-10020").begins_with("Ghost in the Shell"), "redump.csv names the serial")
	# Cartridges: the bundled No-Intro tables.
	check(Identity.table_for("snes").get("c:B19ED489", "") == "Super Mario World (USA)", "SNES table by CRC")
	check(Identity.table_for("snes").get("s:6b47bb75d16514b6", "") == "Super Mario World (USA)", "SNES table by SHA-1")
	# A fixture cartridge: its checksum, found under a name the table gives.
	var rom := PackedByteArray(); rom.resize(4096)
	for i in range(rom.size()): rom[i] = (i * 7) % 251
	var loose := write(folder.path_join("snes/mario.sfc"), rom)
	var mark := Identity.fingerprint("snes", loose)
	var headered := PackedByteArray(); headered.resize(512); headered.append_array(rom)
	check(mark.begins_with("s:") and Identity.fingerprint("snes", write(folder.path_join("snes/copier.smc"), headered)) == mark, "A copier header does not change the SNES checksum")
	var packer := ZIPPacker.new(); packer.open(folder.path_join("snes/zipped.zip"))
	packer.start_file("Zipped Game.sfc"); packer.write_file(rom); packer.close_file(); packer.close()
	var zipped := folder.path_join("snes/zipped.zip")
	var crc := "c:%08X" % int(Archive.entries(zipped)[0].crc)
	check(Identity.fingerprint("snes", zipped) == crc, "A ZIP's recorded CRC is its fingerprint")
	Identity.tables["snes"][mark] = "Fixture Quest (USA)"
	Identity.tables["snes"][crc] = "Fixture Quest (Europe)"
	var identity := Identity.new()
	check(identity.name_for("snes", loose) == "Fixture Quest (USA)" and identity.name_for("snes", zipped) == "Fixture Quest (Europe)", "Files are named by their contents")
	identity.save_cache()
	Identity.tables["snes"].erase(mark)
	var again := Identity.new()
	check(again.name_for("snes", loose) == "Fixture Quest (USA)", "The cache answers without reading the file again")
	OS.delay_msec(1100) # Modified times count whole seconds.
	write(loose, rom + PackedByteArray([1]))
	check(again.name_for("snes", loose) == "", "A changed file is read again")
	write(loose, rom)
	Identity.tables["snes"][mark] = "Fixture Quest (USA)"
	var named_file := write(folder.path_join("named/Fixture Quest (Europe).sfc"), rom)
	check(again.name_for("snes", named_file) == "", "A loose cartridge whose name gives its region is not hashed")
	var odd := rom.duplicate(); odd[0] = 255
	var odd_path := write(folder.path_join("named/odd.sfc"), odd)
	Identity.tables["snes"][Identity.fingerprint("snes", odd_path)] = "& Aardman Fixture"
	check(again.name_for("snes", odd_path) == "", "A list name starting mid-name is not used")
	var junk := PackedByteArray(); junk.resize(64)
	check(Identity.fingerprint("gamecube", write(folder.path_join("named/blank.iso"), junk)) == "", "A disc without a game ID gives none")
	# The library scan uses it; a gamelist that only repeats the file name does not override it.
	var listing := FileAccess.open(folder.path_join("snes/gamelist.xml"), FileAccess.WRITE)
	listing.store_string("<gameList><game><path>./mario.sfc</path><name>mario</name><genre>Platform</genre></game></gameList>")
	listing.close()
	DirAccess.remove_absolute(folder.path_join("snes/copier.smc"))
	var index := Index.new(); index.start(folder.path_join("snes"))
	while index.scanning: index.step()
	var labels: Array = index.games.snes.map(func(game): return game.label)
	check("Fixture Quest" in labels and not "mario" in labels, "The scan shows the identified name: %s" % [labels])
	var named: Dictionary = Index.GameTitle.info(loose)
	check(named.variant == "USA" and named.get("genre", "") == "Platform", "The identified region fills in, and the gamelist still adds its genre")
	print("Game identity checks complete: ", failures, " failures")
	quit(1 if failures else 0)
