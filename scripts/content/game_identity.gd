extends RefCounted
## Names a game from its contents, for files whose names say little ("mario.sfc",
## "ddrx-na.iso"). Cartridges match No-Intro by checksum: the CRC a ZIP already
## records, else a SHA-1 of the file. Discs match by the ID they carry:
## GameCube/Wii game IDs (GameTDB titles shipped with Dolphin), PSP serials
## (PPSSPP's redump.csv) and PS2 serials (PCSX2's GameIndex). Nothing is
## downloaded. What each file matched is cached by path and modified time,
## so only new or changed files are read again.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Archive = preload("res://scripts/content/rom_archive.gd")
const CoreData = preload("res://scripts/emulation/core_data.gd")
const DolphinSupport = preload("res://scripts/emulation/dolphin_support.gd")
const GameTitle = preload("res://scripts/content/game_title.gd")
const TABLES := "res://assets/game-db"
const CACHE_PATH := "user://game-identity.json"
const CACHE_VERSION := 2
## Cartridges larger than this are not hashed (N64's largest is 64 MiB).
const HASH_LIMIT := 96 * 1024 * 1024
const CHUNK := 1024 * 1024
const SHA1_DIGITS := 16
## Disc consoles named by the ID they carry; the rest are cartridges.
const DISC_SYSTEMS := ["gamecube", "wii", "psp", "ps2"]
## GameCube/Wii region letter (the ID's fourth character) as a No-Intro region.
const NINTENDO_REGION := {"E":"USA","P":"Europe","J":"Japan","K":"Korea","D":"Germany","F":"France","S":"Spain","I":"Italy","H":"Netherlands","U":"Australia","R":"Russia","W":"Taiwan","X":"Europe","Y":"Europe","Z":"Europe"}

static var _usable_name := RegEx.create_from_string(r"^[\p{L}\p{N}'\"]")
## "BOOT2 = cdrom0:\SLUS_200.62;1" -> SLUS, 200, 62.
static var _boot2 := RegEx.create_from_string(r"BOOT2\s*=\s*cdrom0:\\*([A-Z]{4})[_-](\d{3})\.?(\d{2})")
static var _serial := RegEx.create_from_string(r"^([A-Z]{4})-?(\d{5})")

## Tables by console, loaded on first use: fingerprint -> name.
static var tables: Dictionary = {}
## path -> [modified time, fingerprint, name]
var cache: Dictionary = {}
var dirty := false
var loaded := false

## The name a file's contents give, or "" when it is unknown or unreadable.
## A loose cartridge whose file name already gives its region is taken at its
## word: hashing a whole library over a network share is slow, and those
## names come from the same lists. ZIPs (their CRC is free) and discs (one
## header read) are always checked.
func name_for(system: String, path: String) -> String:
	if not loaded: load_cache()
	if not system in DISC_SYSTEMS and path.get_extension().to_lower() != "zip" and not cache.has(path):
		if not str(GameTitle.parse(path.get_file()).variant).is_empty(): return ""
	# One check per file: on a network share each file opened costs a round trip.
	# The scan already read a ZIP's time when it looked inside.
	var modified: int = Registry.archive_cache.get(path, {}).get("stamp", -1)
	if modified < 0: modified = FileAccess.get_modified_time(path)
	if modified <= 0: return ""
	var known: Array = cache.get(path, [])
	if known.size() == 3 and int(known[0]) == modified: return str(known[2])
	var mark := fingerprint(system, path)
	var name := lookup(system, mark)
	# A list entry that starts mid-name ("& Aardman Flushed Away") is worse than the file's.
	if not name.is_empty() and _usable_name.search(name) == null: name = ""
	cache[path] = [modified, mark, name]
	dirty = true
	return name

