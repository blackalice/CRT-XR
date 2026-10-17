extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 print("PASS: " if ok else "FAIL: ",message)
 if not ok:failures+=1
func run():
 var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 var tv:Node3D=app.world.television
 var prop:Node3D=tv.get_node("ConsoleProp")
 var console:MeshInstance3D=prop.get_node("SuperRetroConsole")
 check(console.mesh.get_surface_count()==1,"Console is one material batch")
 check(console.mesh.surface_get_array_index_len(0)/3==8527,"Controller and underside fittings removed: 8527 triangles")
 var material:StandardMaterial3D=console.get_active_material(0)
 check(material.albedo_texture.get_width()==1024 and material.albedo_texture.get_image().has_mipmaps(),"1K mipmapped console textures")
 var box:AABB=prop.transform*console.transform*console.get_aabb()
 var table:MeshInstance3D=tv.get_node("TelevisionSupport/TopShelf")
 var bounds:AABB=table.get_parent().transform*table.transform*table.get_aabb()
 check(absf(box.position.y-bounds.end.y)<.005,"Console sits on the tabletop")
 check(box.end.x<app.world.imported_screen.cabinet_bounds.position.x,"Console clears the left side of the TV")
 check(box.position.x>bounds.position.x and box.position.z>bounds.position.z and box.end.z<bounds.end.z,"Console stays inside the tabletop")
 var image:=preload("res://scripts/rendering/room_contacts.gd").texture("table_ao.png").get_image()
 var arrays:=table.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var center:=box.get_center();var found:=false;var shade:=1.0
 for i in range(0,indices.size(),3):
  var a:Vector3=table.get_parent().transform*table.transform*vertices[indices[i]]
  var b:Vector3=table.get_parent().transform*table.transform*vertices[indices[i+1]]
  var c:Vector3=table.get_parent().transform*table.transform*vertices[indices[i+2]]
  if absf(a.y-bounds.end.y)>.005 or absf(b.y-bounds.end.y)>.005 or absf(c.y-bounds.end.y)>.005:continue
  var points:=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
  if not Geometry2D.is_point_in_polygon(Vector2(center.x,center.z),points):continue
  var bary:=Geometry3D.get_triangle_barycentric_coords(Vector3(center.x,a.y,center.z),a,b,c)
  var coordinate:Vector2=uv[indices[i]]*bary.x+uv[indices[i+1]]*bary.y+uv[indices[i+2]]*bary.z
  shade=image.get_pixelv(Vector2i(coordinate*Vector2(image.get_size())).clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE)).r;found=true;break
 print("CONSOLE CONTACT SHADE: ",shade)
 check(found and shade<.8,"Rebaked tabletop contact is registered beneath the console")
 for label in ["ConsoleVideoCable","ConsolePowerCable"]:
  var cable:MeshInstance3D=tv.get_node(label)
  check(cable.mesh.surface_get_array_len(0)<3000,label+" uses a small static mesh")
 var view:=SubViewport.new();view.size=Vector2i(800,600);view.world_3d=World3D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var isolated:=console.duplicate() as MeshInstance3D;isolated.transform=Transform3D.IDENTITY;isolated.material_overlay=null;view.add_child(isolated)
 var camera:=Camera3D.new();camera.position=Vector3(1.05,.95,1.5);camera.fov=38;view.add_child(camera);camera.look_at(Vector3(0,.08,0));camera.current=true
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("252a30");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;view.add_child(env)
 var light:=DirectionalLight3D.new();view.add_child(light);light.rotation_degrees=Vector3(-50,-30,0);light.light_energy=1.4
 for i in range(6):await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  view.get_texture().get_image().save_png("res://build/console/console-only.png")
 view.free();app.free();await create_timer(.15).timeout
 print("CONSOLE CHECKS COMPLETE: ",failures," failures");quit.call_deferred(1 if failures else 0)
