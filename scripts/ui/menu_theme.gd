extends RefCounted
const INK := Color("181b20")
const TEXT := Color("f2ead9")
const MUTED := Color("b2b4b7")
const AMBER := Color("e4b86b")
const FACE := preload("res://assets/fonts/OpenSans.ttf")
## Weights: body text and values read lighter than the titles and headings above them.
const REGULAR := 400
const SEMIBOLD := 600
const BOLD := 700
static var weights := {}

## One shared FontVariation per weight, so labels can be set cheaply.
static func font(weight: int) -> Font:
	if not weights.has(weight):
		var variation := FontVariation.new()
		variation.base_font = FACE
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		weights[weight] = variation
	return weights[weight]

static func weigh(control: Control, weight: int) -> void:
	control.add_theme_font_override("font", font(weight))

static func box(colour: Color, border := Color.TRANSPARENT, width := 0, padding := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(padding)
	return style

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(REGULAR)
	theme.default_font_size = 22
	for type in ["Button","LineEdit"]: theme.set_font("font",type,font(SEMIBOLD))
	for type in ["Label","Button","LineEdit","ItemList"]:
		theme.set_color("font_color",type,TEXT)
		theme.set_color("font_focus_color",type,TEXT)
		theme.set_color("font_hover_color",type,TEXT)
		theme.set_color("font_disabled_color",type,Color("74777d"))
	theme.set_stylebox("panel","PanelContainer",box(INK,Color("45403a"),1,18))
	theme.set_stylebox("normal","Button",box(Color("23272d")))
	theme.set_stylebox("hover","Button",box(Color("2d323a"),Color("65666a"),1))
	theme.set_stylebox("pressed","Button",box(Color("493b28"),AMBER,2))
	theme.set_stylebox("focus","Button",box(Color.TRANSPARENT,AMBER,2))
	theme.set_stylebox("disabled","Button",box(Color("1d2025")))
	theme.set_stylebox("normal","LineEdit",box(Color("23272d")))
	theme.set_stylebox("focus","LineEdit",box(Color.TRANSPARENT,AMBER,2))
	theme.set_stylebox("scroll","VScrollBar",box(Color("24272c"),Color.TRANSPARENT,0,5))
	theme.set_stylebox("grabber","VScrollBar",box(Color("92969c"),Color.TRANSPARENT,0,5))
	theme.set_stylebox("grabber_highlight","VScrollBar",box(AMBER,Color.TRANSPARENT,0,3))
	theme.set_stylebox("grabber_pressed","VScrollBar",box(AMBER,Color.TRANSPARENT,0,3))
	return theme
