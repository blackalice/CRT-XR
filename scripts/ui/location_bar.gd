extends PanelContainer
## Where a file screen is: a breadcrumb with the current folder bright and its
## parents muted, so the path reads as a place rather than as another option.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const RowIcon = preload("res://scripts/ui/row_icon.gd")
const MAX_SEGMENTS := 4
var crumbs: RichTextLabel

func _init() -> void:
	add_theme_stylebox_override("panel", MenuSkin.box(Color("15181d"), Color("353b42"), 1, 8))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	line.add_child(RowIcon.new("folder", MenuSkin.AMBER))
	crumbs = RichTextLabel.new()
	crumbs.bbcode_enabled = true
	crumbs.fit_content = true
	crumbs.scroll_active = false
	crumbs.autowrap_mode = TextServer.AUTOWRAP_OFF
	crumbs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crumbs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crumbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crumbs.add_theme_font_size_override("normal_font_size", 20)
	line.add_child(crumbs)

## Friendly names for the roots people recognise: the SD card and the home folder.
static func segments(path: String, home: String, cards: Array) -> PackedStringArray:
	path = path.replace("\\", "/").trim_suffix("/")
	var root := ""
	for card in cards:
		if path == card or path.begins_with(str(card) + "/"): root = "SD card"; path = path.substr(str(card).length()); break
	if root.is_empty() and not home.is_empty() and (path == home or path.begins_with(home + "/")):
		root = "Home"; path = path.substr(home.length())
	var parts := PackedStringArray()
	if not root.is_empty(): parts.append(root)
	elif path.begins_with("//"): parts.append("Network"); path = path.substr(2)
	elif path.begins_with("/"): parts.append("Computer")
	for part in path.split("/", false): parts.append(part)
	return parts

func show_path(path: String, home: String, cards: Array) -> void:
	var parts := segments(path, home, cards)
	var shown := Array(parts)
	if shown.size() > MAX_SEGMENTS: shown = ["…"] + shown.slice(shown.size() - MAX_SEGMENTS + 1)
	var muted := MenuSkin.MUTED.to_html(false)
	var text := ""
	for i in range(shown.size()):
		var part := str(shown[i]).replace("[", "[lb]")
		if i == shown.size() - 1: text += "[b]%s[/b]" % part
		else: text += "[color=#%s]%s  ›  [/color]" % [muted, part]
	crumbs.text = text
	tooltip_text = path
