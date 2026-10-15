extends RefCounted
## Incremental scan: keep controller/UI updates running on large SD cards.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Folders = preload("res://scripts/content/console_folders.gd")
const SKIP_DIRS := ["bios","media","images","videos","manuals","screenshots","saves","states"]
const MAX_ENTRIES := 200000
var root_path := ""
var games: Dictionary = {}
var scanning := false
var message := ""
var examined := 0
var skipped := 0
var pending: Array[Dictionary] = []
var supported_scope := false
var ignored_system_folders := 0
var revision := 0
var visited: Dictionary = {}
var directory: DirAccess
var current_path := ""
var link_reader: DirAccess = DirAccess.open("user://")

func canonical(path: String) -> String:
	var resolved := ProjectSettings.globalize_path(path).simplify_path()
	# Resolve symlink ancestors too (EmuDeck commonly links the ROM root to SD).
	for attempt in range(32):
		var probe := resolved
		var suffix := ""
		var changed := false
		while not probe.is_empty():
			if link_reader.is_link(probe):
				var destination := link_reader.read_link(probe)
				if destination.is_empty(): return ""
				resolved = (destination if destination.is_absolute_path() else probe.get_base_dir().path_join(destination)).path_join(suffix).simplify_path()
				changed = true
				break
			var parent := probe.get_base_dir()
			if parent==probe: break
			suffix = probe.get_file().path_join(suffix) if not suffix.is_empty() else probe.get_file()
			probe = parent
		if not changed: return resolved
	return "" # Link cycle / excessive indirection.

func cancel() -> void:
	if directory!=null: directory.list_dir_end()
	directory = null; pending.clear(); scanning=false

func start(path: String) -> void:
	cancel(); root_path=path; games.clear(); visited.clear(); examined=0; skipped=0; message=""
	ignored_system_folders=0; revision+=1
	for system in Registry.SYSTEMS: games[system]=[]
	if path.is_empty(): return
	var resolved := canonical(path)
	if resolved.is_empty() or DirAccess.open(resolved)==null:
		message="ROM folder unavailable. Reconnect its SD card or choose another library folder."
		return
	if Folders.unsupported(path.get_file()):
		message="This console is not supported yet. Choose the main ROM folder or a SNES, NES, Mega Drive, Master System or Game Gear folder."
		return
	pending.append({"path":resolved,"supported":not Folders.system(path.get_file()).is_empty()}); scanning=true

func step(budget_usec := 2000, entry_budget := 128) -> bool:
	if not scanning: return false
	var started := Time.get_ticks_usec()
	var processed := 0
	while scanning and processed<entry_budget and Time.get_ticks_usec()-started<budget_usec:
		if examined>=MAX_ENTRIES:
			message="Scan limit reached. Choose a more specific ROM folder to include the remaining files."
			finish(); break
		if directory==null:
			if pending.is_empty(): finish(); break
			var next: Dictionary=pending.pop_back()
			current_path=next.path; supported_scope=next.supported
			if visited.has(current_path): continue
			visited[current_path]=true
			directory=DirAccess.open(current_path)
			if directory==null:
				skipped+=1; continue
			if directory.list_dir_begin()!=OK:
				directory=null; skipped+=1; continue
		var filename := directory.get_next()
		processed+=1
		if filename.is_empty():
			directory.list_dir_end(); directory=null; continue
		examined+=1
		if filename.begins_with("."): continue
		var path := current_path.path_join(filename)
		if directory.current_is_dir():
			if filename.to_lower() in SKIP_DIRS: continue
			if not supported_scope and Folders.unsupported(filename):
				ignored_system_folders+=1; continue
			var resolved := canonical(path)
			if resolved.is_empty(): skipped+=1
			elif not visited.has(resolved):
				var supported := supported_scope or not Folders.system(filename).is_empty()
				var entry := {"path":resolved,"supported":supported}
				if supported: pending.append(entry)
				else: pending.push_front(entry)
		else:
			var system := Registry.identify(path)
			if not system.is_empty():
				games[system].append({"path":path,"label":filename.get_basename()})
				revision+=1
	return not scanning

func finish() -> void:
	for system in games:
		games[system].sort_custom(func(a,b):
			var comparison: int = a.label.naturalnocasecmp_to(b.label)
			return a.path.naturalnocasecmp_to(b.path)<0 if comparison==0 else comparison<0)
	cancel()
	revision+=1
	if message.is_empty() and skipped>0:
		message="%d unavailable or duplicate linked folders skipped. Refresh after reconnecting storage." % skipped

func total() -> int:
	var result := 0
	for system in games: result+=games[system].size()
	return result
