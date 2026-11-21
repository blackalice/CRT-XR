extends Node
## Update check and What's new.
##
## Checking is opt-in: nothing is fetched unless the user turns on "Check for
## updates automatically" or chooses Check now. A check reads the public GitHub
## Releases list (no account, nothing sent but the request) and compares the
## newest release's tag with this build's version. Nothing is downloaded or
## installed: the user is told what is available and where to get it.
##
## State lives in its own small file, user://updates.cfg, so saved setups and
## Reset all settings leave it alone.

signal finished(result: Dictionary)

const RELEASES_URL := "https://api.github.com/repos/blackalice/CRT-XR/releases?per_page=10"
const RELEASES_PAGE := "https://github.com/blackalice/CRT-XR/releases"
const FILE := "user://updates.cfg"
const DAY := 86400
const WHATS_NEW := "res://WHATS-NEW.md"

var auto := false
var last_check := 0
var latest_tag := ""
var latest_url := ""
## The version whose What's new has been seen ("" before this feature existed).
var seen_version := ""
var checking := false
var request: HTTPRequest

static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

func _ready() -> void:
	load_state()

func load_state() -> void:
	var config := ConfigFile.new()
	if config.load(FILE) != OK: return
	auto = bool(config.get_value("updates", "auto", false))
	last_check = int(config.get_value("updates", "last_check", 0))
	latest_tag = str(config.get_value("updates", "latest_tag", ""))
	latest_url = str(config.get_value("updates", "latest_url", ""))
	seen_version = str(config.get_value("updates", "seen_version", ""))

func save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("updates", "auto", auto)
	config.set_value("updates", "last_check", last_check)
	config.set_value("updates", "latest_tag", latest_tag)
	config.set_value("updates", "latest_url", latest_url)
	config.set_value("updates", "seen_version", seen_version)
	config.save(FILE)

## True when a known release is newer than this build.
func update_available() -> bool:
	return not latest_tag.is_empty() and compare(latest_tag, current_version()) > 0

## One line for the menu: what the last check found.
func summary() -> String:
	if checking: return "Checking…"
	if update_available(): return "%s is available" % pretty(latest_tag)
	if last_check > 0: return "Up to date"
	return ""

static func pretty(tag: String) -> String:
	return tag.trim_prefix("v").trim_prefix("V")

## Compares two versions such as 0.1.0-beta.15 and v0.1.0-beta.16.
## A release with no pre-release part is newer than any of its betas.
static func compare(a: String, b: String) -> int:
	var pa := parse(a); var pb := parse(b)
	for i in range(3):
		if pa.numbers[i] != pb.numbers[i]: return 1 if pa.numbers[i] > pb.numbers[i] else -1
	if pa.pre.is_empty() and pb.pre.is_empty(): return 0
	if pa.pre.is_empty(): return 1
	if pb.pre.is_empty(): return -1
	var count := maxi(pa.pre.size(), pb.pre.size())
	for i in range(count):
		if i >= pa.pre.size(): return -1
		if i >= pb.pre.size(): return 1
		var x = pa.pre[i]; var y = pb.pre[i]
		if x == y: continue
		if x is int and y is int: return 1 if x > y else -1
		if x is int: return -1
		if y is int: return 1
		return 1 if str(x) > str(y) else -1
	return 0

static func parse(version: String) -> Dictionary:
	var text := version.strip_edges().trim_prefix("v").trim_prefix("V")
	var build_at := text.find("+")
	if build_at >= 0: text = text.substr(0, build_at)
	var dash := text.find("-")
	var core := text if dash < 0 else text.substr(0, dash)
	var numbers: Array[int] = [0, 0, 0]
	var parts := core.split(".")
	for i in range(mini(3, parts.size())): numbers[i] = int(parts[i]) if parts[i].is_valid_int() else 0
	var pre: Array = []
	if dash >= 0:
		for piece in text.substr(dash + 1).split("."):
			pre.append(int(piece) if piece.is_valid_int() else piece)
	return {"numbers": numbers, "pre": pre}

## The newest published release in a GitHub releases list (drafts skipped;
## pre-releases count, as CRT XR is in beta).
static func newest(releases: Array) -> Dictionary:
	var best := {}
	for release in releases:
		if not release is Dictionary or bool(release.get("draft", false)): continue
		var tag := str(release.get("tag_name", ""))
		if tag.is_empty(): continue
		if best.is_empty() or compare(tag, str(best.tag_name)) > 0: best = release
	return best

## Checks now. Emits finished({"ok", "newer", "tag", "url", "message"}).
func check_now() -> void:
	if checking: return
	checking = true
	if request == null:
		request = HTTPRequest.new()
		request.timeout = 15.0
		add_child(request)
		request.request_completed.connect(_on_completed)
	var error := request.request(RELEASES_URL, PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: CRT-XR/" + current_version()]))
	if error != OK:
		checking = false
		finished.emit({"ok": false, "newer": false, "message": "Couldn't start the update check (%s)." % error_string(error)})

func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	checking = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		finished.emit({"ok": false, "newer": false, "message": "Couldn't reach GitHub to check for updates. Check the internet connection and try again."})
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Array:
		finished.emit({"ok": false, "newer": false, "message": "GitHub's answer couldn't be read. Try again later."})
		return
	var release := newest(data)
	last_check = int(Time.get_unix_time_from_system())
	if not release.is_empty():
		latest_tag = str(release.tag_name)
		latest_url = str(release.get("html_url", RELEASES_PAGE))
	save_state()
	var newer := update_available()
	finished.emit({"ok": true, "newer": newer, "tag": latest_tag, "url": latest_url,
		"message": ("CRT XR %s is available. Download it from %s" % [pretty(latest_tag), RELEASES_PAGE]) if newer else "You have the latest CRT XR (%s)." % current_version()})

## At start-up: an automatic check at most once a day, when turned on.
func startup_check() -> void:
	if auto and int(Time.get_unix_time_from_system()) - last_check >= DAY: check_now()

## True once per version for someone who used an earlier one.
func should_show_whats_new(set_up: bool) -> bool:
	return set_up and seen_version != current_version()

func mark_whats_new_seen() -> void:
	seen_version = current_version()
	save_state()

static func whats_new_text() -> String:
	return FileAccess.get_file_as_string(WHATS_NEW) if FileAccess.file_exists(WHATS_NEW) else "No notes for this version."
