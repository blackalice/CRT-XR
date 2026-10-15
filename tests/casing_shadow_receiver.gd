extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if ok:print("PASS: ",message)
 else:
  failures+=1
  push_error(message)
func texture(colour:Color)->ImageTexture:
 var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
 image.fill(colour)
 return ImageTexture.create_from_image(image)
func run():
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var view:=SubViewport.new()
 view.size=Vector2i(128,128)
 view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 view.positional_shadow_atlas_size=2048
 root.add_child(view)
 var camera:=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=2
 camera.position=Vector3(0,0,4)
 view.add_child(camera)
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color.BLACK
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE
 env.environment.ambient_light_energy=.3
 view.add_child(env)
 var receiver:=MeshInstance3D.new()
 var quad:=QuadMesh.new()
 quad.size=Vector2(2,2)
 receiver.mesh=quad
 var pbr:=StandardMaterial3D.new()
 pbr.albedo_color=Color(.4,.4,.4)
 pbr.roughness=.7
 receiver.material_override=pbr
 view.add_child(receiver)
 var caster:=MeshInstance3D.new()
 var box:=BoxMesh.new()
 box.size=Vector3(.4,.4,.4)
 caster.mesh=box
 caster.position=Vector3(.6,0,.8)
 var plastic:=ShaderMaterial.new()
 plastic.shader=load("res://shaders/cabinet_plastic.gdshader")
 plastic.set_shader_parameter("albedo_map",texture(Color(.4,.4,.4)))
 plastic.set_shader_parameter("surface_map",texture(Color(1,.5,0)))
 plastic.set_shader_parameter("has_normal",false)
 caster.material_override=plastic
 view.add_child(caster)
 var key:=SpotLight3D.new()
 key.position=Vector3(1.5,0,3)
 key.spot_range=6
 key.spot_angle=48
 key.light_energy=3
 key.shadow_enabled=true
 view.add_child(key)
 key.look_at(Vector3.ZERO)
 var images:Array[Image]=[]
 for phase in ['cast','no_cast']:
  caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if phase!='no_cast' else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  receiver.material_override=pbr
  key.shadow_enabled=true
  for i in range(5):await process_frame
  RenderingServer.force_draw(false)
  images.append(view.get_texture().get_image())
 var largest:=0.0
 var coordinate:=Vector2i.ZERO
 for y in range(12,116):
  for x in range(12,116):
   var difference:=images[1].get_pixel(x,y).r-images[0].get_pixel(x,y).r
   if difference>largest:
    largest=difference
    coordinate=Vector2i(x,y)
 check(largest>.05,"Casing still casts a visible shadow onto a normal receiver")
 # Re-render this same receiving plane with the casing material: it should
 # match its unshadowed result even while the occluding box remains present.
 receiver.material_override=plastic
 var comparison:Array[Image]=[]
 for enabled in [true,false]:
  key.shadow_enabled=true
  caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for i in range(5):await process_frame
  RenderingServer.force_draw(false)
  comparison.append(view.get_texture().get_image())
 var a:=comparison[0].get_pixelv(coordinate)
 var b:=comparison[1].get_pixelv(coordinate)
 check(absf(a.r-b.r)<.01,"Casing material receives lighting without the dynamic shadow patches")
 plastic.set_shader_parameter("surface_map",texture(Color(.15,.5,0)))
 for i in range(5):await process_frame
 RenderingServer.force_draw(false)
 var occluded:=view.get_texture().get_image().get_pixelv(coordinate)
 check(occluded.r<b.r,"Authored baked occlusion still darkens recessed surfaces")
 plastic.set_shader_parameter("surface_map",texture(Color(1,.5,0)))
 plastic.set_shader_parameter("baked_ao_map",texture(Color(.2,.2,.2)))
 plastic.set_shader_parameter("has_baked_ao",true)
 plastic.set_shader_parameter("baked_ao_strength",.65)
 for i in range(5):await process_frame
 RenderingServer.force_draw(false)
 var baked:=view.get_texture().get_image().get_pixelv(coordinate)
 check(baked.r<b.r-.02,"New baked recess shading remains visible under direct lighting")
 plastic.set_shader_parameter("baked_ao_strength",0.0)
 for i in range(5):await process_frame
 RenderingServer.force_draw(false)
 var disabled:=view.get_texture().get_image().get_pixelv(coordinate)
 check(absf(disabled.r-b.r)<.01,"Baked shading can be turned off without changing the base material")
 print("CASING_SHADOW shadow_difference=",largest," receiver_difference=",absf(a.r-b.r))
 view.free()
 quit(1 if failures else 0)
