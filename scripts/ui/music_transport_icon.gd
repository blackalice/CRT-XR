extends "res://scripts/ui/setting_row.gd"
## Vector transport symbols: independent of font glyph availability.
func configure(definition: Dictionary) -> void:
	super.configure(definition)
	for child in get_children(): child.hide()
	custom_minimum_size=Vector2(64,56)
	tooltip_text=str(item.label)
	for style in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(style,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
func update_selection_style() -> void:
	queue_redraw()
func _draw() -> void:
	var center := size*.5
	if selected_now: draw_circle(center,24,Color("e4b86b"),false,2,true)
	elif is_hovered() and not disabled: draw_circle(center,24,Color("454b53"))
	var colour := Color("74777d") if disabled else Color("f2ead9")
	var icon: String=item.get("icon","play") if item!=null else "play"
	if icon=="pause":
		for x in [-8,3]: draw_rect(Rect2(center+Vector2(x,-10),Vector2(5,20)),colour)
	elif icon=="stop": draw_rect(Rect2(center-Vector2(9,9),Vector2(18,18)),colour)
	elif icon in ["previous","next"]:
		var direction := -1.0 if icon=="previous" else 1.0
		draw_colored_polygon(PackedVector2Array([center+Vector2(8*direction,0),center+Vector2(-5*direction,-10),center+Vector2(-5*direction,10)]),colour)
		draw_line(center+Vector2(10*direction,-10),center+Vector2(10*direction,10),colour,3,true)
	else:
		draw_colored_polygon(PackedVector2Array([center+Vector2(10,0),center+Vector2(-6,-11),center+Vector2(-6,11)]),colour)
