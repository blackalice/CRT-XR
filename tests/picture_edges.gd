extends SceneTree
## Compare final pixels against the old hard picture cutoff at an oblique angle.
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func capture() -> Image:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run():
	root.size=Vector2i(960,540);root.msaa_3d=Viewport.MSAA_DISABLED
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera)
	camera.position=Vector3(.20,.07,2);camera.look_at(Vector3.ZERO);camera.rotation.z=.091;camera.fov=42
	var mesh:=MeshInstance3D.new();scene.add_child(mesh)
	mesh.mesh=QuadMesh.new();mesh.mesh.size=Vector2(1.3,.73125)
	var material:=ShaderMaterial.new();mesh.material_override=material
	var shader: Shader=load("res://shaders/crt.gdshader");material.shader=shader
	var image:=Image.create(128,128,false,Image.FORMAT_RGB8);image.fill(Color.WHITE)
	material.set_shader_parameter("signal_texture",ImageTexture.create_from_image(image))
	for key in ["scanlines","mask_strength","glow_strength","vignette"]: material.set_shader_parameter(key,0.0)
	material.set_shader_parameter("power_progress",1.0)
	material.set_shader_parameter("picture_rect",Vector4(.08,.08,.84,.84))
	var smoothed:=await capture()
	var reference:=Shader.new()
	reference.code=shader.code.replace("-edge_pixel*0.5","vec2(0)").replace("vec2(1)+edge_pixel*0.5","vec2(1)").replace("color *= edge_coverage.x*edge_coverage.y;","")
	material.shader=reference
	var hard:=await capture()
	var changed:=0;var interior:=0;var fractional:=0
	for y in range(hard.get_height()):
		for x in range(hard.get_width()):
			var a:=hard.get_pixel(x,y);var b:=smoothed.get_pixel(x,y)
			if absf(a.r-b.r)>.008:
				changed+=1
				if x>380 and x<560 and y>240 and y<300: interior+=1
				if b.r>.03 and b.r<.97: fractional+=1
	check(changed>200 and changed<960*540*.02,"Smoothing changes only a narrow picture boundary (%d pixels)" % changed)
	check(fractional>200,"Border has partial pixel coverage without MSAA")
	check(interior==0,"Interior image pixels remain unchanged")
	smoothed.save_png("res://build/display-edges-smoothed.png")
	hard.save_png("res://build/display-edges-reference.png")
	scene.free();quit(1 if failures else 0)
