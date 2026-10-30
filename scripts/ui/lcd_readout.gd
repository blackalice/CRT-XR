extends "res://scripts/ui/status_line.gd"
## The Now playing deck's display, after the Mega-CD control panel's: the play
## state, the track number and the elapsed time, in the header clock's
## seven-segment digits with their unlit segments faintly showing. `source`
## returns {"state": "play"/"pause"/"stop", "track": number or -1 for none,
## "seconds": elapsed or -1 for a live stream, whose time stays dark}.
var source: Callable
var state := "stop"
var track := -1
var seconds := -1
const PAUSED := Color("f8c048")
## 5×9-cell symbols for the play state.
const STATES := {
	"play": ["#....", "##...", "###..", "####.", "#####", "####.", "###..", "##...", "#...."],
	"pause": ["##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##"],
	"stop": [".....", "#####", "#####", "#####", "#####", "#####", "#####", "#####", "....."]}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.hide(); add_child(label)
	var timer := Timer.new(); timer.wait_time = 0.25; timer.autostart = true
	timer.timeout.connect(refresh); add_child(timer)
	refresh()

func refresh() -> void:
	if not source.is_valid(): return
	var now: Dictionary = source.call()
	var shown := [str(now.get("state", "stop")), int(now.get("track", -1)), int(now.get("seconds", -1))]
	if shown == [state, track, seconds]: return
	state = shown[0]; track = shown[1]; seconds = shown[2]
	label.text = state + (" · track %d" % track if track >= 0 else "") + (" · %d:%02d" % [seconds / 60, seconds % 60] if seconds >= 0 else "")
	update_minimum_size()
	queue_redraw()

func columns() -> int:
	return paint(false)

## Lays the display out, drawing it when asked, and returns its width in cells.
func paint(drawing: bool) -> int:
	var y := (ROWS - DIGIT.y) / 2
	var x := 4
	if drawing: pattern(STATES.get(state, STATES.stop), x, (ROWS - 9) / 2, PAUSED if state == "pause" else LIT)
	x += 5 + 4
	if track >= 0:
		for character in "%02d" % track:
			if drawing: digit(character, x, y, LIT)
			x += DIGIT.x + 2
		if drawing: cell(x + 1, 3, 1, ROWS - 6, GHOST)
		x += 1 + 1 + 3
	var time := "  :  " if seconds < 0 else "%02d:%02d" % [seconds / 60, seconds % 60]
	for character in time:
		if character == ":":
			var lit := GHOST if seconds < 0 else LIT
			if drawing: cell(x, y + 3, 2, 2, lit); cell(x, y + DIGIT.y - 5, 2, 2, lit)
			x += 2 + 2
		else:
			if drawing: digit(character, x, y, LIT)
			x += DIGIT.x + 2
	return x - 2 + 4

func _draw() -> void:
	var w := columns()
	cell(0, 0, w, ROWS, WELL)
	cell(0, 0, w, 1, LO); cell(0, 0, 1, ROWS, LO)
	cell(0, ROWS - 1, w, 1, HI); cell(w - 1, 0, 1, ROWS, HI)
	paint(true)
