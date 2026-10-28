extends RefCounted
## Static console and two low-poly rear cables. Placement is relative to TV/table.
const Platform = preload("res://scripts/platform/platform.gd")
static func cable(parent: Node3D, points: PackedVector3Array, radius: float, label: String) -> void:
 var curve:=Curve3D.new()
 for i in range(points.size()):
  var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)])*.18
  curve.add_point(points[i],-tangent,tangent)
 var sample:=curve.tessellate(2,12)
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(sample.size()-1):
  var axis:Vector3=(sample[i+1]-sample[i]).normalized()
  var side:=axis.cross(Vector3.UP).normalized()
  if side.length_squared()<.1:side=Vector3.RIGHT
  var up:=axis.cross(side).normalized()
  for ring in range(6):
   var a:=TAU*ring/6;var b:=TAU*(ring+1)/6
   var na:=side*cos(a)+up*sin(a);var nb:=side*cos(b)+up*sin(b)
   for pair in [[i,na],[i+1,na],[i,nb],[i,nb],[i+1,na],[i+1,nb]]:
    surface.set_normal(pair[1]);surface.add_vertex(sample[pair[0]]+pair[1]*radius)
 var part:=MeshInstance3D.new();part.name=label;part.mesh=surface.commit()
 var material:=StandardMaterial3D.new();material.albedo_color=Color("222125");material.roughness=.9
 part.material_override=material;part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(part)
static func build(tv: Node3D, support: Node3D, cabinet: AABB) -> Node3D:
 var path:=Platform.asset("console/console.scn","console/console.scn")
 if not FileAccess.file_exists(path) or not support.has_node("TopShelf"):return null
 var part:=load(path).instantiate() as MeshInstance3D
 if part==null:return null
 var table:MeshInstance3D=support.get_node("TopShelf")
 var table_transform:=support.transform*table.transform
 var top_bounds:AABB=table_transform*table.get_aabb()
 var available:=cabinet.position.x-top_bounds.position.x
 var width:=minf(cabinet.size.x*.48,available-.12)
 if width<.25:part.free();return null
 var prop:=Node3D.new();prop.name="ConsoleProp";tv.add_child(prop);prop.add_child(part)
 var scale:=width/part.get_aabb().size.x
 part.scale=Vector3.ONE*scale
 var box:AABB=part.transform*part.get_aabb()
 prop.position=Vector3(cabinet.position.x-.07-width*.5,top_bounds.end.y+.001,top_bounds.end.z-.07-box.size.z*.5)
 prop.rotation.y=deg_to_rad(-3)
 part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var back:=prop.position+Vector3(.04,box.size.y*.35,-box.size.z*.5)
 # Routes stay outside the casing, then disappear behind the table.
 cable(tv,PackedVector3Array([back,back+Vector3(0,0,-.10),Vector3(back.x-.02,back.y,top_bounds.position.z+.03),Vector3(cabinet.position.x+.12,back.y,cabinet.position.z-.03)]),.006,"ConsoleVideoCable")
 var end:=Vector3(back.x-.10,float(support.get_meta("floor_y",-2))+.08,top_bounds.position.z-.04)
 cable(tv,PackedVector3Array([back+Vector3(-.07,0,0),back+Vector3(-.09,0,-.10),Vector3(back.x-.10,back.y,top_bounds.position.z-.04),end]),.005,"ConsolePowerCable")
 prop.set_meta("table_top",top_bounds.end.y)
 return prop
