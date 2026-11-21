extends "res://scripts/ui/setting_row.gd"
## The large tiles of Home and Pause (menu_play.gd), in the menu's one-tile-per-item
## form, so they select, focus and activate like every other row.
## "tile_look" says which:
##   "stack": the icon above its name, both centred (Media on Home, Save, Load, Reset).
##   "card":  a picture, the title and a detail line, and a mark at the right edge:
##            the game to Continue, the game or video paused (id "resume").
## Item keys: "min_height", "title_size", "detail" (the second line), "trailing" (the
## mark: "Continue ›" or "›"), "emphasis" ("primary" tints the name amber), and for a
## card's picture "thumbnail_size" (its slot), "thumbnail_fill" (the picture is stretched
## over the slot, for a frame already drawn in the shape of the screen; otherwise it is
## fitted whole) and "thumbnail_fit" == "aspect" (the slot's width follows the picture's
## shape at 72 px tall, between 48 and 128 wide). A missing picture shows its console
## ("thumbnail_console") or icon ("thumbnail_icon").
const AMBER := MenuSkin.AMBER
const SLOT_HEIGHT := 72.0
var detail_label: Label
var trailing_label: Label
var slot: Control
var look := "stack"

func configure(definition: Dictionary) -> void:
	item = definition
	look = str(item.get("tile_look", "stack"))
	name = "Row_" + str(item.id).sha256_text().left(12)
	custom_minimum_size = Vector2(0, float(item.get("min_height", 84)))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	var larger := 2 if item.get("large_text", false) else 0
	var emphasis := str(item.get("emphasis", ""))
	var tint := AMBER if emphasis == "primary" else (DANGER if emphasis == "danger" else MenuSkin.MUTED)
	content_margin = MarginContainer.new()
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margins := {"left": 6, "right": 14, "top": 6, "bottom": 6} if look == "card" else {"left": 4, "right": 4, "top": 6, "bottom": 6}
	for side in margins: content_margin.add_theme_constant_override("margin_" + side, margins[side])
	add_child(content_margin)
	title_label = Label.new()
	title_label.text = str(item.label)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuSkin.shadow(title_label)
	value_label = Label.new() # the base row's, unused here
	if look == "card":
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 12)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_margin.add_child(line)
		slot = build_slot(tint)
		line.add_child(slot)
		set_thumbnail(item.get("thumbnail"))
		words = VBoxContainer.new(); words.add_theme_constant_override("separation", 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL; words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(words)
		title_label.add_theme_font_size_override("font_size", int(item.get("title_size", 26)) + larger)
		MenuSkin.weigh(title_label, MenuSkin.SEMIBOLD)
		title_label.add_theme_color_override("font_color", AMBER if emphasis != "danger" else DANGER)
		# One line, trimmed with an ellipsis: a long title never widens or lengthens the card.
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.add_child(title_label)
		detail_label = Label.new()
		detail_label.add_theme_font_size_override("font_size", 17 + larger)
		detail_label.add_theme_color_override("font_color", MenuSkin.MUTED)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuSkin.shadow(detail_label)
		words.add_child(detail_label)
		var mark := str(item.get("trailing", ""))
		if not mark.is_empty():
			trailing_label = Label.new(); trailing_label.text = mark
			trailing_label.add_theme_font_size_override("font_size", (20 if mark.length() > 1 else 30) + larger)
			trailing_label.add_theme_color_override("font_color", AMBER if mark.length() > 1 else MenuSkin.TEXT)
			trailing_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			trailing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			MenuSkin.shadow(trailing_label)
			line.add_child(trailing_label)
	else:
		var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 4)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_margin.add_child(column)
		var icon := RowIcon.new(str(item.get("row_icon", "folder")), tint)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		var narrow: bool = float(item.get("min_width", 278)) < 140.0
		title_label.add_theme_font_size_override("font_size", int(item.get("title_size", 20 if narrow else 22)) + larger)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if emphasis == "primary": title_label.add_theme_color_override("font_color", AMBER)
		# A narrow tile may wrap its name onto a second line ("Start over"); a wide one trims.
		if narrow:
			title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title_label.max_lines_visible = 2
		else:
			title_label.autowrap_mode = TextServer.AUTOWRAP_OFF; title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(title_label)
	track = ProgressBar.new(); track.hide(); add_child(track)
	pressed.connect(func(): selected.emit(item.id))
	focus_entered.connect(func(): selected.emit(item.id))
	refresh()

