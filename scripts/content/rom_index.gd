extends RefCounted
## Incremental scan: keep controller/UI updates running on large SD cards.
const Registry = preload("res://scripts/emulation/core_registry.gd")
const Folders = preload("res://scripts/content/console_folders.gd")
const GameTitle = preload("res://scripts/content/game_title.gd")
const GameList = preload("res://scripts/content/game_list.gd")
const GameIdentity = preload("res://scripts/content/game_identity.gd")
## A folder whose games mostly start "1234 - " is a numbered release list.
const NUMBERED_MINIMUM := 5
static var numbered_name := RegEx.create_from_string(r"^\d{3,5}\s*-\s+")
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
## Per folder: [games, games named "1234 - …"], to spot numbered release lists.
var numbering: Dictionary = {}
## After the folders: gamelist.xml files still to read, one per step, as
## [file, folder its paths are relative to]. Empty once read.
var listing_queue: Array = []
var reading_listings := false
## Games found, by GameList.key(path), for matching gamelist entries.
var by_key: Dictionary = {}
## After the folders, before the gamelists: [system, game] still to name from
## their contents (see GameIdentity). Results are cached between scans.
var identify_queue: Array = []
var identifying := false
var identity := GameIdentity.new()
var resolved_root := ""
var directory: DirAccess
var current_path := ""
var link_reader: DirAccess = DirAccess.open("user://")

func canonical(path: String) -> String:
	var resolved := ProjectSettings.globalize_path(path).simplify_path()
	# Link checks need any real filesystem DirAccess; user:// can be missing.
	if link_reader==null: link_reader=DirAccess.open(resolved)
	if link_reader==null: return resolved
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
	listing_queue.clear(); reading_listings=false; by_key.clear()
	identify_queue.clear(); identifying=false
	identity.save_cache()

func start(path: String) -> void:
	cancel(); root_path=path; games.clear(); visited.clear(); numbering.clear(); examined=0; skipped=0; message=""
	ignored_system_folders=0; revision+=1
	for system in Registry.SYSTEMS: games[system]=[]
	if path.is_empty(): return
	var resolved := canonical(path)
	resolved_root = resolved
	if resolved.is_empty() or DirAccess.open(resolved)==null:
		message="ROM folder unavailable. Reconnect its SD card or choose another library folder."
		return
	if Folders.unsupported(path.get_file()):
		message="This console is not supported yet. Choose the main ROM folder or one supported console's folder."
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
		if identifying:
			if identify_queue.is_empty():
				identifying=false; start_listings(); continue
			identify_game(identify_queue.pop_back())
			processed+=8 # A file read: fewer per step than directory entries.
			continue
		if reading_listings:
			if listing_queue.is_empty(): finish(); break
			read_listing(listing_queue.pop_front())
			break # One gamelist per step: a large one takes a frame of its own.
		if directory==null:
			if pending.is_empty(): start_identifying(); continue
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
				var parsed := GameTitle.remember(path)
				games[system].append({"path":path,"label":parsed.title,"sort":parsed.sort})
				var counts: Array = numbering.get(current_path,[0,0])
				numbering[current_path]=[counts[0]+1,counts[1]+(1 if numbered_name.search(filename)!=null else 0)]
				revision+=1
	return not scanning

## Release numbers go from folders that are numbered lists, not from "1943 - …".
func relabel_numbered() -> void:
	for folder in numbering:
		var counts: Array = numbering[folder]
		if counts[1]<NUMBERED_MINIMUM or counts[1]*5<counts[0]*4: continue
		for system in games:
			for game in games[system]:
				if game.path.get_base_dir()!=folder: continue
				var parsed := GameTitle.remember(game.path,true)
				game.label=parsed.title; game.sort=parsed.sort
	numbering.clear()

## The folders are walked: queue every game to be named from its contents.
func start_identifying() -> void:
	relabel_numbered()
	identifying=true
	for system in games:
		for game in games[system]: identify_queue.append([system,game])

## Names one game from its checksum or disc ID, when the tables know it.
func identify_game(job: Array) -> void:
	var game: Dictionary = job[1]
	var name: String = identity.name_for(job[0],game.path)
	if name.is_empty(): return
	var named := GameTitle.use_listing(game.path,{"name":name})
	game.label=named.title; game.sort=named.sort; game["identified"]=true
	revision+=1

## Identified: queue the gamelists that may name what was found.
func start_listings() -> void:
	relabel_numbered()
	reading_listings=true
	var queued: Dictionary = {}
	for system in games:
		for game in games[system]:
			by_key[GameList.key(game.path)]=game
			var folder: String=game.path.get_base_dir()
			for candidate in GameList.candidates(root_path,system_folder(folder),folder):
				if queued.has(candidate[0]): continue
				queued[candidate[0]]=true
				if FileAccess.file_exists(candidate[0]): listing_queue.append(candidate)

## The console's own folder, directly inside the ROM root, that holds `folder`.
func system_folder(folder: String) -> String:
	if resolved_root.is_empty() or not folder.begins_with(resolved_root): return folder
	var inside := folder.substr(resolved_root.length()).trim_prefix("/").trim_prefix("\\")
	if inside.is_empty(): return resolved_root
	return resolved_root.path_join(inside.replace("\\","/").split("/",false)[0])

## Names from one gamelist. The first list to name a game wins: the one beside
## its ROMs is read before ES-DE's own.
func read_listing(candidate: Array) -> void:
	var entries: Dictionary = GameList.read(candidate[0],candidate[1],root_path)
	for key in entries:
		var game = by_key.get(key)
		if game==null or game.get("listed",false): continue
		var listing: Dictionary = entries[key]
		# An unscraped list only repeats the file name: keep a name read from the game.
		if listing.has("name") and str(listing.name)==game.path.get_file().get_basename():
			listing=listing.duplicate(); listing.erase("name")
		var named := GameTitle.use_listing(game.path,listing)
		game.label=named.title; game.sort=named.sort; game["listed"]=true
	if not entries.is_empty(): revision+=1

func finish() -> void:
	# A disc's cue or playlist stands for its tracks and discs: list the game once.
	for system in ["segacd", "psx", "dreamcast", "gamecube", "wii", "ps2"]:
		if not games.has(system): continue
		var members := Registry.playlist_members(games[system].map(func(game): return game.path))
		if not members.is_empty(): games[system] = games[system].filter(func(game): return not members.has(game.path))
	if not reading_listings: relabel_numbered()
	for system in games:
		games[system].sort_custom(func(a,b):
			var comparison: int = str(a.get("sort",a.label)).naturalnocasecmp_to(str(b.get("sort",b.label)))
			return a.path.naturalnocasecmp_to(b.path)<0 if comparison==0 else comparison<0)
	cancel()
	revision+=1
	if message.is_empty() and skipped>0:
		message="%d unavailable or duplicate linked folders skipped. Refresh after reconnecting storage." % skipped

func total() -> int:
	var result := 0
	for system in games: result+=games[system].size()
	return result
