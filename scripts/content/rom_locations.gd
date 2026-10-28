extends RefCounted
const Platform = preload("res://scripts/platform/platform.gd")

static func unescape_mount_path(path: String) -> String:
	return path.replace("\\040", " ").replace("\\011", "\t").replace("\\012", "\n").replace("\\134", "\\")

static func parse_sd_mounts(mountinfo: String) -> PackedStringArray:
	var result := PackedStringArray()
	for line in mountinfo.split("\n", false):
		var halves := line.split(" - ", false, 1)
		if halves.size() != 2: continue
		var fields := halves[0].split(" ", false)
		var filesystem := halves[1].split(" ", false)
		if fields.size() < 6 or filesystem.size() < 2: continue
		# Steam Deck's card reader is mmcblk; internal NVMe and USB drives differ.
		if not filesystem[1].begins_with("/dev/mmcblk"): continue
		var path := unescape_mount_path(fields[4])
		if not path in result: result.append(path)
	result.sort()
	return result

static func sd_cards() -> PackedStringArray:
	var result := PackedStringArray()
	var file := FileAccess.open("/proc/self/mountinfo", FileAccess.READ)
	if file == null: return result
	# procfs reports a length of zero: whole-file helpers read no data. Stream
	# lines to EOF rather than relying on the file's reported size.
	var mountinfo := ""
	while not file.eof_reached(): mountinfo += file.get_line() + "\n"
	file.close()
	for path in parse_sd_mounts(mountinfo):
		if DirAccess.open(path) != null: result.append(path)
	return result

# Suggest existing libraries only; never scan an entire home directory or card
# automatically, and never replace the user's saved root without their choice.
static func library_candidates(home: String, mounts: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	var seen: Dictionary = {}
	var roots := PackedStringArray([home])
	roots.append_array(mounts)
	for root in roots:
		for relative in ["Emulation/roms", "emulation/roms", "retrodeck/roms", "RetroDECK/roms", "roms", "ROMs", "Roms", "ROMs/roms"]:
			var path := root.path_join(relative)
			var key := path.to_lower() if Platform.case_insensitive_paths() else path
			if DirAccess.open(path)!=null and not seen.has(key):
				seen[key]=true; result.append(path)
	return result

static func normalize_windows_path(path: String) -> String:
	var result := path.strip_edges().replace("\\", "/")
	if result.length()==2 and result[1]==":": result+="/"
	return result

static func computer_drives() -> PackedStringArray:
	var result := PackedStringArray()
	for index in range(DirAccess.get_drive_count()):
		var path := normalize_windows_path(DirAccess.get_drive_name(index))
		if not path in result: result.append(path)
	return result
