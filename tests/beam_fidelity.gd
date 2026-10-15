extends SceneTree
var failures := 0
var picture
var view: SubViewport
var material: ShaderMaterial
func _initialize(): call_deferred("run")
# Submit offscreen frames explicitly: a paused/occluded window can stop
# presenting, even though the test still needs a rendered viewport readback.
func settle():
	for i in range(5): await process_frame
	RenderingServer.force_draw(false)
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1
func capture(cached: bool) -> Image:
	picture.shared_beam_enabled = cached
	picture.refresh()
	await settle()
	return view.get_texture().get_image()
func run():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	view = SubViewport.new()
	view.size = Vector2i(960,720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.05
	camera.position.z = 2
	view.add_child(camera)
	var tube := MeshInstance3D.new()
	tube.mesh = QuadMesh.new()
	tube.mesh.size = Vector2(4.0/3.0,1)
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/crt.gdshader")
	tube.material_override = material
	view.add_child(tube)
	picture = load("res://scripts/rendering/picture_pipeline.gd").new()
	view.add_child(picture)
	var image := Image.create(256,240,false,Image.FORMAT_RGBA8)
	# Original diagnostic content only: colour ramps, sharp edges and dark tones.
	for y in range(240):
		for x in range(256):
			var color := Color(float(x)/255,float(y)/239,float((x+y)%256)/255)
			if y<80: color = Color.WHITE if (x/4)%2 else Color.BLACK
			if y>160: color *= .08
			image.set_pixel(x,y,color)
	picture.configure(material,ImageTexture.create_from_image(image),Rect2(.03,.03,.94,.94),4.0/3.0)
	picture.paused = true
	material.set_shader_parameter("scanlines",.7)
	material.set_shader_parameter("mask_strength",.5)
	material.set_shader_parameter("glow_strength",.4)
	for mode in [0,2]:
		picture.mode = mode
		for sharpness in [1.0,3.0,8.0]:
			picture.set_value("beam_softness",sharpness)
			picture.set_value("brightness",1.3)
			picture.set_value("saturation",.95)
			picture.set_value("temperature",.15)
			var reference := await capture(false)
			var optimized := await capture(true)
			var squared := 0.0
			var count := 0
			var peak := 0.0
			var peak_at := Vector2i.ZERO
			var peak_colors := ""
			for y in range(0,720,2):
				for x in range(0,960,2):
					var a := reference.get_pixel(x,y)
					var b := optimized.get_pixel(x,y)
					for delta in [absf(a.r-b.r),absf(a.g-b.g),absf(a.b-b.b)]:
						squared += delta*delta
						if delta>peak:
							peak=delta
							peak_at=Vector2i(x,y)
							peak_colors=str(a)+" -> "+str(b)
						count += 1
			var rmse := sqrt(squared/count)
			print("BEAM_FIDELITY mode=",mode," sharpness=",sharpness," rmse=",rmse," peak=",peak," at=",peak_at," colors=",peak_colors)
			check(rmse<.012 and peak<.12,"Cached beam closely matches reference at mode %d sharpness %.1f" % [mode,sharpness])
	var frozen_cache: PackedByteArray = picture.beam.get_texture().get_image().get_data()
	image.fill(Color.MAGENTA)
	picture.source_texture.update(image)
	await settle()
	check(picture.beam.get_texture().get_image().get_data()==frozen_cache,"Paused beam cache stops after its requested redraw")
	picture.mode = 0
	picture.paused = false
	picture.set_value("brightness",1)
	picture.set_value("saturation",1)
	picture.set_value("temperature",0)
	picture.set_value("gamma",2.2)
	material.set_shader_parameter("mask_strength",0)
	material.set_shader_parameter("glow_strength",0)
	image.fill(Color.GREEN)
	picture.source_texture.update(image)
	await settle()
	image.fill(Color.RED)
	picture.source_texture.update(image)
	await process_frame
	RenderingServer.force_draw(false)
	var immediate: Color = view.get_texture().get_image().get_pixel(480,360)
	check(immediate.r>.8 and immediate.g<.08,"Shared reconstruction presents the current source in the same rendered frame")
	picture.mode = 2
	picture.refresh()
	image.fill(Color.GREEN)
	picture.source_texture.update(image)
	await settle()
	image.fill(Color.RED)
	picture.source_texture.update(image)
	await process_frame
	RenderingServer.force_draw(false)
	immediate = view.get_texture().get_image().get_pixel(480,360)
	check(immediate.r>.7 and immediate.g<.2,"Composite decoder and shared beam both present the current frame")
	material.set_shader_parameter("scanlines",0)
	await settle()
	check(not picture.beam_active and picture.beam.render_target_update_mode==SubViewport.UPDATE_DISABLED,"No beam pass is rendered when scanlines are disabled")
	quit(1 if failures else 0)
