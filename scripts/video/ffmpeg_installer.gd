extends Node
## Video playback on Windows needs FFmpeg's libraries, which Windows does not
## provide. This fetches only the five DLLs used, from BtbN's LGPL builds on
## GitHub: it reads the release zip's directory from its end, then downloads
## just those files by byte range, so the rest of the archive (tools, filters,
## devices) never comes down. Every file is checked against the archive's
## CRC-32 before it is used. CRT XR itself ships no FFmpeg.
signal progress(done: int, total: int, message: String)
signal finished(ok: bool, message: String)

const RELEASE_API := "https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest"
const RELEASE_DOWNLOADS := "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/"
const SOURCE_PAGE := "https://github.com/BtbN/FFmpeg-Builds"
## Builds this version of CRT XR can load, newest first (FFmpeg 8.x, then 7.1).
const SUPPORTED_BRANCHES := ["8.1", "8.0", "7.1"]
const NEEDED := ["avcodec", "avformat", "avutil", "swscale", "swresample"]
const INSTALL_DIR := "user://ffmpeg"
## The zip directory sits at the end: its end record plus the longest comment.
const TAIL_BYTES := 65558
var busy := false
var http: HTTPRequest
var archive_url := ""
var bytes_done := 0
var bytes_total := 0
var current_label := ""

static func install_path() -> String:
	return ProjectSettings.globalize_path(INSTALL_DIR)

## True when a previous download is present; points the decoder at it unless a
## developer has already chosen a copy with CRT_XR_FFMPEG_DIR.
static func use_installed() -> bool:
	if OS.get_name() != "Windows": return false
	var folder := install_path()
	var found := false
	for file in DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray():
		if file.begins_with("avcodec-") and file.ends_with(".dll"): found = true
	if found and OS.get_environment("CRT_XR_FFMPEG_DIR").is_empty(): OS.set_environment("CRT_XR_FFMPEG_DIR", folder)
	return found

## What a download would be, for the confirmation: "about 54 MB".
static func size_note() -> String:
	return "about 55 MB"

func _ready() -> void:
	http = HTTPRequest.new()
	http.use_threads = true
	http.max_redirects = 8
	add_child(http)

func _process(_delta: float) -> void:
	if busy and http.get_http_client_status() == HTTPClient.STATUS_BODY:
		progress.emit(bytes_done + http.get_downloaded_bytes(), bytes_total, current_label)

func request(url: String, headers := PackedStringArray()) -> Dictionary:
	headers.append("User-Agent: CRT-XR")
	var error := http.request(url, headers)
	if error != OK: return {"ok": false, "code": 0, "body": PackedByteArray(), "headers": PackedStringArray()}
	var reply: Array = await http.request_completed
	return {"ok": reply[0] == HTTPRequest.RESULT_SUCCESS, "code": int(reply[1]), "headers": reply[2], "body": reply[3]}

## The newest supported LGPL Windows build in BtbN's latest release.
func choose_archive() -> String:
	var names := PackedStringArray()
	var reply := await request(RELEASE_API, PackedStringArray(["Accept: application/vnd.github+json"]))
	if reply.ok and reply.code == 200:
		var release = JSON.parse_string(reply.body.get_string_from_utf8())
		if release is Dictionary:
			for asset in release.get("assets", []): names.append(str(asset.get("name", "")))
	for branch in SUPPORTED_BRANCHES:
		var name := "ffmpeg-n%s-latest-win64-lgpl-shared-%s.zip" % [branch, branch]
		# Without the API (rate limits, proxies) the usual names are tried directly.
		if names.is_empty() or name in names: return RELEASE_DOWNLOADS + name
	return ""

func remote_range(from: int, to: int) -> PackedByteArray:
	var reply := await request(archive_url, PackedStringArray(["Range: bytes=%d-%d" % [from, to - 1]]))
	if not reply.ok or reply.code != 206 or reply.body.size() != to - from: return PackedByteArray()
	return reply.body

## Archive size and its last bytes. GitHub's file host refuses "last N bytes"
## ranges (501), so one byte is asked for first to learn the size.
func remote_tail() -> Dictionary:
	var reply := await request(archive_url, PackedStringArray(["Range: bytes=0-0"]))
	if not reply.ok or reply.code != 206: return {}
	var size := 0
	for header in reply.headers:
		if header.to_lower().begins_with("content-range:"): size = int(header.get_slice("/", 1))
	if size <= 0: return {}
	var tail := await remote_range(maxi(0, size - TAIL_BYTES), size)
	return {"size": size, "tail": tail} if not tail.is_empty() else {}

## The central directory entries for the five libraries, and where each file's
## stored bytes end (the next file's start, or the directory).
func needed_entries(size: int, tail: PackedByteArray, directory_reader: Callable) -> Array:
	var end := -1
	for i in range(tail.size() - 22, -1, -1):
		if tail.decode_u32(i) == 0x06054b50: end = i; break
	if end < 0: return []
	var count := tail.decode_u16(end + 10)
	var directory_size := tail.decode_u32(end + 12)
	var directory_offset := tail.decode_u32(end + 16)
	var tail_start := size - tail.size()
	var directory: PackedByteArray
	if directory_offset >= tail_start: directory = tail.slice(directory_offset - tail_start, directory_offset - tail_start + directory_size)
	else: directory = await directory_reader.call(directory_offset, directory_offset + directory_size)
	var all: Array = []
	var at := 0
	for i in range(count):
		if at + 46 > directory.size() or directory.decode_u32(at) != 0x02014b50: return []
		var name_length := directory.decode_u16(at + 28)
		var length := 46 + name_length + directory.decode_u16(at + 30) + directory.decode_u16(at + 32)
		all.append({"name": directory.slice(at + 46, at + 46 + name_length).get_string_from_utf8(), "crc": directory.decode_u32(at + 16),
			"size": directory.decode_u32(at + 24), "offset": directory.decode_u32(at + 42), "record": directory.slice(at, at + length)})
		at += length
	var wanted: Array = []
	for entry in all:
		var file := str(entry.name).get_file()
		if entry.name.contains("/bin/") and file.ends_with(".dll") and file.get_slice("-", 0) in NEEDED: wanted.append(entry)
	if wanted.size() != NEEDED.size(): return []
	for entry in wanted:
		entry.end = directory_offset
		for other in all:
			if int(other.offset) > int(entry.offset) and int(other.offset) < int(entry.end): entry.end = int(other.offset)
	return wanted

