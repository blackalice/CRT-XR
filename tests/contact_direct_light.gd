extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func settle():
    for i in range(4):await process_frame
    await RenderingServer.frame_post_draw
func run():
    var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
    var view:=SubViewport.new();view.size=Vector2i(256,256);view.world_3d=World3D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;view.add_child(camera);camera.current=true
    var quad:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=Vector2(2,2);quad.mesh=mesh;quad.position.z=-2;view.add_child(quad)
    var lit:=DirectionalLight3D.new();view.add_child(lit)
    var table:MeshInstance3D=app.world.television.get_node("TelevisionSupport/TopShelf")
    var shaded:=table.get_active_material(0).duplicate() as StandardMaterial3D
    var plain:=shaded.duplicate() as StandardMaterial3D
    plain.albedo_texture=table.mesh.surface_get_material(0).albedo_texture
    for energy in [.3,1.0,3.0,8.0]:
        lit.light_energy=energy
        quad.material_override=plain;await settle();var before:=view.get_texture().get_image()
        quad.material_override=shaded;await settle();var after:=view.get_texture().get_image()
        var affected:=0;var sum:=0.0
        for y in range(32,224,4):
            for x in range(32,224,4):
                var a:=before.get_pixel(x,y).r;var b:=after.get_pixel(x,y).r
                if a>.08 and b<a*.8:affected+=1;sum+=a-b
        print("TABLE DIRECT LIGHT ",energy," visible shadow pixels=",affected," mean drop=",sum/maxi(1,affected))
        if affected<10 or sum/maxi(1,affected)<.02:failures+=1
    camera.position=Vector3(0,5,0);camera.size=6;camera.look_at(Vector3.ZERO,Vector3(0,0,-1))
    var plane:=PlaneMesh.new();plane.size=Vector2(6,5);quad.mesh=plane;quad.position=Vector3.ZERO
    lit.rotation_degrees=Vector3(-90,0,0)
    var floor_mat:ShaderMaterial=app.world.floor_material.duplicate();floor_mat.set_shader_parameter("fade_begin",20.0);floor_mat.set_shader_parameter("fade_end",30.0);quad.material_override=floor_mat
    for energy in [.3,1.0,3.0,8.0]:
        lit.light_energy=energy
        floor_mat.set_shader_parameter("contact_enabled",false);await settle();var before:=view.get_texture().get_image()
        floor_mat.set_shader_parameter("contact_enabled",true);await settle();var after:=view.get_texture().get_image()
        var affected:=0;var sum:=0.0
        for y in range(40,216,2):
            for x in range(32,224,2):
                var a:=before.get_pixel(x,y).r;var b:=after.get_pixel(x,y).r
                if a>.08 and b<a*.8:affected+=1;sum+=a-b
        print("CARPET DIRECT LIGHT ",energy," visible shadow pixels=",affected," mean drop=",sum/maxi(1,affected))
        if affected<10 or sum/maxi(1,affected)<.02:failures+=1
    view.free();app.free()
    for i in range(3):await process_frame
    print("BRIGHT CONTACT GPU CHECKS COMPLETE: ",failures," failures")
    quit.call_deferred(1 if failures else 0)
