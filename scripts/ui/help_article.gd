extends RefCounted
## Help pages as structured articles rather than one block of text. The copy
## is a small markup, one block per line or paragraph:
##   ## Heading               a section heading, with a rule beneath
##   1. Text                 a numbered step
##   - Text  or  * Text      a bullet
##   A | Enter :: Text       a control: button chips (pad, then keyboard)
##   !! Title                a card; the paragraph after it is its body
##   > Text                  a tip, set apart
##   Label := Value          a fact: a quiet label beside its value
##   @@ logo                 the animated 3D logo (scripts/ui/logo_3d.gd)
##   anything else           a paragraph; consecutive lines join, as in Markdown
## Markdown files (THIRD_PARTY.md) read as the same: their `# Title` is
## dropped (the page has one), code ticks and link targets are removed, and
## indented lines continue the bullet above.
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const InputGlyph = preload("res://scripts/ui/input_glyph.gd")
const GlyphText = preload("res://scripts/ui/glyph_text.gd")
const CARD := Color("102860")
const CHIP := Color("000c30")
const RULE := Color("3858a0")
const EDGE := Color("3858a0")

## Blocks as [kind, text, extra]: kinds heading, step, bullet, control, card,
## tip, fact, logo and text. Steps carry their number; controls their chips;
## cards their body; facts their label.
static func parse(copy: String) -> Array:
	var blocks: Array = []
	var paragraph: Array = []
	var card := [-1]  # the card awaiting its body
	for raw in copy.replace("\r", "").split("\n"):
		var line := tidy(raw)
		var stripped := line.strip_edges()
		if stripped.is_empty():
			flush(blocks, paragraph, card); continue
		# An indented line continues the bullet or step above it.
		if raw.begins_with("  ") and paragraph.is_empty() and not blocks.is_empty() and blocks[-1][0] in ["bullet", "step"]:
			blocks[-1][1] += " " + stripped; continue
		if stripped.begins_with("# "): flush(blocks, paragraph, card); continue
		if stripped.begins_with("## ") or stripped.begins_with("### "):
			flush(blocks, paragraph, card); card[0] = -1
			blocks.append(["heading", stripped.trim_prefix("### ").trim_prefix("## "), ""]); continue
		if stripped == "@@ logo":
			flush(blocks, paragraph, card); blocks.append(["logo", "", ""]); continue
		if " := " in stripped:
			flush(blocks, paragraph, card)
			var fact := stripped.split(" := ", true, 1)
			blocks.append(["fact", fact[1], fact[0]]); continue
		if stripped.begins_with("!! "):
			flush(blocks, paragraph, card); blocks.append(["card", stripped.trim_prefix("!! "), ""]); card[0] = blocks.size() - 1; continue
		if stripped.begins_with("> "):
			flush(blocks, paragraph, card); blocks.append(["tip", stripped.trim_prefix("> "), ""]); continue
		if stripped.begins_with("- ") or stripped.begins_with("* "):
			flush(blocks, paragraph, card); blocks.append(["bullet", stripped.substr(2), ""]); continue
		var number := RegEx.create_from_string("^([0-9]+)\\. (.*)$").search(stripped)
		if number != null:
			flush(blocks, paragraph, card); blocks.append(["step", number.get_string(2), number.get_string(1)]); continue
		if " :: " in stripped:
			flush(blocks, paragraph, card)
			var parts := stripped.split(" :: ", true, 1)
			blocks.append(["control", parts[1], Array(parts[0].split(" | "))]); continue
		paragraph.append(stripped)
	flush(blocks, paragraph, card)
	return blocks

## The paragraph so far becomes a block, or the body of the card above it.
static func flush(blocks: Array, paragraph: Array, card: Array) -> void:
	if paragraph.is_empty(): return
	var text := " ".join(PackedStringArray(paragraph))
	paragraph.clear()
	if card[0] >= 0 and blocks[card[0]][2] == "": blocks[card[0]][2] = text
	else: blocks.append(["text", text, ""])

## Markdown's code ticks and link targets are noise on a TV menu.
static func tidy(line: String) -> String:
	line = line.replace("`", "")
	return RegEx.create_from_string("\\[([^\\]]+)\\]\\([^)]+\\)").sub(line, "$1", true)

