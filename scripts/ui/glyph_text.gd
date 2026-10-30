extends VBoxContainer
## Text that names controls the way the rest of the menus draw them. Write a
## control in braces: "Press {A} to continue", "{L1+R1+Start} opens the menu".
## With a controller the braces become input glyphs (input_glyph.gd); with a
## keyboard, the key that does the same (Enter, Backspace, Escape, R) or the
## button's name. Lines break at "\n" and words wrap like a label's. `text`
## keeps the string as written, so it reads back like a Label's.
const InputGlyph = preload("res://scripts/ui/input_glyph.gd")
## Keyboard keys for the controller buttons the menus describe.
const KEYBOARD := {"A": "Enter", "B": "Backspace", "R3": "R", "L1+R1+Start": "Escape"}
var font_size := 20:
	set(value): font_size = value; rebuild()
var colour := Color("e6e6e6"):
	set(value): colour = value; rebuild()
var controller := true:
	set(value):
		if controller == value: return
		controller = value; rebuild()
var centred := false:
	set(value): centred = value; rebuild()
var text := "":
	set(value):
		if text == value: return
		text = value; rebuild()

func _init(copy := "", size := 20, tint := Color("e6e6e6")) -> void:
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font_size = size
	colour = tint
	text = copy

## The text with controls written as plain words, for tooltips and logs.
static func plain(copy: String) -> String:
	return copy.replace("{", "").replace("}", "")

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for line in text.split("\n"):
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", int(font_size * 0.4))
		flow.add_theme_constant_override("v_separation", 0)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if centred: flow.alignment = FlowContainer.ALIGNMENT_CENTER
		add_child(flow)
		var at := 0
		while at < line.length():
			var open := line.find("{", at)
			if open < 0:
				words(flow, line.substr(at)); break
			var close := line.find("}", open)
			if close < 0:
				words(flow, line.substr(at)); break
			words(flow, line.substr(at, open - at))
			# Punctuation straight after a control ("{R3},") stays beside it.
			var after := close + 1
			while after < line.length() and line[after] != " " and line[after] != "{": after += 1
			control(flow, line.substr(open + 1, close - open - 1), line.substr(close + 1, after - close - 1))
			at = after

func words(flow: HFlowContainer, copy: String) -> void:
	for word in copy.split(" ", false): flow.add_child(word_label(word))

func word_label(word: String) -> Label:
	var label := Label.new()
	label.text = word
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## One control, or several joined with "+" (a chord) or "/" (alternatives).
func control(flow: HFlowContainer, name: String, trailing := "") -> void:
	if not controller:
		flow.add_child(word_label(KEYBOARD.get(name, name.replace("+", " + ")) + trailing))
		return
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 3)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var height := font_size * 1.5
	for part in name.replace("+", " + ").replace("/", " / ").split(" ", false):
		if InputGlyph.knows(part): group.add_child(InputGlyph.new(part, height))
		else:
			var joining := word_label(part)
			joining.add_theme_color_override("font_color", Color(colour, 0.7))
			group.add_child(joining)
	if not trailing.is_empty():
		var tail := word_label(trailing)
		group.add_child(tail)
		group.add_theme_constant_override("separation", 1)
	flow.add_child(group)
