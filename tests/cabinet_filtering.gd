extends SceneTree
var failures := 0
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1
func _initialize(): call_deferred("run")
func sample_variation(view: SubViewport, mat: StandardMaterial3D) -> float:
	var samples: Array[float] = []
	for step in range(16):
		mat.uv1_offset.x = float(step)/8192.0
		for i in range(2): await process_frame
		await RenderingServer.frame_post_draw
		samples.append(view.get_texture().get_image().get_pixel(48,48).r)
	var mean := 0.0
	for value in samples: mean += value/float(samples.size())
	var variance := 0.0
	for value in samples: variance += pow(value-mean,2)/float(samples.size())
	return variance
func run():
	var view := SubViewport.new()
	view.size = Vector2i(96,96)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1
	camera.position.z = 2
	view.add_child(camera)
	var plane := MeshInstance3D.new()
	plane.mesh = QuadMesh.new()
	plane.mesh.size = Vector2(.3,.3)
	view.add_child(plane)
	var image := Image.create(512,512,false,Image.FORMAT_RGB8)
	for y in range(512):
		for x in range(512): image.set_pixel(x,y,Color.WHITE if (x+y)%2 == 0 else Color.BLACK)
	var tex := ImageTexture.create_from_image(image)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.albedo_texture = tex
	plane.material_override = mat
	var original_variance := await sample_variation(view,mat)
	load("res://scripts/rendering/imported_crt.gd").filter_cabinet_materials(view)
	check(tex.get_image().has_mipmaps(), "Runtime embedded images receive actual mip levels")
	check(mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "Cabinet uses trilinear anisotropic filtering")
	var filtered_variance := await sample_variation(view,mat)
	print("PATTERN_VARIANCE before=",original_variance," after=",filtered_variance)
	check(original_variance > .001 and filtered_variance < original_variance*.1, "Minified grille-like pattern is stable during subpixel motion")
	check(tex.get_image().get_pixel(0,0).r == 1 and tex.get_image().get_pixel(1,0).r == 0, "Full-resolution texture detail remains intact")
	# Verify shared resources are updated once, without accumulating mip levels.
	load("res://scripts/rendering/imported_crt.gd").filter_cabinet_materials(view)
	check(mat.albedo_texture == tex and tex.get_image().get_mipmap_count() == 9, "Filtering is idempotent and preserves shared textures")
	quit(1 if failures else 0)
