extends RefCounted
## The state remains the authoritative, backward-compatible .rst envelope.
## Preview sidecars are small, disposable and never needed to restore a save.
static var commit_mutex := Mutex.new()
const MAX_STATE := 257 * 1024 * 1024
const MAX_PREVIEW := 1024 * 1024

static func fingerprint(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	var prefix := file.get_buffer(256).hex_encode().sha256_text() if file != null else ""
	return [FileAccess.get_modified_time(path), FileAccess.get_size(path), prefix]

static func read_state(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 4 or file.get_length() > MAX_STATE: return {}
	var value = bytes_to_var(file.get_buffer(file.get_length()))
	if not value is Dictionary or value.get("format") != 1 or not value.get("state") is PackedByteArray: return {}
	return value

static func metadata(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path + ".preview", FileAccess.READ)
	if file == null or file.get_length() < 4 or file.get_length() > MAX_PREVIEW: return {}
	var value = bytes_to_var(file.get_buffer(file.get_length()))
	if not value is Dictionary or value.get("preview_format") != 1 or value.get("source") != fingerprint(path): return {}
	return value

static func atomic_write(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_buffer(bytes); file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

static func write_preview(path: String, envelope: Dictionary) -> void:
	var preview := {"preview_format": 1, "source": fingerprint(path)}
	for key in ["saved_at", "game", "rom", "core", "thumbnail"]:
		if envelope.has(key): preview[key] = envelope[key]
	var bytes := var_to_bytes(preview)
	if bytes.size() <= MAX_PREVIEW: atomic_write(path + ".preview", bytes)

static func write_state(path: String, envelope: Dictionary) -> Error:
	# A tiny prefix distinguishes same-size overwrites within one timestamp tick.
	# Extra envelope fields remain compatible with existing format-1 readers.
	var committed := {"preview_revision": Crypto.new().generate_random_bytes(16).hex_encode()}
	committed.merge(envelope)
	var bytes := var_to_bytes(committed)
	commit_mutex.lock()
	# Never let a migration of the previous state overwrite this state's preview.
	var error := atomic_write(path, bytes)
	if error == OK:
		if FileAccess.file_exists(path + ".preview"): DirAccess.remove_absolute(path + ".preview")
		write_preview(path, envelope)
	commit_mutex.unlock()
	return error

static func ensure_metadata(path: String) -> Dictionary:
	commit_mutex.lock()
	var preview := metadata(path)
	if preview.is_empty():
		var envelope := read_state(path)
		if not envelope.is_empty():
			write_preview(path, envelope)
			preview = metadata(path)
	commit_mutex.unlock()
	return preview
