extends RefCounted
## A game's name as people say it, from its ROM file name. The path stays the key
## for saves, history, favourites and box art; only what the menus show changes.
##
## Understands No-Intro / Redump ("Addams Family, The (USA, Europe).md"),
## GoodTools ("Aladdin (U) [!].smc"), TOSEC ("1943 - The Battle of Midway
## (1988-10)(Capcom)(US).nes") and numbered release lists ("0003 - F-Zero (J).gba").

## Parsed names by path. The ROM index fills it as it scans, so numbered sets it
## recognised by folder keep their clean names everywhere else too.
static var known: Dictionary = {}

const NO_INTRO_REGIONS := ["USA","Europe","Japan","World","Asia","Australia","Brazil","Canada","China","France","Germany","Hong Kong","Italy","Korea","Netherlands","Spain","Sweden","Taiwan","UK","United Kingdom","Russia","Scandinavia","Denmark","Finland","Norway","Portugal","Greece","Poland","Mexico","Argentina","India","Latin America","Unknown"]
## TOSEC two-letter country codes ("US", "JP-US").
const COUNTRY := {"US":"USA","JP":"Japan","EU":"Europe","GB":"UK","DE":"Germany","FR":"France","ES":"Spain","IT":"Italy","AU":"Australia","KR":"Korea","BR":"Brazil","CA":"Canada","NL":"Netherlands","SE":"Sweden","CN":"China","TW":"Taiwan","HK":"Hong Kong","RU":"Russia","AS":"Asia"}
## GoodTools single-letter codes, also run together ("UE", "JU").
const GOOD_CODES := {"U":"USA","E":"Europe","J":"Japan","W":"World","G":"Germany","F":"France","S":"Spain","I":"Italy","A":"Australia","K":"Korea","B":"Brazil","H":"Netherlands","D":"Netherlands","R":"Russia","SW":"Sweden"}
## Shown on every row, because they change what you would be playing.
const STATUS := {"beta":"Beta","proto":"Prototype","prototype":"Prototype","demo":"Demo","sample":"Sample","unl":"Unlicensed","pirate":"Pirate","hack":"Hack","kiosk":"Kiosk","debug":"Debug","promo":"Promo","bios":"BIOS"}
## GoodTools [codes]; [!] (verified) and unknown codes say nothing.
const BRACKET := {"b":"Bad dump","h":"Hack","t":"Translation","o":"Overdump","a":"Alternate","f":"Fixed","p":"Pirate","x":"Bad checksum"}
const ARTICLES := ["The","A","An"]
## A second extension left behind ("Game.iso.zip", "Game.cue.7z").
const INNER_EXTENSIONS := ["iso","cue","bin","chd","gdi","cdi","m3u","rvz","gcm","wbfs","cso","pbp","sfc","smc","nes","md","gen","gb","gbc","gba","z64","n64","v64","pce","sms","gg"]

static var _groups := RegEx.create_from_string(r"\(([^()]*)\)|\[([^\[\]]*)\]")
static var _numbered := RegEx.create_from_string(r"^(\d{3,5})\s*-\s+")
static var _article := RegEx.create_from_string(r"^(.+?), (The|A|An)(\s+-\s+.*|:.*|\s*)$")
static var _year := RegEx.create_from_string(r"^(1[89]\d\d|20\d\d|19xx|198x|199x)(-\d\d(-\d\d)?)?$")
static var _revision := RegEx.create_from_string(r"(?i)^(rev\s*[\w.]+|v\s?\d[\w.]*|version\s+[\w.]+)$")
static var _disc := RegEx.create_from_string(r"(?i)^(disc|disk|cd)\s*(\d+)(\s+of\s+\d+)?$")
static var _status_word := RegEx.create_from_string(r"(?i)^(beta|proto|prototype|demo|sample|unl|pirate|hack|kiosk|debug|promo|bios)(\s+\d+)?$")
static var _part := RegEx.create_from_string(r"(?i)^[\p{L}\p{N}' &+.-]+ (mode|disc|disk)$|^(side [a-z0-9]+|part \d+)$")
static var _good_code :=RegEx.create_from_string(r"^[a-z]\d*[A-Za-z]{0,2}$")
static var _spaces := RegEx.create_from_string(r"\s+")
static var _search_strip := RegEx.create_from_string(r"[^\p{L}\p{N}]+")

## The display title for a ROM path.
static func of(path: String) -> String:
	return info(path).title

## Everything known about a path: title, sort, variant, tags, year, publisher,
## and from a gamelist, genre, players and developer.
static func info(path: String) -> Dictionary:
	if not known.has(path): known[path] = parse(path.get_file())
	return known[path]

## Records a path the index found; `numbered` strips a release number ("2345 - ").
static func remember(path: String, numbered := false) -> Dictionary:
	known[path] = parse(path.get_file(), numbered)
	return known[path]

## Adds a gamelist.xml entry (see GameList) to a path's name: its name, cleaned
## the same way, replaces the file's, and its year, genre and players fill the
## details. The file's region, revision and tags stay, since lists often omit them.
static func use_listing(path: String, listing: Dictionary) -> Dictionary:
	var merged: Dictionary = info(path).duplicate(true)
	if listing.has("name"):
		var named := parse(str(listing.name), false, true)
		merged.title = named.title; merged.sort = named.sort
		if str(merged.variant).is_empty(): merged.variant = named.variant
		for tag in named.tags:
			if not tag in merged.tags: merged.tags.append(tag)
	for field in ["year", "genre", "players", "publisher", "developer"]:
		if listing.has(field): merged[field] = listing[field]
	known[path] = merged
	return merged

