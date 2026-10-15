extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1
func run():
	var model := "res://build/crt-model/crt_tv.glb"
	var before := FileAccess.get_sha256(model)
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.close_settings()
	app.use_tracking(false)
	await process_frame
	app.set_process(false)
	var world = app.world
	check(not world.imported_screen.is_empty(),"User-supplied cabinet loads for numeric inspection only")
	if world.imported_screen.is_empty():
		app.free()
		quit(1)
		return
	var bounds: AABB = world.imported_screen.cabinet_bounds
	var screen: MeshInstance3D = world.television.get_node("PhosphorSurface")
	var glass: MeshInstance3D = world.television.get_node("GlassFaceplate")
	var stand: Node3D = world.television.get_node("TelevisionSupport")
	var shelf: MeshInstance3D = stand.get_node("TopShelf")
	var top: AABB = world.television.global_transform.affine_inverse()*shelf.global_transform*shelf.get_aabb()
	check(absf(screen.position.x)<.0001 and absf(bounds.get_center().x-screen.position.x)<.002,"Live picture and physical casing share the centred viewing axis")
	check(absf(top.get_center().x-bounds.get_center().x)<.0001,"TV casing is centred left/right on the shelf")
	check(absf(top.get_center().z-bounds.get_center().z)<.0001,"Shelf is centred under the full CRT depth")
	check(bounds.position.z-top.position.z>.095 and top.end.z-bounds.end.z>.095,"Shelf supports the rear and front with at least 9.5 cm of margin")
	check(absf(top.end.y-bounds.position.y)<.0001,"TV sits on the shelf without a gap or intersection")
	check(glass.position.is_equal_approx(screen.position+Vector3(0,0,.006)),"Glass remains registered to the centred phosphor surface")
	check(absf((world.screen_light.lights[0].position.x+world.screen_light.lights[1].position.x)*.5-screen.position.x)<.0001,"Picture-driven lights remain centred on the tube")
	var casing_count := 0
	var metal_count := 0
	for part in world.television.get_node("ImportedCabinet").find_children("*","MeshInstance3D",true,false):
		var actual: Material = part.get_active_material(0)
		var original := part.mesh.surface_get_material(0) as StandardMaterial3D
		if str(part.get_parent().name) in ["Front_section","Front_buttons","rear_section"]:
			casing_count += 1
			check(actual is ShaderMaterial and actual.get_shader_parameter("albedo_map")==original.albedo_texture and actual.get_shader_parameter("normal_map")==original.normal_texture,"Casing keeps the authored colour/normal textures on "+str(part.get_parent().name))
			var baked: Texture2D = actual.get_shader_parameter("baked_ao_map")
			check(actual.get_shader_parameter("has_baked_ao") and baked != null and baked.get_width()==2048 and baked.get_image().get_format()==Image.FORMAT_L8 and baked.get_image().has_mipmaps(),"Blender bake loads as filtered single-channel data on "+str(part.get_parent().name))
			check(actual.get_shader_parameter("surface_map")==original.roughness_texture and original.roughness_texture.get_image().has_mipmaps(),"Casing retains packed surface detail and mip filtering on "+str(part.get_parent().name))
		elif str(part.get_parent().name) in ["AV_front","AV_back","Screw","Coax_connector"]:
			metal_count += 1
			check(actual==original and actual is StandardMaterial3D,"Hardware keeps its original material: "+str(part.get_parent().name))
	check(casing_count==3 and metal_count==1,"Casing and retained front hardware were checked")
	check(FileAccess.get_sha256(model)==before,"Original GLB remains byte-for-byte unchanged")
	app.distance_save_delay = -1
	app.free()
	quit(1 if failures else 0)
