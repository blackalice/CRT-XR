extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func run():
	# Synthetic quad only: no licensed cabinet/model/texture in this test.
	RenderingServer.set_default_clear_color(Color.BLACK)
	var view := SubViewport.new(); view.size=Vector2i(256,192); view.world_3d=World3D.new(); root.add_child(view)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2; view.add_child(camera); camera.current=true
	var quad := MeshInstance3D.new(); var mesh := QuadMesh.new(); mesh.size=Vector2(2,1.5); quad.mesh=mesh; quad.position.z=-2; view.add_child(quad)
	var material := ShaderMaterial.new(); material.shader=load("res://shaders/crt.gdshader"); quad.material_override=material
	var signal_image := Image.create(16,16,false,Image.FORMAT_RGBA8); signal_image.fill(Color(.5,.5,.5))
	material.set_shader_parameter("signal_texture",ImageTexture.create_from_image(signal_image))
	material.set_shader_parameter("picture_rect",Vector4(0,0,1,1))
	for key in ["scanlines","mask_strength","glow_strength","vignette"]: material.set_shader_parameter(key,0.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/power-review"))
	var luminances: Array[float]=[]
	for step in [0.0,.08,.20,.50,1.0]:
		material.set_shader_parameter("power_progress",step)
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		image.save_png("res://build/power-review/tube-%.2f.png" % step)
		var sum := 0.0
		for y in range(image.get_height()):
			for x in range(image.get_width()): sum+=image.get_pixel(x,y).r
		luminances.append(sum/(image.get_width()*image.get_height()))
	print("SYNTHETIC TUBE MEAN BRIGHTNESS: ",luminances)
	if luminances[0]>.001 or luminances[-1]<.10: failures+=1
	for i in range(1,luminances.size()):
		if luminances[i]+.0001<luminances[i-1] or luminances[i]>luminances[-1]+.001: failures+=1
	print("POWER ON VISUAL CHECKS COMPLETE: ",failures," failures")
	view.free(); quit(1 if failures else 0)
