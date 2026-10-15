extends SceneTree
var failures := 0
var view: SubViewport
var tube: MeshInstance3D
var picture: Node
var material: ShaderMaterial
func check(ok: bool,message: String):
	if ok: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1
func _initialize(): call_deferred("run")
func settle():
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
func image_texture(size: Vector2i, color: Color) -> ImageTexture:
	var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
func run():
	view = SubViewport.new()
	view.size = Vector2i(640,480)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.1
	camera.position.z = 2
	view.add_child(camera)
	tube = MeshInstance3D.new()
	tube.mesh = QuadMesh.new()
	tube.mesh.size = Vector2(4.0/3.0,1)
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/crt.gdshader")
	material.set_shader_parameter("scanlines",0)
	material.set_shader_parameter("mask_strength",0)
	material.set_shader_parameter("glow_strength",0)
	tube.material_override = material
	view.add_child(tube)
	picture = load("res://scripts/rendering/picture_pipeline.gd").new()
	view.add_child(picture)
	picture.configure(material,image_texture(Vector2i(256,240),Color(.5,.5,.5)),Rect2(.06,.06,.88,.88),4.0/3.0)
	picture.set_value("gamma",2.2)
	picture.set_value("vignette",0)
	picture.paused = true
	await settle()
	var neutral: Color = view.get_texture().get_image().get_pixel(320,240)
	check(absf(neutral.r-.5)<.025,"Neutral gamma preserves a mid-gray source")
	picture.set_value("gamma",1.8)
	await settle()
	var lighter: Color = view.get_texture().get_image().get_pixel(320,240)
	check(lighter.r>neutral.r+.04,"Lower display gamma lightens midtones")
	picture.set_value("gamma",2.2)
	picture.mode = 2
	picture.refresh()
	await settle()
	var pal: Color = view.get_texture().get_image().get_pixel(320,240)
	print("MID_GRAY rgb=",neutral," pal=",pal)
	check(absf(pal.r-pal.g)<.08 and absf(pal.g-pal.b)<.08,"PAL decoder keeps gray approximately neutral")
	picture.mode = 1
	picture.refresh()
	await settle()
	var ntsc: Color = view.get_texture().get_image().get_pixel(320,240)
	check(absf(ntsc.r-ntsc.g)<.08 and absf(ntsc.g-ntsc.b)<.08,"NTSC decoder keeps gray approximately neutral")
	picture.set_value("signal_motion",1)
	var frozen: float = picture.elapsed
	await settle()
	check(is_equal_approx(picture.elapsed,frozen),"Paused composite signal has no moving carrier or noise")
	check(material.get_shader_parameter("signal_texture") == picture.decode.get_texture(),"Analog mode binds one shared decoded texture")
	picture.mode = 0
	picture.refresh()
	check(picture.decode.render_target_update_mode == SubViewport.UPDATE_DISABLED,"RGB bypasses the analog rendering pass")
	for size in [Vector2i(256,224),Vector2i(256,240),Vector2i(512,448),Vector2i(512,478)]:
		picture.set_source(image_texture(size,Color.WHITE))
		for x in [-1.0,0.0,1.0]:
			for y in [-1.0,0.0,1.0]:
				picture.set_value("shift_x",x)
				picture.set_value("shift_y",y)
				picture.set_value("width",.6)
				picture.set_value("height",.8)
				var rect: Rect2 = picture.picture_rect()
				check(picture.safe_rect.encloses(rect) and absf(rect.size.x/rect.size.y*picture.tube_aspect-4.0/3.0)<.001,"Complete %s source stays inside tube with locked aspect at %s"%[size,Vector2(x,y)])
	picture.mode = 3
	picture.source_rate = 50.007
	check(picture.effective_mode()==2,"Auto composite chooses PAL for a 50 Hz game")
	picture.source_rate = 60.099
	check(picture.effective_mode()==1,"Auto composite chooses NTSC for a 60 Hz game")
	picture.mode = 1
	picture.refresh()
	await settle()
	check(picture.decode.size==Vector2i(1024,478),"Analog pass follows high-resolution source height")
	quit(1 if failures else 0)
