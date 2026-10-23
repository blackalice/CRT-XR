extends RefCounted
## Games inside ZIP archives. The central directory is read directly, so a scan
## learns names and sizes without inflating anything; an entry is inflated only
## to check an ambiguous header, to hash it, or to play it.
const CACHE := "user://cache/content"
## Largest entry inflated just to read a Sega header. The biggest Mega Drive
## cartridges are 5 MiB; Sega CD tracks are far larger and are not read from ZIPs.
const HEADER_LIMIT := 8 * 1024 * 1024
## Largest entry played from a ZIP: comfortably above the 32 MiB GBA maximum.
const PLAY_LIMIT := 64 * 1024 * 1024
const END_RECORD := 0x06054b50
const DIRECTORY_RECORD := 0x02014b50

## The files in a ZIP as [{name, size}], or [] when it is not a readable ZIP.
## ZIP64 archives (over 4 GiB) are not cartridges and read as empty.
static func entries(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 22: return []
	var length := file.get_length()
	# The end record is the last 22 bytes unless the archive carries a comment.
	file.seek(length - 22)
	var tail := file.get_buffer(22)
	var end := 0
	if tail.decode_u32(0) != END_RECORD:
		var size := mini(length, 22 + 65535)
		file.seek(length - size)
		tail = file.get_buffer(size)
		end = -1
		for i in range(tail.size() - 22, -1, -1):
			if tail.decode_u32(i) == END_RECORD:
				end = i
				break
		if end < 0: return []
	var count := tail.decode_u16(end + 10)
	var directory_size := tail.decode_u32(end + 12)
	var offset := tail.decode_u32(end + 16)
	if count == 0xFFFF or offset == 0xFFFFFFFF or offset + directory_size > length or directory_size > 16 * 1024 * 1024: return []
	file.seek(offset)
	var directory := file.get_buffer(directory_size)
	var result := []
	var at := 0
	for i in range(count):
		if at + 46 > directory.size() or directory.decode_u32(at) != DIRECTORY_RECORD: break
		var name_length := directory.decode_u16(at + 28)
		var name := directory.slice(at + 46, at + 46 + name_length).get_string_from_utf8()
		if not name.ends_with("/"): result.append({"name": name, "size": directory.decode_u32(at + 24)})
		at += 46 + name_length + directory.decode_u16(at + 30) + directory.decode_u16(at + 32)
	return result

## One entry's bytes, or empty when it cannot be inflated.
static func read(path: String, name: String) -> PackedByteArray:
	var reader := ZIPReader.new()
	if reader.open(path) != OK: return PackedByteArray()
	var bytes := reader.read_file(name)
	reader.close()
	return bytes

## Unpacks one entry beside nothing else: the cache holds only the game being
## played, under its own file name (some cores read the name). Returns the
## absolute path, or "" on failure.
static func extract(path: String, name: String) -> String:
	var bytes := read(path, name)
	if bytes.is_empty(): return ""
	var folder := ProjectSettings.globalize_path(CACHE)
	DirAccess.make_dir_recursive_absolute(folder)
	for old in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(old))
	var target := folder.path_join(name.get_file())
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null: return ""
	file.store_buffer(bytes)
	file.close()
	return target
