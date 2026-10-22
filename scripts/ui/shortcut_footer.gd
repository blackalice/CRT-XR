extends HFlowContainer
const Glyph = preload("res://scripts/ui/button_glyph.gd")
var controller := false
var text := "":
	set(value):
		if text==value and last_controller==controller: return
		text=value; last_controller=controller
		for child in get_children(): remove_child(child); child.queue_free()
		for action in value.replace("   "," · ").split(" · ",false):
			var group := HBoxContainer.new(); group.add_theme_constant_override("separation",4); add_child(group)
			for word in action.split(" ",false):
				if controller and word in ["A","B","X","Y","LB","RB","LT","RT","R3"]: group.add_child(Glyph.new(word))
				else:
					var label := Label.new(); label.text=word; label.add_theme_font_size_override("font_size",18); label.add_theme_color_override("font_color",Color("bfc1c5")); group.add_child(label)
var last_controller := false
func _init() -> void:
	add_theme_constant_override("h_separation",14)
	add_theme_constant_override("v_separation",4)
