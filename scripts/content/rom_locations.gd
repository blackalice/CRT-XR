extends RefCounted

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
