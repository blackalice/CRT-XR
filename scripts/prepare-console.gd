extends SceneTree
const OUT := "res://build/console"
const SOURCE := "res://build/console-source/console-1k.glb"
func _initialize():call_deferred("run")
func run():
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 assert(document.append_from_file(ProjectSettings.globalize_path(SOURCE),state)==OK)
 var scene:=document.generate_scene(state);root.add_child(scene)
 var keep:Array[MeshInstance3D]=[];var removed:Array=[];var bounds:=AABB();var first:=true
 for part in scene.find_children("*","MeshInstance3D",true,false):
  var label:=str(part.get_parent().name)
  if label.begins_with("MainController") or label.begins_with("Buttons") or label.begins_with("Holders") or label.begins_with("Ext_"):
   removed.append({"node":label,"triangles":part.mesh.surface_get_array_index_len(0)/3});continue
  keep.append(part)
  var box:AABB=part.global_transform*part.get_aabb()
  bounds=box if first else bounds.merge(box);first=false
 var center:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for part in keep:
  var transform:=part.global_transform;transform.origin-=center
  surface.append_from(part.mesh,0,transform)
 surface.generate_tangents()
 var mesh:=surface.commit()
 var material:StandardMaterial3D=keep[0].get_active_material(0).duplicate()
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 var base:=material.albedo_texture.get_image();if base.is_compressed():base.decompress()
 var ao:=material.ao_texture.get_image();if ao.is_compressed():ao.decompress()
 base.clear_mipmaps()
 # Bake the authored occlusion into linear-light base colour for Compatibility.
 for y in range(base.get_height()):
  for x in range(base.get_width()):
   var colour:=base.get_pixel(x,y).srgb_to_linear()
   var shade:=lerpf(1,ao.get_pixel(x,y).r,.8)
   base.set_pixel(x,y,Color(colour.r*shade,colour.g*shade,colour.b*shade,colour.a).linear_to_srgb())
 material.albedo_texture=ImageTexture.create_from_image(base);material.ao_enabled=false
 material.ao_texture=null # Occlusion is already baked into base colour.
 # Keep the imported roughness detail, but give the dielectric plastic a matte
 # finish. Packed metal pixels retain their authored roughness and metal values.
 var packed_texture:=material.roughness_texture
 var finish_image:=packed_texture.get_image()
 if finish_image.is_compressed():finish_image.decompress()
 finish_image.clear_mipmaps();finish_image.convert(Image.FORMAT_RGBA8)
 for y in range(finish_image.get_height()):
  for x in range(finish_image.get_width()):
   var pixel:=finish_image.get_pixel(x,y)
   var original:float=pixel[material.roughness_texture_channel]
   var metal:float=pixel[material.metallic_texture_channel]*material.metallic
   var plastic:=1.0-smoothstep(.15,.65,metal)
   pixel[material.roughness_texture_channel]=lerpf(original,lerpf(.48,.95,original),plastic)
   finish_image.set_pixel(x,y,pixel)
 var matte:=ImageTexture.create_from_image(finish_image)
 if material.metallic_texture==packed_texture:material.metallic_texture=matte
 material.roughness_texture=matte
 material.metallic_specular=.35
 var cache:Dictionary={};var total:=0;var textures:Array=[]
 for channel in range(BaseMaterial3D.TEXTURE_MAX):
  var texture:=material.get_texture(channel)
  if texture==null:continue
  if cache.has(texture.get_instance_id()):material.set_texture(channel,cache[texture.get_instance_id()]);continue
  var image:=texture.get_image();if image.is_compressed():image.decompress()
  image.clear_mipmaps();image.convert(Image.FORMAT_RGBA8)
  image.generate_mipmaps(channel==BaseMaterial3D.TEXTURE_NORMAL)
  assert(image.compress(Image.COMPRESS_BPTC)==OK)
  var ready:=ImageTexture.create_from_image(image);cache[texture.get_instance_id()]=ready;material.set_texture(channel,ready)
  total+=image.get_data_size();textures.append({"channel":channel,"size":[image.get_width(),image.get_height()],"gpu_bytes":image.get_data_size()})
 mesh.surface_set_material(0,material)
 var console:=MeshInstance3D.new();console.name="SuperRetroConsole";console.mesh=mesh
 var packed:=PackedScene.new();assert(packed.pack(console)==OK)
 DirAccess.make_dir_recursive_absolute(OUT)
 assert(ResourceSaver.save(packed,OUT+"/console.scn",ResourceSaver.FLAG_COMPRESS)==OK)
 var manifest={"finish":{"plastic_roughness_min":.48,"plastic_roughness_max":.95,"dielectric_specular":.35,"metal_mask_preserved":true},"source_sha256":FileAccess.get_sha256(SOURCE),"high_resolution_sha256":FileAccess.get_sha256("res://build/console-source/console-4k.glb"),"triangles":mesh.surface_get_array_index_len(0)/3,"removed":removed,"surfaces":1,"texture_count":cache.size(),"textures":textures,"gpu_texture_bytes_with_mips":total,"author":"ELIZION","license":"CC-BY-4.0","source_url":"https://sketchfab.com/3d-models/super-retro-game-console-d672d0ac1d6a4d238314d6675f8f92b2"}
 var file:=FileAccess.open(OUT+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  "));file.close()
 print("CONSOLE PREPARED ",JSON.stringify(manifest));console.free();scene.free();quit.call_deferred()