## What identifies a file: "c:CRC32" / "s:sha1-prefix" for cartridges, a game
## ID or serial for discs, or "" when none can be read.
static func fingerprint(system: String, path: String) -> String:
	var extension := path.get_extension().to_lower()
	# A playlist is named by its first disc.
	if extension == "m3u":
		var discs := Registry.playlist_files(path)
		if discs.is_empty(): return ""
		path = discs[0]; extension = path.get_extension().to_lower()
	match system:
		"gamecube", "wii": return nintendo_id(path)
		"psp": return psp_serial(path)
		"ps2": return ps2_serial(path)
	if system in DISC_SYSTEMS or not has_table(system): return ""
	if extension == "zip":
		var game: Dictionary = Registry.archive_game(path)
		return "c:%08X" % int(game.crc) if game.has("crc") else ""
	return cartridge_sha1(system, path)

## SHA-1 of a cartridge, without a SNES copier's 512-byte header (No-Intro
## lists the bare ROM). NES and Lynx lists include their file headers.
static func cartridge_sha1(system: String, path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > HASH_LIMIT or file.get_length() == 0: return ""
	if system == "snes" and file.get_length() % 1024 == 512: file.seek(512)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA1)
	while file.get_position() < file.get_length():
		hashing.update(file.get_buffer(mini(CHUNK, file.get_length() - file.get_position())))
	return "s:" + hashing.finish().hex_encode().left(SHA1_DIGITS)

