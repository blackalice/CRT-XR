extends "res://scripts/ui/setting_row.gd"
## A key on the Now playing deck, after the Mega-CD control panel's: a bevelled
## pixel key with its symbol drawn cell by cell. Keys with a "caption" (Browse
## albums, Resume) are wider and carry the word beside the symbol.
const CELL := 2.0
const SHADOW := MenuSkin.SHADOW
## 9 cells tall, so the symbols sit on one line.
const SYMBOLS := {
	"volume": ["...#.......", "..##.......", ".###..#....", "####...#...", "####.#.#...", "####...#...", ".###..#....", "..##.......", "...#......."],
	"visualiser": [".......", "...#...", "#..#...", "#.##.#.", "#.##.#.", "#.##.#.", "#.####.", "#######", "......."],
	"play": ["#....", "##...", "###..", "####.", "#####", "####.", "###..", "##...", "#...."],
	"pause": ["##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##"],
	"stop": [".......", "#######", "#######", "#######", "#######", "#######", "#######", "#######", "......."],
	"next": ["#....#", "##...#", "###..#", "####.#", "######", "####.#", "###..#", "##...#", "#....#"],
	"hide": ["#######", "#.....#", "#.....#", "#.....#", "#.###.#", "#..#..#", "#.....#", "#.....#", "#######"],
	"previous": ["#....#", "#...##", "#..###", "#.####", "######", "#.####", "#..###", "#...##", "#....#"]}
var face: Control
var caption: Label
var volume_label: Label
var volume_arrows: Array[Label] = []

func configure(definition: Dictionary) -> void:
	super.configure(definition)
	# The row's own words step aside; its pixel panel stays.
	for child in get_children(): child.visible=child==panel
	tooltip_text=str(item.label)
	var volume: bool = item.kind=="number"
	var wide: bool = item.has("caption")
	custom_minimum_size=Vector2(144 if volume else (0 if wide else 56), 40)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL if wide else Control.SIZE_FILL
	var line := HBoxContainer.new(); line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.alignment=BoxContainer.ALIGNMENT_CENTER; line.add_theme_constant_override("separation",6 if volume else 10)
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(line)
	if volume: add_volume_arrow(line,"‹")
	var icon: String=item.get("icon","play")
	if SYMBOLS.has(icon):
		face=Control.new(); face.mouse_filter=Control.MOUSE_FILTER_IGNORE
		face.custom_minimum_size=Vector2(SYMBOLS[icon][0].length()+1, 10)*CELL
		face.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		face.draw.connect(draw_symbol); line.add_child(face)
	else:
		var sprite := RowIcon.new(icon,MenuSkin.TEXT if item.get("id", "") == "transport.choose" else MenuSkin.MUTED)
		sprite.size_flags_vertical=Control.SIZE_SHRINK_CENTER; line.add_child(sprite)
	if wide:
		caption=Label.new(); caption.text=str(item.caption); caption.add_theme_font_size_override("font_size",int(item.get("caption_size",20)))
		MenuSkin.shadow(caption); caption.mouse_filter=Control.MOUSE_FILTER_IGNORE; line.add_child(caption)
	if volume:
		volume_label=Label.new(); volume_label.add_theme_font_size_override("font_size",20)
		volume_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		volume_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		volume_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		volume_label.add_theme_color_override("font_color",MenuSkin.VALUE)
		MenuSkin.shadow(volume_label)
		# Reserve the complete 100% slot even at 0%, 5% and 99%. The key and its
		# neighbours never move when the number gains or loses a digit.
		var font := volume_label.get_theme_font("font")
		volume_label.custom_minimum_size.x=ceilf(font.get_string_size("100%",HORIZONTAL_ALIGNMENT_LEFT,-1,20).x)+2
		line.add_child(volume_label)
		add_volume_arrow(line,"›")
	refresh()

func add_volume_arrow(line: HBoxContainer, text: String) -> void:
	var arrow:=Label.new();arrow.text=text;arrow.add_theme_font_size_override("font_size",18)
	arrow.custom_minimum_size.x=10;arrow.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(arrow);volume_arrows.append(arrow)

func refresh() -> void:
	super.refresh()
	if face!=null: face.queue_redraw()
	if caption!=null: caption.modulate=Color("85878b") if disabled else Color.WHITE
	if volume_label!=null: volume_label.text=formatted_value()
	for arrow in volume_arrows: arrow.modulate.a=1.0 if editing and selected_now else 0.0

func update_selection_style() -> void:
	super.update_selection_style()
	if editing and selected_now: panel.material=MenuSkin.panel_material("editing")

## The symbol with a cell of shadow down and right, like the menus' text.
func draw_symbol() -> void:
	var colour := Color("74777d") if disabled else (MenuSkin.AMBER if editing or item.get("icon","")=="pause" else MenuSkin.TEXT)
	draw_on(face,item.get("icon","play"),Vector2.ZERO,colour)

## Shared by menu keys and the playback overlays.
static func draw_on(canvas: CanvasItem, symbol: String, origin: Vector2, colour: Color) -> void:
	var rows: Array=SYMBOLS[symbol]
	for pass_colour in [SHADOW, colour]:
		var offset := CELL if pass_colour==SHADOW else 0.0
		for j in range(rows.size()):
			for i in range(rows[j].length()):
				if rows[j][i]=="#": canvas.draw_rect(Rect2(origin+Vector2(i,j)*CELL+Vector2(offset,offset),Vector2(CELL,CELL)),pass_colour)
