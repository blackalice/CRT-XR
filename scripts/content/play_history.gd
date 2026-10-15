extends RefCounted
const Store = preload("res://scripts/ui/settings_store.gd")
var path := "user://play-history.cfg"
var recent: Array[String] = []
var favourites: Array[String] = []

func read(legacy := "") -> void:
	var config = Store.new().read(path)
	recent = clean(config.get_value("games","recent",[]))
	favourites = clean(config.get_value("games","favourites",[]))
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
	return Store.write(path,config)==OK

func played(game: String) -> bool:
	var previous := recent.duplicate()
	recent.erase(game); recent.push_front(game); recent.resize(mini(20,recent.size()))
	if write(): return true
	recent.assign(previous)
	return false

func toggle(game: String) -> bool:
	var previous := favourites.duplicate()
	if game in favourites: favourites.erase(game)
	else: favourites.append(game)
	if write(): return true
	favourites.assign(previous)
	return false
