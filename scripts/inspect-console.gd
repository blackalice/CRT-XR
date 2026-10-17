extends SceneTree
func _initialize():call_deferred("run")
func run():
 for source in ["console-1k.glb","console-4k.glb"]:
  var doc:=GLTFDocument.new();var state:=GLTFState.new()
  assert(doc.append_from_file(ProjectSettings.globalize_path("res://build/console-source/"+source),state)==OK)
  var scene:=doc.generate_scene(state);root.add_child(scene)
  print("SOURCE ",source)
  for part in scene.find_children("*","MeshInstance3D",true,false):print(part.get_parent().name," ",part.global_transform*part.get_aabb()," tris ",part.mesh.surface_get_array_index_len(0)/3)
  var mat:StandardMaterial3D=scene.find_children("*","MeshInstance3D",true,false)[0].get_active_material(0)
  for c in range(BaseMaterial3D.TEXTURE_MAX):
   var texture:=mat.get_texture(c)
   if texture!=null:print("TEXTURE ",c," ",texture.get_size())
  scene.free()
 var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 var table:MeshInstance3D=app.world.television.get_node("TelevisionSupport/TopShelf")
 print("TABLE TV LOCAL ",app.world.television.global_transform.affine_inverse()*table.global_transform*table.get_aabb())
 print("TV ",app.world.imported_screen.cabinet_bounds)
 app.free();quit.call_deferred()
