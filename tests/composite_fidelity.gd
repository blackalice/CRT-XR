extends SceneTree
var failures := 0
func _initialize():call_deferred("run")
func settle():
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
func run():
	var source := Image.create(256,240,false,Image.FORMAT_RGBA8)
	for y in range(240):
		for x in range(256):source.set_pixel(x,y,Color(float(x%17)/16,float(y%19)/18,float((x+y)%23)/22))
	var texture := ImageTexture.create_from_image(source)
	var views: Array[SubViewport] = []
	var materials: Array[ShaderMaterial] = []
	var reference_path:="res://tests/fixtures/analog_reference.gdshader"
	if not ResourceLoader.exists(reference_path):reference_path=get_script().resource_path.get_base_dir().path_join("analog_reference.gdshader")
	for path in [reference_path,"res://shaders/analog_signal.gdshader"]:
		var view := SubViewport.new()
		view.disable_3d = true
		view.size = Vector2i(1024,240)
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var material := ShaderMaterial.new()
		material.shader = load(path)
		material.set_shader_parameter("source_texture",texture)
		material.set_shader_parameter("source_size",Vector2(256,240))
		material.set_shader_parameter("composite_strength",1)
		material.set_shader_parameter("artifact_strength",1)
		material.set_shader_parameter("phase_noise",.48)
		material.set_shader_parameter("signal_motion",.45)
		var rect:=ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.material=material
		view.add_child(rect)
		views.append(view)
		materials.append(material)
	for mode in [1,2]:
		for frame in [0,1,20]:
			for material in materials:
				material.set_shader_parameter("signal_standard",mode)
				material.set_shader_parameter("frame_index",frame)
			await settle()
			var reference:=views[0].get_texture().get_image().get_data()
			var optimized:=views[1].get_texture().get_image().get_data()
			var squared:=0.0
			var peak:=0
			for index in range(reference.size()):
				var delta:=absi(int(reference[index])-int(optimized[index]))
				peak=maxi(peak,delta)
				squared+=delta*delta
			var rmse:=sqrt(squared/reference.size())/255.0
			print("COMPOSITE_FIDELITY mode=",mode," frame=",frame," rmse=",rmse," peak_8bit=",peak)
			if peak>2 or rmse>.002:
				failures+=1
				push_error("Carrier rotation differs excessively from the reference")
			else:print("PASS: Quarter-cycle carrier preserves decoded colours and distortion")
	quit(1 if failures else 0)