## The article's controls, ready to add to the page's column.
static func build(copy: String, large: bool) -> Control:
	var size := 24 if large else 22
	var article := VBoxContainer.new()
	article.add_theme_constant_override("separation", 12)
	article.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var first := true
	for block in parse(copy):
		match block[0]:
			"heading":
				if not first: article.add_child(spacer(10))
				var heading := label(block[1].to_upper(), size - 4, MenuSkin.BOLD, MenuSkin.AMBER)
				heading.add_theme_constant_override("line_spacing", 0)
				article.add_child(heading)
				var rule := ColorRect.new()
				rule.color = RULE
				rule.custom_minimum_size.y = 2
				article.add_child(rule)
			"step":
				article.add_child(marked(badge(block[2], size), block[1], size))
			"bullet":
				var dot := Control.new()
				dot.custom_minimum_size = Vector2(36, size * 1.4)
				var mark := ColorRect.new()
				mark.color = MenuSkin.AMBER
				mark.size = Vector2(8, 8)
				mark.position = Vector2(12, size * 0.7 - 4)
				dot.add_child(mark)
				article.add_child(marked(dot, block[1], size))
			"control":
				var keys := HBoxContainer.new()
				keys.add_theme_constant_override("separation", 6)
				keys.custom_minimum_size.x = 250
				for i in range(block[2].size()):
					keys.add_child(chip(str(block[2][i]).strip_edges(), size - 4, i > 0))
				article.add_child(marked(keys, block[1], size))
			"card":
				var panel := PanelContainer.new()
				panel.add_theme_stylebox_override("panel", MenuSkin.box(CARD, EDGE, 2, 16))
				var column := VBoxContainer.new()
				column.add_theme_constant_override("separation", 4)
				column.add_child(label(block[1], size, MenuSkin.SEMIBOLD, MenuSkin.TEXT))
				if block[2] != "": column.add_child(label(block[2], size - 2, MenuSkin.REGULAR, MenuSkin.MUTED))
				panel.add_child(column)
				article.add_child(panel)
			"logo":
				var logo := preload("res://scripts/ui/logo_3d.gd").new()
				logo.name = "Logo3D"
				logo.custom_minimum_size = Vector2(0, 300)
				logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				article.add_child(logo)
			"fact":
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 16)
				var key := label(block[2], size - 2, MenuSkin.REGULAR, MenuSkin.MUTED)
				key.custom_minimum_size.x = 250
				key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				row.add_child(key)
				row.add_child(label(block[1], size, MenuSkin.SEMIBOLD, MenuSkin.TEXT))
				article.add_child(row)
			"tip":
				var tip := PanelContainer.new()
				var style := MenuSkin.box(CHIP, MenuSkin.AMBER, 0, 14)
				style.border_width_left = 4
				tip.add_theme_stylebox_override("panel", style)
				tip.add_child(label(block[1], size - 2, MenuSkin.REGULAR, MenuSkin.TEXT))
				article.add_child(tip)
			_:
				article.add_child(prose(block[1], size, MenuSkin.TEXT))
		first = false
	return article

static func label(text: String, size: int, weight: int, colour: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", colour)
	MenuSkin.weigh(result, weight)
	return result

static func spacer(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	return gap

## A mark (number, dot or keys) beside wrapped text, aligned to its first line.
static func marked(mark: Control, text: String, size: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(mark)
	row.add_child(prose(text, size, MenuSkin.TEXT))
	return row

## Text that may name controls in braces ("press {A}"): drawn with glyphs.
static func prose(text: String, size: int, colour: Color) -> Control:
	if not "{" in text: return label(text, size, MenuSkin.REGULAR, colour)
	var copy := GlyphText.new(text, size, colour)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return copy

static func badge(number: String, size: int) -> Control:
	var panel := PanelContainer.new()
	# A square lit plate, like the menus' open category.
	panel.add_theme_stylebox_override("panel", MenuSkin.box(Color("2c58c0"), Color("88a8e8"), 2, 0))
	panel.custom_minimum_size = Vector2(32, 32)
	var digit := label(number, size - 6, MenuSkin.BOLD, MenuSkin.TEXT)
	MenuSkin.shadow(digit)
	digit.autowrap_mode = TextServer.AUTOWRAP_OFF
	digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(digit)
	return panel

## A button as a keycap; the keyboard's alternative is quieter. Controller
## buttons are drawn as input glyphs, as everywhere else in the menus.
static func chip(text: String, size: int, keyboard: bool) -> Control:
	if not keyboard and Array(text.split(" ", false)).any(func(word): return InputGlyph.knows(word)):
		return InputGlyph.row(text, size + 14.0, size - 2, MenuSkin.MUTED)
	var panel := PanelContainer.new()
	var style := MenuSkin.box(Color.TRANSPARENT if keyboard else CHIP, Color("1c3068") if keyboard else EDGE, 2, 0)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 2; style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	var key := label(text, size, MenuSkin.SEMIBOLD, MenuSkin.MUTED if keyboard else MenuSkin.TEXT)
	key.autowrap_mode = TextServer.AUTOWRAP_OFF
	key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_child(key)
	return panel
