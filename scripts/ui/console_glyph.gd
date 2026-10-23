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
	elif kind in ["gamegear","gameboy","gba","atarilynx","ngpc"]:
		var shell := Color("b8bd97") if kind=="gameboy" else (Color("424954") if kind=="gamegear" else Color("2c2f38"))
		block(Rect2(1,12,58,37),shell,8); block(Rect2(20,18,23,24),ink,2)
		block(Rect2(23,21,17,16),accent,1); block(Rect2(7,27,11,3),accent,0);block(Rect2(11,23,3,11),accent,0)
		draw_circle(Vector2(49,27),2.5,accent); draw_circle(Vector2(53,33),2.5,accent)
	elif kind=="atari2600":
		block(Rect2(2,20,56,26),Color("7a5a33"),3); block(Rect2(6,24,20,18),accent,1)
		for y in [27,31,35]: draw_line(Vector2(30,y),Vector2(54,y),Color("5c4425"),2)
		draw_circle(Vector2(49,15),3.5,Color("b9bdc4")); draw_line(Vector2(46,15),Vector2(52,15),ink,1)
	elif kind=="videos":
		# A video cassette: shell, label and the two spools behind the window.
		block(Rect2(3,14,54,33),Color("2a2d33"),4); block(Rect2(9,18,42,9),accent,2)
		block(Rect2(15,31,30,11),ink,2)
		for x in [21,39]: draw_circle(Vector2(x,36.5),3.5,Color("8b8f96")); draw_circle(Vector2(x,36.5),1.4,ink)
	elif kind=="vectrex":
		block(Rect2(6,12,48,36),Color("e6e4da"),6); block(Rect2(12,17,36,22),Color("1d222b"),3)
		draw_arc(Vector2(30,28),9,-0.7,PI+0.7,24,accent,1.5,true); block(Rect2(14,42,32,3),accent,1)
	else:
		var tall := kind=="nes"
		var body := Rect2(13,3,35,53) if tall else Rect2(3,10,54,40)
		block(body,Color("747983") if kind in ["snes","nes"] else Color("3e454f"),4)
		block(Rect2(body.position+Vector2(6,7),Vector2(body.size.x-12,21)),accent,2)
		block(Rect2(22,43 if tall else 42,17,8),ink,1)
		for i in range(4): draw_line(Vector2(25+i*3,45 if tall else 44),Vector2(25+i*3,49 if tall else 48),accent,1)
		if kind=="snes":
			for x in [8,51]: block(Rect2(x,16,2,19),ink,0)
