extends RefCounted
const Store = preload("res://scripts/ui/settings_store.gd")
var path := "user://play-history.cfg"
var recent: Array[String] = []
var favourites: Array[String] = []
## Unix time each game was last started.
var played_at: Dictionary = {}
## Seconds each game has been played, counting only unpaused play.
var play_seconds: Dictionary = {}
## Most played lists games with at least this much play.
const MOST_PLAYED_MINIMUM := 60
const MOST_PLAYED_LIMIT := 20

func read(legacy := "") -> void:
	var config = Store.new().read(path)
	recent = clean(config.get_value("games","recent",[]))
	favourites = clean(config.get_value("games","favourites",[]))
	var times = config.get_value("games","played_at",{})
	played_at = times if times is Dictionary else {}
	play_seconds = {}
	var totals = config.get_value("games","play_seconds",{})
	if totals is Dictionary:
		for game in totals:
			if game is String and not game.is_empty() and (totals[game] is int or totals[game] is float) and totals[game] > 0:
				play_seconds[game] = int(totals[game])
	if recent.is_empty() and not legacy.is_empty(): recent.append(legacy)

func clean(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			if entry is String and not entry.is_empty() and not entry in result: result.append(entry)
	return result

func write() -> bool:
	var config := ConfigFile.new()
	config.set_value("games","recent",recent)
	config.set_value("games","favourites",favourites)
	config.set_value("games","played_at",played_at)
	config.set_value("games","play_seconds",play_seconds)
	return Store.write(path,config)==OK

func played(game: String) -> bool:
	var previous := recent.duplicate()
	var previous_time = played_at.get(game)
	recent.erase(game); recent.push_front(game); recent.resize(mini(20,recent.size()))
	played_at[game] = int(Time.get_unix_time_from_system())
	# Only games still listed keep a time, so the file stays small.
	for path in played_at.keys():
		if not path in recent and not path in favourites and not play_seconds.has(path): played_at.erase(path)
	if write(): return true
	recent.assign(previous)
	if previous_time == null: played_at.erase(game)
	else: played_at[game] = previous_time
	return false

## When a game was last started (Unix time), or 0 when unknown.
func last_played(game: String) -> int:
	return int(played_at.get(game, 0))

## Adds play to a game's total. The total is kept in memory even when the
## file cannot be written, so the next save catches up.
func add_play_time(game: String, seconds: int) -> bool:
	if game.is_empty() or seconds <= 0: return true
	play_seconds[game] = play_time(game) + seconds
	return write()

## Seconds a game has been played, or 0.
func play_time(game: String) -> int:
	return int(play_seconds.get(game, 0))

## The games played longest, longest first.
func most_played(limit := MOST_PLAYED_LIMIT) -> Array[String]:
	var result: Array[String] = []
	for game in play_seconds:
		if play_time(game) >= MOST_PLAYED_MINIMUM: result.append(game)
	result.sort_custom(func(a: String, b: String): return play_time(a) > play_time(b) if play_time(a) != play_time(b) else a < b)
	result.resize(mini(limit, result.size()))
	return result

## Play time for a library row: "45m", "3h 20m", "120h". Empty under a minute.
static func duration(seconds: int) -> String:
	var minutes := seconds / 60
	if minutes < 1: return ""
	if minutes < 60: return "%dm" % minutes
	var hours := minutes / 60
	if hours >= 100 or minutes % 60 == 0: return "%dh" % hours
	return "%dh %dm" % [hours, minutes % 60]

func toggle(game: String) -> bool:
	var previous := favourites.duplicate()
	if game in favourites: favourites.erase(game)
	else: favourites.append(game)
	if write(): return true
	favourites.assign(previous)
	return false
