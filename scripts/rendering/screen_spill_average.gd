extends SubViewport
## Tiny GPU-only colour reduction, shared by both eyes and every cabinet part.
var material := ShaderMaterial.new()
var source_texture: Texture2D

func _init() -> void:
	size = Vector2i(2, 2)
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	material.shader = preload("res://shaders/screen_average.gdshader")
	var rect := ColorRect.new()
	rect.size = Vector2(2, 2)
	rect.material = material
	add_child(rect)

func set_signal(texture: Texture2D) -> void:
	source_texture = texture
	material.set_shader_parameter("signal_texture", texture)
