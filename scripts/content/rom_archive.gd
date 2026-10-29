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

## The files in a ZIP as [{name, size, packed, method, crc, offset}], or [] when it
## is not a readable ZIP. offset is the entry's local header.
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
		if not name.ends_with("/"): result.append({"name": name, "size": directory.decode_u32(at + 24), "packed": directory.decode_u32(at + 20),
			"method": directory.decode_u16(at + 10), "crc": directory.decode_u32(at + 16), "offset": directory.decode_u32(at + 42)})
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

## A disc's files (its cue and tracks) unpacked together, as a disc needs them side
## by side. The cache keeps the last disc, so playing it again starts at once.
const DISC_MARKER := "crt-xr-disc-source.txt"

static func disc_stamp(path: String) -> String:
	return "%s|%d|%d" % [path, FileAccess.get_modified_time(path), FileAccess.get_size(path)]

## The unpacked copy of entry in the disc ZIP at path, or "" until it is unpacked.
static func unpacked_disc(path: String, entry: String) -> String:
	var folder := ProjectSettings.globalize_path(CACHE)
	if FileAccess.get_file_as_string(folder.path_join(DISC_MARKER)) != disc_stamp(path): return ""
	for item in entries(path):
		var target := folder.path_join(item.name.get_file())
		if not FileAccess.file_exists(target) or FileAccess.get_size(target) != item.size: return ""
	return folder.path_join(entry.get_file())

## Unpacks every file of a disc ZIP into the cache, streaming so a 700 MB track
## never sits in memory. For a worker thread: progress receives (done, total)
## bytes and cancelled() is polled between chunks. Returns "" or an error.
static func unpack_disc(path: String, progress: Callable, cancelled: Callable) -> String:
	var items := entries(path)
	if items.is_empty(): return "The ZIP could not be read."
	var folder := ProjectSettings.globalize_path(CACHE)
	DirAccess.make_dir_recursive_absolute(folder)
	for old in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(old))
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null: return "The ZIP could not be opened."
	var total := 0
	for item in items: total += item.size
	var done := 0
	for item in items:
		if not item.method in [0, 8]: return "The disc uses an unsupported ZIP compression method. Use Deflate or store the files uncompressed."
		var target := FileAccess.open(folder.path_join(item.name.get_file()), FileAccess.WRITE)
		if target == null: return "Cannot write the unpacked disc. Check free space."
		source.seek(item.offset)
		var local := source.get_buffer(30)
		if local.size() < 30 or local.decode_u32(0) != 0x04034b50: return "The ZIP is damaged."
		source.seek(item.offset + 30 + local.decode_u16(26) + local.decode_u16(28))
		var inflater: StreamPeerGZIP = null
		if item.method == 8:
			# StreamPeerGZIP reads zlib streams; a two-byte zlib header in front of the
			# raw deflate data makes one. The stream ends at the known size, so the
			# missing checksum trailer is never read.
			inflater = StreamPeerGZIP.new()
			inflater.start_decompression(true, 1 << 16)
			inflater.put_data(PackedByteArray([0x78, 0x9C]))
		var left: int = item.packed
		var written := 0
		while written < item.size:
			if cancelled.call(): return "Cancelled."
			var output := PackedByteArray()
			if inflater == null or left > 0:
				var chunk := source.get_buffer(mini(left, 1 << 20))
				left -= chunk.size()
				if chunk.is_empty(): return "The ZIP ends early; it may be damaged or still copying."
				if inflater == null: output = chunk
				else:
					var at := 0
					while at < chunk.size():
						var put: Array = inflater.put_partial_data(chunk.slice(at))
						at += int(put[1])
						var out: Array = inflater.get_partial_data(inflater.get_available_bytes())
						output.append_array(out[1])
						if put[1] == 0 and out[1].is_empty(): return "The disc could not be unpacked; the ZIP may be damaged."
			else:
				var rest: Array = inflater.get_partial_data(inflater.get_available_bytes())
				if rest[1].is_empty(): return "The disc could not be unpacked; the ZIP may be damaged."
				output = rest[1]
			output = output.slice(0, item.size - written)
			target.store_buffer(output)
			written += output.size(); done += output.size()
			progress.call(done, total)
		target.close()
		if target.get_error() != OK: return "Cannot write the unpacked disc. Check free space."
	var marker := FileAccess.open(folder.path_join(DISC_MARKER), FileAccess.WRITE)
	if marker == null: return "Cannot write the unpacked disc."
	marker.store_string(disc_stamp(path))
	marker.close()
	return ""
