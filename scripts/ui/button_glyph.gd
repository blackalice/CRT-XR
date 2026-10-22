extends Control
## Drawn badges stay crisp at either eye's menu resolution.
var caption := "A"
func _init(value := "A") -> void:
	caption=value
	custom_minimum_size=Vector2(38 if value.length()>1 else 28,28)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var colour := Color("e6e6e6")
	var rect := Rect2(Vector2(1,1),size-Vector2(2,2))
	if caption in ["A","B","X","Y"]: draw_circle(size*.5,12,colour,false,1.5,true)
	else:
		var style := StyleBoxFlat.new(); style.bg_color=Color("252b33"); style.border_color=colour; style.set_border_width_all(1); style.set_corner_radius_all(5); draw_style_box(style,rect)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	draw_string(font,Vector2((size.x-width)*.5,(size.y-font.get_height(16))*.5+font.get_ascent(16)),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,colour)