## The picture's recessed slot: its well, the console or icon shown until there is
## a picture, and the picture itself.
## A narrow tile's name stays on one line: its type shrinks until "Start over" fits 92 px.
func _ready() -> void:
	super._ready()
	if look == "stack" and float(item.get("min_width", 278)) < 140.0:
		var font := title_label.get_theme_font("font")
		var size := title_label.get_theme_font_size("font_size")
		var room := float(item.get("min_width", 92)) - 10.0
		while size > 14 and font.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room: size -= 1
		title_label.add_theme_font_size_override("font_size", size)

func build_slot(tint: Color) -> Control:
	var slot_size: Vector2 = item.get("thumbnail_size", Vector2(96, SLOT_HEIGHT))
	var holder := Control.new(); holder.custom_minimum_size = slot_size
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER; holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var well := Panel.new(); well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	well.add_theme_stylebox_override("panel", MenuSkin.box(Color(0.02, 0.04, 0.12, 0.75), Color(0.45, 0.55, 0.85, 0.35), 1, 0))
	holder.add_child(well)
	if item.has("thumbnail_console"):
		var glyph = preload("res://scripts/ui/console_glyph.gd").new()
		glyph.kind = str(item.thumbnail_console); glyph.custom_minimum_size = Vector2(48, 48); glyph.size = Vector2(48, 48)
		glyph.position = (slot_size - Vector2(48, 48)) * 0.5; glyph.modulate = Color(1, 1, 1, 0.55); glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(glyph)
	else:
		var placeholder := RowIcon.new(str(item.get("thumbnail_icon", "video")), tint)
		placeholder.position = (slot_size - Vector2(30, 30)) * 0.5
		holder.add_child(placeholder)
	thumbnail = TextureRect.new(); thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_SCALE if item.get("thumbnail_fill", false) else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	thumbnail.size = slot_size - Vector2(2, 2); thumbnail.position = Vector2(1, 1); thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(thumbnail)
	set_thumbnail(item.get("thumbnail"))
	return holder

func set_thumbnail(texture: Texture2D) -> void:
	if thumbnail == null: return
	thumbnail.texture = texture
	thumbnail.visible = texture != null
	thumbnail.stretch_mode = TextureRect.STRETCH_SCALE if item.get("thumbnail_fill", false) else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The console or icon placeholder steps aside once the picture arrives.
	for child in thumbnail.get_parent().get_children():
		if child != thumbnail and not child is Panel: child.visible = texture == null
	# Continue's slot follows the picture's shape: a wide frame is wider than a tall cover.
	if item.get("thumbnail_fit", "") == "aspect" and slot != null:
		var width := 96.0
		if texture != null and texture.get_height() > 0: width = clampf(roundf(SLOT_HEIGHT * float(texture.get_width()) / float(texture.get_height())), 48.0, 128.0)
		slot.custom_minimum_size.x = width
		thumbnail.size.x = width - 2.0

func refresh() -> void:
	disabled = item.get("disabled", false)
	title_label.text = str(item.label)
	if detail_label != null:
		detail_label.text = str(item.get("detail", ""))
		detail_label.visible = not detail_label.text.is_empty()
	if trailing_label != null: trailing_label.text = str(item.get("trailing", ""))
	# The menu's focus flash owns this row's own modulate.
	content_margin.modulate = Color(1, 1, 1, 0.55) if disabled else Color.WHITE
	tooltip_text = GlyphText.plain(str(item.get("disabled_reason", item.get("help", ""))))

func sync_content_height() -> void:
	pass

func formatted_value() -> String:
	return ""

func changed_from_default() -> bool:
	return false
