extends SceneTree
const Pipeline=preload("res://scripts/rendering/picture_pipeline.gd")
var failures:=0
func _initialize():call_deferred("run")
func run():
	var image:=Image.create(256,64,false,Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(256):image.set_pixel(x,y,Color(float(x)/255,float(y)/63,float((x+y)%256)/255))
	var texture:=ImageTexture.create_from_image(image)
	var views:Array[SubViewport]=[]
	var materials:Array[ShaderMaterial]=[]
	var reference_path:="res://tests/fixtures/crt_colour_reference.gdshaderinc"
	if not FileAccess.file_exists(reference_path):reference_path=get_script().resource_path.get_base_dir().path_join("crt_colour_reference.gdshaderinc")
	for include in [reference_path,"res://shaders/include/crt_colour.gdshaderinc"]:
		var view:=SubViewport.new()
		view.size=Vector2i(256,64)
		view.disable_3d=true
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var shader:=Shader.new()
		shader.code='shader_type canvas_item; render_mode unshaded,blend_disabled; uniform sampler2D signal_texture : source_color,filter_linear;\n#include "'+include+'"\nvoid fragment(){COLOR=vec4(pow(clamp(grade_rgb(texture(signal_texture,UV).rgb),vec3(0),vec3(1)),vec3(1.0/2.2)),1);}'
		var material:=ShaderMaterial.new()
		material.shader=shader
		material.set_shader_parameter("signal_texture",texture)
		var rect:=ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.material=material
		view.add_child(rect)
		views.append(view)
		materials.append(material)
	for setting in [{"hue":0.0,"saturation":.95,"gamma":2.25,"brightness":1.3,"contrast":1.0,"temperature":.15},{"hue":30.0,"saturation":1.5,"gamma":2.8,"brightness":1.5,"contrast":1.4,"temperature":1.0},{"hue":-30.0,"saturation":0.0,"gamma":1.6,"brightness":.5,"contrast":.6,"temperature":-1.0}]:
		for material in materials:
			for key in ["saturation","gamma","brightness","contrast"]:material.set_shader_parameter(key,setting[key])
			material.set_shader_parameter("hue_rotation",Vector2(cos(deg_to_rad(setting.hue)),sin(deg_to_rad(setting.hue))))
			material.set_shader_parameter("white_balance",Vector3(1+setting.temperature*.08,1,1-setting.temperature*.1))
		materials[1].set_shader_parameter("colour_matrix",Pipeline.colour_basis_for(setting))
		for i in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var old:=views[0].get_texture().get_image().get_data()
		var current:=views[1].get_texture().get_image().get_data()
		var peak:=0
		for i in range(old.size()):peak=maxi(peak,absi(int(old[i])-int(current[i])))
		print("COLOUR_FIDELITY peak_8bit=",peak," settings=",setting)
		if peak>1:
			failures+=1
			push_error("Composed colour matrix changed output")
		else:print("PASS: Composed colour transform preserves the original grading")
	quit(1 if failures else 0)
