extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
    print("PASS: " if ok else "FAIL: ",label)
    if not ok:failures+=1
func run():
    var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
    var stand:Node3D=app.world.television.get_node("TelevisionSupport")
    var parts:=stand.find_children("*","MeshInstance3D",true,false)
    check(parts.size()==1,"Only the fourth table is present; old shelf and props are removed")
    var table:MeshInstance3D=parts[0]
    check(table.mesh.get_surface_count()==1,"Table retains one material surface")
    check(table.mesh.surface_get_array_index_len(0)/3==3272,"All 3272 authored table triangles are retained")
    var material:=table.get_active_material(0) as StandardMaterial3D
    check(material!=null and material.albedo_texture!=null and material.normal_texture!=null,"Authored wood colour and normal textures are retained")
    check(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"Mipmaps and anisotropic filtering keep wood stable at distance")
    var image:=material.albedo_texture.get_image()
    check(image.has_mipmaps() and image.is_compressed() and image.get_width()==2048,"Table textures are compressed and limited to 2K")
    check(table.material_overlay==app.world.distance_fade,"Table uses the existing distance fade")
    var bounds:AABB=stand.global_transform*table.transform*table.get_aabb()
    var relative:AABB=app.world.television.global_transform.affine_inverse()*bounds
    check(absf(relative.position.y-app.world.support_floor_y)<.001,"Feet meet the adjusted floor reference")
    check(table.scale.is_equal_approx(Vector3.ONE*table.scale.x),"Original table proportions are preserved")
    # Inspect only furniture in the preview below, never the licensed CRT.
    var view:=SubViewport.new();view.size=Vector2i(960,720);view.world_3d=World3D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var furniture:Node3D=stand.duplicate();furniture.position=Vector3.ZERO;view.add_child(furniture)
    var surface:MeshInstance3D=furniture.get_node("TopShelf");surface.material_overlay=null
    var camera:=Camera3D.new();camera.position=Vector3(2.2,1.4,2.7);view.add_child(camera);camera.look_at(Vector3(0,.3,0));camera.fov=40;camera.current=true
    var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.07,.075,.08);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;view.add_child(env)
    var light:=DirectionalLight3D.new();view.add_child(light);light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.8
    for i in range(5):await process_frame
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute("res://build/table-review")
        view.get_texture().get_image().save_png("res://build/table-review/table-only.png")
    view.free();app.free()
    for i in range(3):await process_frame
    print("WOOD TABLE CHECKS COMPLETE: ",failures," failures")
    quit.call_deferred(1 if failures else 0)
