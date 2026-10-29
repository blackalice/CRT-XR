extends HFlowContainer
## The menu's hint line: "A Open · B Back". With a controller, controls are drawn
## as input glyphs (the same drawings as everywhere else); with a keyboard, words.
const InputGlyph = preload("res://scripts/ui/input_glyph.gd")
const GLYPH_HEIGHT := 30.0
var controller := false
var text := "":
	set(value):
		if text==value and last_controller==controller: return
		text=value; last_controller=controller
		for child in get_children(): remove_child(child); child.queue_free()
		for action in value.replace("   "," · ").split(" · ",false):
			var group := HBoxContainer.new(); group.add_theme_constant_override("separation",4); add_child(group)
			for word in action.split(" ",false):
				if controller and InputGlyph.knows(word): group.add_child(InputGlyph.new(word, GLYPH_HEIGHT))
				else:
					var label := Label.new(); label.text=word; label.add_theme_font_size_override("font_size",18); label.add_theme_color_override("font_color",Color("bfc1c5")); group.add_child(label)
var last_controller := false
func _init() -> void:
	add_theme_constant_override("h_separation",14)
	add_theme_constant_override("v_separation",4)
