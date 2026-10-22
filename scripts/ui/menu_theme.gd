extends RefCounted
const INK := Color("181b20")
const TEXT := Color("f2ead9")
const MUTED := Color("b2b4b7")
const AMBER := Color("e4b86b")

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
	theme.default_font_size = 22
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
