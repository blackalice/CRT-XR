extends SceneTree
## Hardware regression probe: use an installed app's --script option and set
## CRT_XR_NES_CORE and CRT_XR_NES_ROM. Always run with isolated XDG_DATA_HOME.
## Explicit checks are required: release engines strip assert expressions.
var progress: FileAccess

func _initialize() -> void: call_deferred("run")

func mark(message: String) -> void:
	print(message)
	progress.store_line(message)
	progress.flush()

func require(ok: bool, message: String) -> bool:
	if not ok:
		mark("FAIL: " + message)
		quit(1)
	return ok

func run() -> void:
	progress = FileAccess.open("user://nes-reopen-progress.txt", FileAccess.WRITE)
	var path := OS.get_environment("CRT_XR_NES_CORE")
	var rom := OS.get_environment("CRT_XR_NES_ROM")
	if not require(FileAccess.file_exists(path) and FileAccess.file_exists(rom), "Set CRT_XR_NES_CORE and CRT_XR_NES_ROM to existing files"): return
	var preview := "--probe-preview" in OS.get_cmdline_user_args()
	var saves := ProjectSettings.globalize_path("user://probe-saves")
	var preview_saves := ProjectSettings.globalize_path("user://probe-preview")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(preview_saves)
	for cycle in range(10):
		mark("PROBE cycle=%d preview=%s" % [cycle, preview])
		var core = ClassDB.instantiate("RetroCore")
		if not require(core.load_core(path), "Core load failed"): return
		if not require(core.load_game(rom, saves), "ROM load failed: " + core.last_error()): return
		if preview and not require(core.load_preview(path, rom, preview_saves), "Preview load failed"): return
		# The unpatched core crashed on the first frame after reopening.
		for frame in range(120):
			if not require(core.run_frame(0), "Frame failed: " + core.last_error()): return
			if preview and not require(not core.run_preview(0, 1).is_empty(), "Preview failed"): return
		var info: Dictionary = core.info()
		if not require(info.width > 0 and info.height > 0 and not core.frame().is_empty(), "No game picture"): return
		var state: PackedByteArray = core.save_state()
		if not require(not state.is_empty() and core.run_frame(0) and core.load_state(state) and core.run_frame(0), "State restore failed"): return
		if preview and not require(not core.run_preview(0, 1).is_empty(), "Preview after restore failed"): return
		if not require(core.reset() and core.run_frame(0), "First frame after reset failed"): return
		if preview and not require(not core.run_preview(0, 1).is_empty(), "Preview after reset failed"): return
		core.close()
		core = null
		mark("PASS: Reopen, 120 frames, state restore and reset cycle %d" % (cycle + 1))
	mark("NES REOPEN PASS preview=" + str(preview))
	quit()
