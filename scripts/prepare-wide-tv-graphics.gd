extends SceneTree
## Rasterise the extracted vector once for Blender and the opaque game material.
func _initialize():
	var image := Image.new()
	var error := image.load_svg_from_string(FileAccess.get_file_as_string("res://artwork/widescreen-crt/graphics.svg"))
	if error == OK: error = image.save_png("res://artwork/widescreen-crt/graphics-mask.png")
	quit(0 if error == OK else 1)
