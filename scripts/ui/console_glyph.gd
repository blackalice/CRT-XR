extends Control
## Original small vector illustrations, drawn locally; no box-art downloads.
var kind := "snes"
var accent := Color("ba9fdb")
func block(rect: Rect2, colour: Color, radius := 5) -> void:
	var style := StyleBoxFlat.new(); style.bg_color=colour; style.set_corner_radius_all(radius)
	draw_style_box(style,rect)
func _draw() -> void:
	var ink := Color("15181d")
	if kind=="recent":
		draw_arc(Vector2(30,30),23,0,TAU,40,accent,2.5,true)
		draw_line(Vector2(30,16),Vector2(30,30),accent,3,true); draw_line(Vector2(30,30),Vector2(42,36),accent,3,true)
	elif kind=="favourites":
		var points := PackedVector2Array()
		for i in range(10): points.append(Vector2(30,30)+Vector2.from_angle(-PI/2+i*PI/5)*(25 if i%2==0 else 12))
		draw_colored_polygon(points,accent)
	elif kind=="locations":
		block(Rect2(6,18,48,35),accent); block(Rect2(6,12,23,12),accent); block(Rect2(12,26,36,3),ink)
	elif kind=="gamegear":
		block(Rect2(1,12,58,37),Color("424954"),8); block(Rect2(20,18,23,24),ink,2)
		block(Rect2(23,21,17,16),accent,1); block(Rect2(7,27,11,3),accent,0);block(Rect2(11,23,3,11),accent,0)
		draw_circle(Vector2(49,27),2.5,accent); draw_circle(Vector2(53,33),2.5,accent)
	else:
		var tall := kind=="nes"
		var body := Rect2(13,3,35,53) if tall else Rect2(3,10,54,40)
		block(body,Color("747983") if kind in ["snes","nes"] else Color("3e454f"),4)
		block(Rect2(body.position+Vector2(6,7),Vector2(body.size.x-12,21)),accent,2)
		block(Rect2(22,43 if tall else 42,17,8),ink,1)
		for i in range(4): draw_line(Vector2(25+i*3,45 if tall else 44),Vector2(25+i*3,49 if tall else 48),accent,1)
		if kind=="snes":
			for x in [8,51]: block(Rect2(x,16,2,19),ink,0)