## Parses one file name (or, with `bare`, a name with no extension). A release number with a leading zero ("0001 - ") always
## goes; others only when the folder is a numbered set, so "1943 - The Battle of
## Midway" keeps its name.
static func parse(file_name: String, numbered := false, bare := false) -> Dictionary:
	var name := file_name if bare or file_name.get_extension().is_empty() else file_name.get_basename()
	if not bare and name.get_extension().to_lower() in INNER_EXTENSIONS: name = name.get_basename()
	var raw := name
	name = name.replace("_", " ")
	var regions: Array[String] = []
	var revision := ""
	var tags: Array[String] = []
	var year := ""
	var publisher := ""
	var after_year := false
	for found in _groups.search_all(name):
		var bracket := not found.get_string(2).is_empty() or found.get_string(0).begins_with("[")
		var text := (found.get_string(2) if bracket else found.get_string(1)).strip_edges()
		if bracket:
			var code := text.left(1).to_lower()
			if text.to_upper() == "BIOS": _add(tags, "BIOS")
			elif text.begins_with("T+") or text.begins_with("T-"): _add(tags, "Translation")
			# GoodTools codes are lower case and short ("b1", "h1C"); "[Trial]" is an edition.
			elif BRACKET.has(code) and text.left(1) == code and _good_code.search(text) != null: _add(tags, BRACKET[code])
			continue
		# TOSEC: (date)(publisher) follow the title.
		if year.is_empty() and _year.search(text) != null:
			year = text.left(4); after_year = true; continue
		if after_year:
			after_year = false
			if text != "-": publisher = text
			continue
		# A second GoodTools letter is not a region: "(J) (S)" is Super Game Boy.
		var region := _regions(text, regions.is_empty())
		if not region.is_empty():
			for each in region:
				if not each in regions: regions.append(each)
			continue
		if _revision.search(text) != null: revision = text; continue
		var disc := _disc.search(text)
		if disc != null: _add(tags, "Disc " + disc.get_string(2)); continue
		var status := _status_word.search(text)
		if status != null:
			_add(tags, (STATUS[status.get_string(1).to_lower()] + status.get_string(2)).strip_edges()); continue
		# A part of a game, not a version of it: Gran Turismo 2's "Arcade Mode" and
		# "Simulation Mode" discs, a "Bonus Disc", "Side B".
		if _part.search(text) != null: _add(tags, text); continue
		if text.to_lower() in ["pal","ntsc"]: regions.append(text.to_upper())
	var title := _groups.sub(name, "", true)
	for word in ["Decrypted", "Encrypted"]:
		title = title.replace(" " + word, "")
	title = _spaces.sub(title, " ", true).strip_edges().trim_suffix(" -").strip_edges()
	var number := _numbered.search(title)
	if number != null and (numbered or (number.get_string(1).begins_with("0") and number.get_string(1).length() >= 4)):
		title = title.substr(number.get_end()).strip_edges()
	# "Legend of Zelda, The - A Link to the Past" reads "The Legend of Zelda - …"
	# but sorts under L, as it did by file name.
	var sort := title
	var article := _article.search(title)
	if article != null:
		sort = article.get_string(1) + article.get_string(3)
		title = article.get_string(2) + " " + article.get_string(1) + article.get_string(3)
	if title.is_empty(): title = raw; sort = raw
	var variant: Array[String] = []
	if not regions.is_empty(): variant.append(", ".join(regions))
	if not revision.is_empty(): variant.append(revision)
	return {"title": title, "sort": sort_key(sort), "variant": " · ".join(variant), "regions": regions, "tags": tags, "year": year, "publisher": publisher}

## Lower case without a leading article, for ordering and Jump to letter.
static func sort_key(text: String) -> String:
	var key := text.strip_edges().to_lower()
	for article in ARTICLES:
		var prefix: String = article.to_lower() + " "
		if key.begins_with(prefix) and key.length() > prefix.length(): return key.substr(prefix.length())
	return key

## The Jump to letter heading for a sort key: A-Z, or # for anything else.
static func letter(key: String) -> String:
	var first := key.left(1).to_upper()
	return first if first >= "A" and first <= "Z" else "#"

## True when every word of the query is in the title or the file name, ignoring
## case and punctuation: "zelda link" finds "The Legend of Zelda - A Link to the Past".
static func matches(query: String, path: String, title := "") -> bool:
	var words := _search_text(query).split(" ", false)
	if words.is_empty(): return true
	var haystack := " " + _search_text((title if not title.is_empty() else of(path)) + " " + path.get_file()) + " "
	for word in words:
		if not haystack.contains(word): return false
	return true

static func _search_text(text: String) -> String:
	return _search_strip.sub(text.to_lower(), " ", true).strip_edges()

## The regions a tag names, or none: "USA, Europe", "UE", "JP-US".
static func _regions(text: String, letters := true) -> Array[String]:
	var result: Array[String] = []
	var parts := text.split(",")
	var all_named := true
	for part in parts:
		var word := part.strip_edges()
		if word in NO_INTRO_REGIONS: result.append("UK" if word == "United Kingdom" else word)
		else: all_named = false; break
	if all_named and not result.is_empty(): return result
	result.clear()
	var codes := text.split("-")
	var all_countries := true
	for code in codes:
		if COUNTRY.has(code): result.append(COUNTRY[code])
		else: all_countries = false; break
	if all_countries and not result.is_empty(): return result
	result.clear()
	if text == "UK":
		result.append("UK"); return result
	if not letters or text.length() > 4 or text != text.to_upper(): return result
	for i in range(text.length()):
		var code := text[i]
		if not GOOD_CODES.has(code): result.clear(); return result
		if not GOOD_CODES[code] in result: result.append(GOOD_CODES[code])
	return result

static func _add(list: Array[String], tag: String) -> void:
	if not tag in list: list.append(tag)
