extends SceneTree
const Plastic=preload("res://scripts/rendering/cabinet_plastic.gd")
var failures:=0
var view:SubViewport
var plane:MeshInstance3D
var camera:Camera3D
var material:ShaderMaterial
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if ok:print("PASS: ",message)
 else:
  push_error(message)
  failures+=1
func texture(colour:Color)->ImageTexture:
 var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
 image.fill(colour)
 return ImageTexture.create_from_image(image)
func pixel()->float:
 for i in range(3):await process_frame
 RenderingServer.force_draw(false)
 return view.get_texture().get_image().get_pixel(128,128).r
func variance(values:Array[float])->float:
 var mean:=0.0
 for value in values:mean+=value/values.size()
 var total:=0.0
 for value in values:total+=pow(value-mean,2)/values.size()
 return total
func motion(size:float,strength:float)->Array[float]:
 camera.size=size
 material.set_shader_parameter("grain_strength",strength)
 var samples:Array[float]=[]
 for i in range(12):
  plane.position.x=float(i)*.0007
  samples.append(await pixel())
 return samples
func run():
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var grain:=Plastic.make_grain_texture()
 check(grain==Plastic.make_grain_texture(),"Casing parts share one cached grain texture")
 check(grain.get_size()==Vector2(256,256) and grain.get_image().has_mipmaps(),"Small original grain texture includes mip levels")
 view=SubViewport.new()
 view.own_world_3d=true
 view.size=Vector2i(256,256)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 camera=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.position.z=2
 view.add_child(camera)
 var environment:=WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color.BLACK
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.WHITE
 environment.environment.ambient_light_energy=.3
 view.add_child(environment)
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-25,30,0)
 light.light_energy=1.2
 view.add_child(light)
 plane=MeshInstance3D.new()
 plane.mesh=QuadMesh.new()
 material=ShaderMaterial.new()
 material.shader=Plastic.SHADER
 material.set_shader_parameter("albedo_map",texture(Color(.3,.3,.3)))
 material.set_shader_parameter("surface_map",texture(Color(1,.4,0)))
 material.set_shader_parameter("has_normal",false)
 material.set_shader_parameter("has_grain",true)
 material.set_shader_parameter("grain_map",grain)
 plane.material_override=material
 view.add_child(plane)
 var smooth:=await motion(.08,0)
 var close:=await motion(.08,.4)
 var distant:=await motion(20,.4)
 var smooth_variance:=variance(smooth)
 var close_variance:=variance(close)
 var far_variance:=variance(distant)
 print("PLASTIC_GRAIN variance smooth=",smooth_variance," close=",close_variance," distant=",far_variance)
 check(smooth_variance<.000001 and close_variance>.000001,"Resolved grain adds subtle stable material detail; zero removes it")
 check(far_variance<.000001 and far_variance<close_variance*.1,"Minified grain stays stable during subpixel movement")
 plane.position.x=0
 camera.size=.08
 material.set_shader_parameter("grain_strength",.4)
 var first:=await pixel()
 var second:=await pixel()
 check(first==second,"Grain is static rather than animated noise")
 view.free()
 quit(1 if failures else 0)