## A GameCube/Wii disc's six-character game ID ("GALE01"), from the disc header
## an ISO, WIA/RVZ or WBFS keeps uncompressed.
static func nintendo_id(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var extension := path.get_extension().to_lower()
	var offset := 0
	if extension in ["rvz", "wia"]: offset = 0x58
	elif extension == "wbfs": offset = 0x200
	elif extension == "ciso": offset = 0x8000
	if file.get_length() < offset + 6: return ""
	file.seek(offset)
	var bytes := file.get_buffer(6)
	# Check the bytes before making text of them: other files hold anything here.
	for byte in bytes:
		if not (byte >= 0x30 and byte <= 0x39 or byte >= 0x41 and byte <= 0x5a): return ""
	return bytes.get_string_from_ascii()

## A PSP serial ("ULUS-10020"): UMD_DATA.BIN on a UMD image, or DISC_ID in an
## eboot's PARAM.SFO. Compressed CSO images are not read.
static func psp_serial(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	if path.get_extension().to_lower() == "pbp": return sfo_value(eboot_sfo(file), "DISC_ID")
	var volume := Registry.disc_sector(file, [2048, 0], 16)
	if volume.size() < 2048 or not Registry.tag_at(volume, 1, "CD001"): return ""
	var umd := Registry.root_file(file, [2048, 0], volume, "UMD_DATA.BIN").get_string_from_ascii()
	return serial(umd.get_slice("|", 0))

## A PS2 serial ("SLUS-20062") from SYSTEM.CNF's BOOT2 line. A .cue reads its
## first track; compressed CHD images are not read.
static func ps2_serial(path: String) -> String:
	if path.get_extension().to_lower() == "cue":
		var tracks := Registry.cue_files(path)
		if tracks.is_empty(): return ""
		path = tracks[0]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	for layout in Registry.DISC_LAYOUTS:
		var volume := Registry.disc_sector(file, layout, 16)
		if volume.size() < 2048 or not Registry.tag_at(volume, 1, "CD001"): continue
		var config := Registry.system_cnf(file, layout, volume)
		var boot := _boot2.search(config)
		return "" if boot == null else "%s-%s%s" % [boot.get_string(1), boot.get_string(2), boot.get_string(3)]
	return ""

## "ULUS-10020" from "ULUS10020" or "ULUS-10020", else "".
static func serial(text: String) -> String:
	var found := _serial.search(text.strip_edges())
	return "" if found == null else found.get_string(1) + "-" + found.get_string(2)

## The PARAM.SFO inside a PBP eboot (its offset is the first in the header).
static func eboot_sfo(file: FileAccess) -> PackedByteArray:
	var header := file.get_buffer(0x28)
	if header.size() < 0x28 or header.slice(0, 4) != PackedByteArray([0, 0x50, 0x42, 0x50]): return PackedByteArray()
	var start := header.decode_u32(0x08)
	var end := header.decode_u32(0x0c)
	if end <= start or end - start > 65536: return PackedByteArray()
	file.seek(start)
	return file.get_buffer(end - start)

## One string value from a PARAM.SFO, or "".
static func sfo_value(sfo: PackedByteArray, wanted: String) -> String:
	if sfo.size() < 20 or sfo.slice(0, 4) != PackedByteArray([0, 0x50, 0x53, 0x46]): return ""
	var keys := sfo.decode_u32(8)
	var values := sfo.decode_u32(12)
	for index in range(sfo.decode_u32(16)):
		var entry := 20 + index * 16
		if entry + 16 > sfo.size(): break
		var key_at := keys + sfo.decode_u16(entry)
		var key := sfo.slice(key_at, key_at + 32).get_string_from_utf8().get_slice(char(0), 0)
		if key != wanted: continue
		var at := values + sfo.decode_u32(entry + 12)
		return serial(sfo.slice(at, at + sfo.decode_u32(entry + 4)).get_string_from_utf8())
	return ""

## The name for a fingerprint, or "".
static func lookup(system: String, mark: String) -> String:
	if mark.is_empty(): return ""
	var table := table_for(system)
	if system in ["gamecube", "wii"]:
		var title: String = table.get(mark, "")
		var region: String = NINTENDO_REGION.get(mark.substr(3, 1), "")
		return title if title.is_empty() or region.is_empty() else "%s (%s)" % [title, region]
	return table.get(mark, "")

static func has_table(system: String) -> bool:
	return FileAccess.file_exists(TABLES.path_join(system + ".tsv.gz"))

## A console's table, read once.
static func table_for(system: String) -> Dictionary:
	if tables.has(system): return tables[system]
	var table: Dictionary = {}
	match system:
		"gamecube", "wii":
			# Dolphin ships GameTDB's titles, "GALE01 = Super Smash Bros. Melee".
			var titles := FileAccess.open(DolphinSupport.source_directory().path_join("wiitdb-en.txt"), FileAccess.READ)
			while titles != null and not titles.eof_reached():
				var line := titles.get_line()
				var split := line.find(" = ")
				if split == 6: table[line.left(6)] = line.substr(9).strip_edges()
		"psp":
			# PPSSPP ships Redump's PSP list: Title, Region and Serial columns.
			var spec: Dictionary = Registry.DEFINITIONS.get("psp", {})
			var csv := FileAccess.open(CoreData.source_directory(spec).path_join("redump.csv"), FileAccess.READ) if spec.has("core_data") else null
			if csv != null: csv.get_csv_line()
			while csv != null and not csv.eof_reached():
				var row := csv.get_csv_line()
				if row.size() < 7 or row[2].is_empty(): continue
				var name: String = row[2] + (" (%s)" % row[5] if not row[5].is_empty() else "")
				for each in row[6].split(","):
					var code := serial(each)
					if not code.is_empty() and not table.has(code): table[code] = name
		_:
			var packed := FileAccess.get_file_as_bytes(TABLES.path_join(system + ".tsv.gz"))
			if not packed.is_empty():
				for line in packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8().split("\n", false):
					var fields := line.split("\t")
					if fields.size() == 2: table[fields[0]] = fields[1]
					elif fields.size() == 3:
						if not table.has("c:" + fields[0]): table["c:" + fields[0]] = fields[2]
						if not fields[1].is_empty() and not table.has("s:" + fields[1]): table["s:" + fields[1]] = fields[2]
	tables[system] = table
	return table

func load_cache() -> void:
	loaded = true
	var text := FileAccess.get_file_as_string(CACHE_PATH)
	var data = JSON.parse_string(text) if not text.is_empty() else null
	if data is Dictionary and int(data.get("version", 0)) == CACHE_VERSION and data.get("files") is Dictionary:
		cache = data.files

## Writes the cache when something new was read.
func save_cache() -> void:
	if not dirty: return
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"version": CACHE_VERSION, "files": cache}))
	dirty = false
