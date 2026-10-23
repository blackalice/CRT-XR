extends SceneTree
## The Windows FFmpeg download, driven from a local copy of BtbN's release zip so
## no network is needed. Needs build/ffmpeg-download/ffmpeg-n8.1-latest-win64-
## lgpl-shared-8.1.zip and its five DLLs extracted to build/ffmpeg-8.1-win64-lgpl
## for comparison; without them the suite skips. Uses an isolated user folder
## under the beta runner; otherwise it removes what it installs.
var failures := 0
const ARCHIVE := "res://build/ffmpeg-download/ffmpeg-n8.1-latest-win64-lgpl-shared-8.1.zip"
const REFERENCE := "res://build/ffmpeg-8.1-win64-lgpl"
var archive: FileAccess
var bytes_read := 0
var corrupt_at := -1

func _initialize(): call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func local_range(from: int, to: int) -> PackedByteArray:
	archive.seek(from)
	var bytes := archive.get_buffer(to - from)
	bytes_read += bytes.size()
	if corrupt_at >= from and corrupt_at < to: bytes[corrupt_at - from] ^= 0x55
	return bytes

func run() -> void:
	var path := ProjectSettings.globalize_path(ARCHIVE)
	if not FileAccess.file_exists(path) or not ClassDB.class_exists("VideoDecoder"):
		print("CHECKS SKIPPED: no local FFmpeg 8.1 archive (" + path + ")")
		quit(0)
		return
	var Installer := preload("res://scripts/video/ffmpeg_installer.gd")
	var installer: Node = Installer.new()
	root.add_child(installer)
	archive = FileAccess.open(path, FileAccess.READ)
	var size := archive.get_length()
	var tail := local_range(size - Installer.TAIL_BYTES, size)
	bytes_read = 0
	installer.archive_url = "local"

	var entries: Array = await installer.needed_entries(size, tail, local_range)
	var names: Array = entries.map(func(entry): return str(entry.name).get_file())
	names.sort()
	check(names == ["avcodec-62.dll", "avformat-62.dll", "avutil-60.dll", "swresample-6.dll", "swscale-9.dll"], "The archive's directory lists the five libraries: %s" % [names])

	var message: String = await installer.install_from(size, tail, local_range)
	check(message.is_empty(), "The five libraries install (%s)" % message)
	check(bytes_read < size * 0.75, "Only the libraries are read: %.1f of %.1f MB" % [bytes_read / 1048576.0, size / 1048576.0])
	var identical := true
	for name in names:
		var installed := Installer.install_path().path_join(name)
		var reference := ProjectSettings.globalize_path(REFERENCE).path_join(name)
		identical = identical and FileAccess.file_exists(installed) and FileAccess.get_sha256(installed) == FileAccess.get_sha256(reference)
	check(identical, "Each installed library matches the archive byte for byte")
	check(not FileAccess.file_exists(Installer.install_path().path_join("download.zip")) and FileAccess.file_exists(Installer.install_path().path_join("source.cfg")),
		"The temporary zip is removed and the source is recorded")
	var before := FileAccess.get_sha256(Installer.install_path().path_join("avutil-60.dll"))

	# One flipped byte in a library: refused, and the earlier install is untouched.
	for entry in entries:
		if str(entry.name).ends_with("avutil-60.dll"): corrupt_at = int(entry.offset) + int(entry.end - entry.offset) / 2
	message = await installer.install_from(size, tail, local_range)
	check(message.contains("did not match its checksum") and FileAccess.get_sha256(Installer.install_path().path_join("avutil-60.dll")) == before,
		"A corrupted download is refused and nothing is replaced (%s)" % message)

	OS.set_environment("CRT_XR_FFMPEG_DIR", "")
	check(Installer.use_installed() == (OS.get_name() == "Windows"), "A previous download is found at startup on Windows")
	Installer.remove()
	check(not FileAccess.file_exists(Installer.install_path().path_join("avcodec-62.dll")), "Removing deletes the downloaded libraries")
	archive.close()
	print("FFMPEG INSTALLER CHECKS COMPLETE: %d failures" % failures)
	quit(1 if failures else 0)
