extends "res://scripts/ui/setting_row.gd"
## A key on the Now playing deck, after the Mega-CD control panel's: a bevelled
## pixel key with its symbol drawn cell by cell. Keys with a "caption" (Browse
## albums, Resume) are wider and carry the word beside the symbol.
const CELL := 2.0
const SHADOW := Color("000418")
## 9 cells tall, so the symbols sit on one line.
const SYMBOLS := {
	"play": ["#....", "##...", "###..", "####.", "#####", "####.", "###..", "##...", "#...."],
	"pause": ["##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##"],
	"stop": [".......", "#######", "#######", "#######", "#######", "#######", "#######", "#######", "......."],
	"next": ["#....#", "##...#", "###..#", "####.#", "######", "####.#", "###..#", "##...#", "#....#"],
	"hide": ["#######", "#.....#", "#.....#", "#.....#", "#.###.#", "#..#..#", "#.....#", "#.....#", "#######"],
	"previous": ["#....#", "#...##", "#..###", "#.####", "######", "#.####", "#..###", "#...##", "#....#"]}
var face: Control
var caption: Label

func configure(definition: Dictionary) -> void:
	super.configure(definition)
	# The row's own words step aside; its pixel panel stays.
	for child in get_children(): child.visible=child==panel
	tooltip_text=str(item.label)
	var wide: bool = item.has("caption")
	custom_minimum_size=Vector2(0 if wide else 56, 40)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL if wide else Control.SIZE_FILL
	var line := HBoxContainer.new(); line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.alignment=BoxContainer.ALIGNMENT_CENTER; line.add_theme_constant_override("separation",10)
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(line)
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
	refresh()

func refresh() -> void:
	super.refresh()
	if face!=null: face.queue_redraw()
	if caption!=null: caption.modulate=Color("85878b") if disabled else Color.WHITE

## The symbol with a cell of shadow down and right, like the menus' text.
func draw_symbol() -> void:
	var rows: Array=SYMBOLS[item.get("icon","play")]
	var colour := Color("74777d") if disabled else (MenuSkin.AMBER if item.get("icon","")=="pause" else MenuSkin.TEXT)
	for pass_colour in [SHADOW, colour]:
		var offset := CELL if pass_colour==SHADOW else 0.0
		for j in range(rows.size()):
			for i in range(rows[j].length()):
				if rows[j][i]=="#": face.draw_rect(Rect2(Vector2(i,j)*CELL+Vector2(offset,offset),Vector2(CELL,CELL)),pass_colour)
