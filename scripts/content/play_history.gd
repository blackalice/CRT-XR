extends RefCounted
const Store = preload("res://scripts/ui/settings_store.gd")
var path := "user://play-history.cfg"
var recent: Array[String] = []
var favourites: Array[String] = []
## Unix time each game was last started.
var played_at: Dictionary = {}

func read(legacy := "") -> void:
	var config = Store.new().read(path)
	recent = clean(config.get_value("games","recent",[]))
	favourites = clean(config.get_value("games","favourites",[]))
	var times = config.get_value("games","played_at",{})
	played_at = times if times is Dictionary else {}
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
	return Store.write(path,config)==OK

func played(game: String) -> bool:
	var previous := recent.duplicate()
	var previous_time = played_at.get(game)
	recent.erase(game); recent.push_front(game); recent.resize(mini(20,recent.size()))
	played_at[game] = int(Time.get_unix_time_from_system())
	# Only games still listed keep a time, so the file stays small.
	for path in played_at.keys():
		if not path in recent and not path in favourites: played_at.erase(path)
	if write(): return true
	recent.assign(previous)
	if previous_time == null: played_at.erase(game)
	else: played_at[game] = previous_time
	return false

## When a game was last started (Unix time), or 0 when unknown.
func last_played(game: String) -> int:
	return int(played_at.get(game, 0))

func toggle(game: String) -> bool:
	var previous := favourites.duplicate()
	if game in favourites: favourites.erase(game)
	else: favourites.append(game)
	if write(): return true
	favourites.assign(previous)
	return false