## Downloads the five files into a small zip of their own, then checks and
## installs them. `reader` fetches byte ranges (the network, or a local file in tests).
func install_from(size: int, tail: PackedByteArray, reader: Callable) -> String:
	var wanted: Array = await needed_entries(size, tail, reader)
	if wanted.is_empty(): return "The FFmpeg archive does not contain the expected libraries."
	bytes_total = 0
	for entry in wanted: bytes_total += int(entry.end) - int(entry.offset)
	bytes_done = 0
	var stored := PackedByteArray()
	var central := PackedByteArray()
	for entry in wanted:
		current_label = str(entry.name).get_file()
		progress.emit(bytes_done, bytes_total, current_label)
		var piece: PackedByteArray = await reader.call(int(entry.offset), int(entry.end))
		if piece.size() != int(entry.end) - int(entry.offset): return "The download of %s was interrupted. Check the connection and try again." % current_label
		var record: PackedByteArray = entry.record.duplicate()
		record.encode_u32(42, stored.size())
		central.append_array(record)
		stored.append_array(piece)
		bytes_done += piece.size()
	var end := PackedByteArray()
	end.resize(22)
	end.encode_u32(0, 0x06054b50)
	end.encode_u16(8, wanted.size())
	end.encode_u16(10, wanted.size())
	end.encode_u32(12, central.size())
	end.encode_u32(16, stored.size())
	stored.append_array(central)
	stored.append_array(end)
	var folder := install_path()
	DirAccess.make_dir_recursive_absolute(folder)
	var temporary := folder.path_join("download.zip")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return "Could not write to %s. Check free space and permissions." % folder
	file.store_buffer(stored)
	file.close()
	var archive := ZIPReader.new()
	if archive.open(temporary) != OK: return "The downloaded files could not be read."
	var checked := {}
	for entry in wanted:
		var bytes := archive.read_file(entry.name)
		if bytes.size() != int(entry.size) or int(ClassDB.class_call_static("VideoDecoder", "crc32", bytes)) != int(entry.crc):
			archive.close()
			DirAccess.remove_absolute(temporary)
			return "%s did not match its checksum; nothing was installed. Try again." % str(entry.name).get_file()
		checked[str(entry.name).get_file()] = bytes
	archive.close()
	DirAccess.remove_absolute(temporary)
	# Only now, with every file checked, replace any earlier download.
	for old in DirAccess.get_files_at(folder):
		if old.ends_with(".dll"): DirAccess.remove_absolute(folder.path_join(old))
	for name in checked:
		var out := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
		if out == null: return "Could not write %s." % name
		out.store_buffer(checked[name])
		out.close()
	var note := ConfigFile.new()
	note.set_value("ffmpeg", "source", archive_url)
	note.set_value("ffmpeg", "licence", "GNU LGPL 2.1 or later; source and licence at " + SOURCE_PAGE)
	note.set_value("ffmpeg", "installed", Time.get_datetime_string_from_system(true))
	note.save(folder.path_join("source.cfg"))
	return ""

func install() -> void:
	if busy: return
	busy = true
	progress.emit(0, 0, "Finding FFmpeg")
	archive_url = await choose_archive()
	var message := "No supported FFmpeg build was found at " + SOURCE_PAGE + "."
	if not archive_url.is_empty():
		var start := await remote_tail()
		if start.is_empty(): message = "Could not reach GitHub to download FFmpeg. Check the connection and try again."
		else: message = await install_from(int(start.size), start.tail, remote_range)
	if message.is_empty():
		OS.set_environment("CRT_XR_FFMPEG_DIR", install_path())
		if not bool(ClassDB.class_call_static("VideoDecoder", "retry_libraries")):
			message = "The libraries downloaded but did not load: " + str(ClassDB.class_call_static("VideoDecoder", "library_error"))
	busy = false
	finished.emit(message.is_empty(), message if not message.is_empty() else "Video playback is ready: " + str(ClassDB.class_call_static("VideoDecoder", "library_version")))

## Removes downloaded libraries. Windows cannot delete a library that is in
## use, so anything left is marked and cleared at the next start, before loading.
static func remove() -> void:
	var folder := install_path()
	if not DirAccess.dir_exists_absolute(folder): return
	var left := false
	for file in DirAccess.get_files_at(folder):
		if DirAccess.remove_absolute(folder.path_join(file)) != OK: left = true
	if left:
		var marker := FileAccess.open(folder.path_join("remove"), FileAccess.WRITE)
		if marker != null: marker.close()

static func finish_removal() -> void:
	var folder := install_path()
	if not FileAccess.file_exists(folder.path_join("remove")): return
	for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))

## True when this copy of CRT XR is using libraries it downloaded.
static func installed() -> bool:
	var folder := install_path()
	return OS.get_name() == "Windows" and DirAccess.dir_exists_absolute(folder) and not FileAccess.file_exists(folder.path_join("remove")) \
		and Array(DirAccess.get_files_at(folder)).any(func(file): return str(file).begins_with("avcodec-"))
