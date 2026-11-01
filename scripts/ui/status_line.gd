extends Control
## Battery and time for the menu header, in one recessed LCD window: in the
## glasses you cannot see the Deck's own status bar. Battery, charge and clock
## share one style, seven-segment digits with their unlit segments faintly
## showing, on the menus' 2×2-pixel grid. The battery comes from Linux's
## power-supply class (the Deck's BAT1); without one (a desktop, or Windows)
## only the time shows.
const POWER := "/sys/class/power_supply"
const CELL := 2.0
## The window is this many cells tall; digits are 7×12 cells.
const ROWS := 18
const DIGIT := Vector2i(7, 12)
const WELL := Color("000c20")
const LO := Color("000418")
const HI := Color("3858a0")
const LIT := Color("68e8f8")
const GHOST := Color("0e3456")
const LOW := Color("f87858")
const SEGMENTS := {"0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg", "5": "acdfg",
	"6": "acdefg", "7": "abc", "8": "abcdefg", "9": "abcdfg"}
## 3×5-cell letters for the AM/PM indicator.
const LETTERS := {"A": [".#.", "#.#", "###", "#.#", "#.#"], "M": ["#.#", "###", "###", "#.#", "#.#"], "P": ["##.", "#.#", "##.", "#..", "#.."]}
const BOLT := ["..#", ".#.", "###", ".#.", "#.."]
var host: Node
## The status as text, for anything that reads it rather than looking.
var label := Label.new()
var battery_folder := ""
var level := -1
var charging := false
var hours := "12"
var minutes := "00"
var meridiem := ""
var colon_on := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.hide(); add_child(label)
	if DirAccess.dir_exists_absolute(POWER):
		for supply in DirAccess.get_directories_at(POWER):
			if read(POWER.path_join(supply).path_join("type")) == "Battery":
				battery_folder = POWER.path_join(supply); break
	var timer := Timer.new(); timer.wait_time = 15.0; timer.autostart = true
	timer.timeout.connect(refresh); add_child(timer)
	# The colon blinks once a second, as LCD clocks do; Reduce animation holds it.
	var blink := Timer.new(); blink.wait_time = 0.5; blink.autostart = true
	blink.timeout.connect(func():
		var still: bool = host != null and host.get("menu_reduced_motion") == true
		colon_on = true if still else not colon_on
		queue_redraw())
	add_child(blink)
	refresh()

## The first line of a sysfs file. Their reported length (4 KiB) is not their
## content, so reading the whole length fails; reading one line does not.
static func read(file: String) -> String:
	var handle := FileAccess.open(file, FileAccess.READ)
	return handle.get_line().strip_edges() if handle != null else ""

## "21:40", or "9:40 pm" when the room clocks use 12 hours.
func clock() -> String:
	return (hours + ":" + minutes + (" " + meridiem.to_lower() if not meridiem.is_empty() else "")).strip_edges()

func refresh() -> void:
	var now := Time.get_time_dict_from_system()
	meridiem = ""
	var hour := int(now.hour)
	if host != null and is_instance_valid(host.world) and not host.world.clock_24_hour:
		meridiem = "PM" if hour >= 12 else "AM"
		hour = 12 if hour % 12 == 0 else hour % 12
		hours = str(hour)
	else: hours = "%02d" % hour
	minutes = "%02d" % int(now.minute)
	level = -1
	if not battery_folder.is_empty():
		level = clampi(int(read(battery_folder.path_join("capacity"))), 0, 100)
		charging = read(battery_folder.path_join("status")) in ["Charging", "Full"]
	label.text = ("%d%% · " % level if level >= 0 else "") + clock()
	update_minimum_size()
	queue_redraw()

## Cells across: padding, battery and charge, a divider, then the clock.
func columns() -> int:
	var width := 3 + (hours.length() + 2) * (DIGIT.x + 2) + 4 + 3
	if level >= 0: width += 16 + 3 + str(level).length() * (DIGIT.x + 2) + 6 + 3 + 1 + 3
	if not meridiem.is_empty(): width += 1 + 7
	return width

func _get_minimum_size() -> Vector2:
	return Vector2(columns(), ROWS) * CELL

func cell(x: int, y: int, w: int, h: int, colour: Color) -> void:
	draw_rect(Rect2(Vector2(x, y) * CELL, Vector2(w, h) * CELL), colour)

func pattern(rows: Array, x: int, y: int, colour: Color) -> void:
	for j in range(rows.size()):
		for i in range(rows[j].length()):
			if rows[j][i] == "#": cell(x + i, y + j, 1, 1, colour)

## One seven-segment digit; " " leaves only the unlit segments.
func digit(character: String, x: int, y: int, colour: Color) -> void:
	var w := DIGIT.x; var h := DIGIT.y; var t := 2; var m := h / 2
	var bars := {"a": [x + t, y, w - 2 * t, t], "b": [x + w - t, y + t, t, m - t - 1], "c": [x + w - t, y + m + 1, t, m - t - 1],
		"d": [x + t, y + h - t, w - 2 * t, t], "e": [x, y + m + 1, t, m - t - 1], "f": [x, y + t, t, m - t - 1], "g": [x + t, y + m - 1, w - 2 * t, t]}
	for segment in "abcdefg": cell(bars[segment][0], bars[segment][1], bars[segment][2], bars[segment][3], GHOST)
	for segment in SEGMENTS.get(character, ""): cell(bars[segment][0], bars[segment][1], bars[segment][2], bars[segment][3], colour)

func _draw() -> void:
	var w := columns()
	cell(0, 0, w, ROWS, WELL)
	cell(0, 0, w, 1, LO); cell(0, 0, 1, ROWS, LO)
	cell(0, ROWS - 1, w, 1, HI); cell(w - 1, 0, 1, ROWS, HI)
	var y := (ROWS - DIGIT.y) / 2
	var x := 3
	if level >= 0:
		var colour := LOW if level <= 15 and not charging else LIT
		# The battery: an outline, a nub, and four bars of charge.
		var by := (ROWS - 7) / 2
		cell(x, by, 15, 1, colour); cell(x, by + 6, 15, 1, colour); cell(x, by, 1, 7, colour); cell(x + 14, by, 1, 7, colour)
		cell(x + 15, by + 2, 1, 3, colour)
		for n in range(4): cell(x + 2 + n * 3, by + 2, 2, 3, colour if level > n * 25 else GHOST)
		if charging: pattern(BOLT, x + 6, by + 1, WELL)
		x += 16 + 3
		for character in str(level): digit(character, x, y, colour); x += DIGIT.x + 2
		# A percent sign the height of the digits.
		cell(x, y, 2, 2, colour); cell(x + 4, y + DIGIT.y - 2, 2, 2, colour)
		for row in range(DIGIT.y): cell(x + 5 - floori(row * 6.0 / DIGIT.y), y + row, 1, 1, colour)
		x += 6 + 3
		cell(x, 3, 1, ROWS - 6, GHOST)
		x += 1 + 3
	for character in hours: digit(character, x, y, LIT); x += DIGIT.x + 2
	cell(x, y + 3, 2, 2, LIT if colon_on else GHOST); cell(x, y + DIGIT.y - 5, 2, 2, LIT if colon_on else GHOST)
	x += 2 + 2
	for character in minutes: digit(character, x, y, LIT); x += DIGIT.x + 2
	if not meridiem.is_empty():
		pattern(LETTERS[meridiem[0]], x - 1, y, LIT)
		pattern(LETTERS["M"], x + 3, y, LIT)
