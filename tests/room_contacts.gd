extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
    print("PASS: " if ok else "FAIL: ",label)
    if not ok:failures+=1
func run():
    var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
    var w=app.world;var support:Node3D=w.television.get_node("TelevisionSupport");var table:MeshInstance3D=support.get_node("TopShelf")
    check(support.get_meta("contact_bake",false),"Matching contact bake is enabled")
    var material:=table.get_active_material(0) as StandardMaterial3D
    check(not material.ao_enabled and material.has_meta("contact_baked_into_colour"),"Table combines baked contact shading into its existing PBR colour")
    check(w.floor_material.get_shader_parameter("contact_enabled"),"Carpet samples the baked floor contacts")
    check(w.floor_material.get_shader_parameter("carpet_colour").get_image().has_mipmaps(),"Carpet colour uses mipmaps to avoid shimmer")
    check(w.floor_material.get_shader_parameter("carpet_normal").get_image().has_mipmaps(),"Carpet normals use mipmaps to avoid shimmer")
    check(preload("res://scripts/rendering/room_contacts.gd").texture("table_ao.png").get_image().has_mipmaps(),"Contact maps have filtered mip levels")
    var all_static:=true
    for node in w.television.find_children("*","MeshInstance3D",true,false):
        if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:all_static=false
    check(all_static,"Static shapes avoid aliasing live shadow maps")
    var floor_image:Image=w.floor_material.get_shader_parameter("contact_ao").get_image()
    var table_image:Image=preload("res://scripts/rendering/room_contacts.gd").texture("table_ao.png").get_image()
    var vertices:PackedVector3Array=table.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=table.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
    var uv:PackedVector2Array=table.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
    var indices:PackedInt32Array=table.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
    var transform:Transform3D=w.television.global_transform.affine_inverse()*table.global_transform
    var feet:Array[float]=[];var centre:Array[float]=[];var outside:Array[float]=[]
    var casing:AABB=w.imported_screen.cabinet_bounds
    for vertex in vertices:
        var p:Vector3=transform*vertex
        if p.y>w.support_floor_y+.005:continue
        var fuv:Vector2=(Vector2(p.x,p.z)-Vector2(-3,-2.5))/Vector2(6,5)
        feet.append(floor_image.get_pixelv(Vector2i(fuv*Vector2(floor_image.get_size()))).r)
    for i in range(0,indices.size(),3):
        var a:=indices[i];var b:=indices[i+1];var c:=indices[i+2]
        var p:Vector3=transform*((vertices[a]+vertices[b]+vertices[c])/3.0)
        var normal:Vector3=transform.basis*(normals[a]+normals[b]+normals[c])/3.0
        if p.y<casing.position.y-.005 or normal.y<.8:continue
        var tuv:Vector2=(uv[a]+uv[b]+uv[c])/3.0
        var value:=table_image.get_pixelv(Vector2i(tuv*Vector2(table_image.get_size())).clamp(Vector2i.ZERO,table_image.get_size()-Vector2i.ONE)).r
        if p.x>casing.position.x+.1 and p.x<casing.end.x-.1 and p.z>casing.position.z+.1 and p.z<casing.end.z-.1:centre.append(value)
        elif p.x<casing.position.x-.04 or p.x>casing.end.x+.04:outside.append(value)
    var foot_mean:float=feet.reduce(func(a,b):return a+b,0.0)/maxi(1,feet.size())
    var centre_mean:float=centre.reduce(func(a,b):return a+b,0.0)/maxi(1,centre.size())
    var outside_mean:float=outside.reduce(func(a,b):return a+b,0.0)/maxi(1,outside.size())
    print("CONTACT SAMPLES feet=",foot_mean," underTV=",centre_mean," outside=",outside_mean," sample counts=",[feet.size(),centre.size(),outside.size()])
    check(feet.size()>0 and foot_mean<.85,"Baked floor darkening is aligned beneath the actual feet")
    check(centre.size()>0 and outside.size()>0 and centre_mean<outside_mean-.05,"Table UV bake darkens beneath the TV more than the exposed tabletop")
    var far:=floor_image.get_pixel(10,10).r
    check(far>.95,"Carpet away from furniture stays unshadowed")
    var old_rect:Vector4=w.floor_material.get_shader_parameter("contact_rect")
    app.distance=2.0;app.height_offset=.3;app.tv_scale=1.2
    for i in range(4):await process_frame
    check(w.floor_material.get_shader_parameter("contact_rect")==old_rect and absf(w.floor_node.position.y-(w.television.position.y+(w.support_floor_y-.01)*w.television.scale.y))<.001,"Contact maps stay registered when distance, height and scale change")
    # Carpet-only preview; the licensed TV model is never included in inspection.
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.world_3d=World3D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var carpet:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(4,4);carpet.mesh=plane
    var preview_material:ShaderMaterial=w.floor_material.duplicate();preview_material.set_shader_parameter("contact_enabled",false);preview_material.set_shader_parameter("fade_begin",20.0);preview_material.set_shader_parameter("fade_end",30.0);carpet.material_override=preview_material;view.add_child(carpet)
    var camera:=Camera3D.new();camera.position=Vector3(0,1.2,1.6);view.add_child(camera);camera.look_at(Vector3.ZERO);camera.current=true
    var light:=DirectionalLight3D.new();view.add_child(light);light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=2
    var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.4;view.add_child(env)
    for i in range(5):await process_frame
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute("res://build/carpet-review")
        view.get_texture().get_image().save_png("res://build/carpet-review/carpet-only.png")
    view.free();app.free()
    for i in range(3):await process_frame
    print("ROOM CONTACT CHECKS COMPLETE: ",failures," failures")
    quit.call_deferred(1 if failures else 0)
