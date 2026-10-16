extends RefCounted

static func soft_box(parent: Node3D, size: Vector3, at: Vector3, material: Material, radius := 0.015) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var bevel := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.8)
	var inner := half - Vector3.ONE * bevel
	var faces := [
		[Vector3.FORWARD * -1, Vector3.RIGHT, Vector3.DOWN],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN],
		[Vector3.LEFT, Vector3.BACK, Vector3.DOWN],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD]]
	for face in faces:
		var bx: float = bevel / (face[1] * half).length()
		var by: float = bevel / (face[2] * half).length()
		var xs := [-1.0, -1.0 + bx * 0.293, -1.0 + bx, 0.0, 1.0 - bx, 1.0 - bx * 0.293, 1.0]
		var ys := [-1.0, -1.0 + by * 0.293, -1.0 + by, 0.0, 1.0 - by, 1.0 - by * 0.293, 1.0]
		for y in range(ys.size() - 1):
			for x in range(xs.size() - 1):
				for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
					var point := Vector2(xs[x + int(corner.x)], ys[y + int(corner.y)])
					var uv := point * 0.5 + Vector2.ONE * 0.5
					var p: Vector3 = face[0] * half + face[1] * half * point.x + face[2] * half * point.y
					var nearest := p.clamp(-inner, inner)
					var normal := (p - nearest).normalized()
					surface.set_normal(normal)
					surface.set_uv(uv)
					surface.add_vertex(nearest + normal * bevel)
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

static func matte(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

static func build_stand(parent: Node3D, top: float, cabinet_bounds := AABB()) -> Node3D:
	var imported := preload("res://scripts/rendering/imported_table.gd").build(parent,top,cabinet_bounds)
	if imported!=null: return imported
	return build_procedural_stand(parent,top,cabinet_bounds)

static func build_procedural_stand(parent: Node3D, top: float, cabinet_bounds := AABB()) -> Node3D:
	var stand := Node3D.new()
	stand.name = "TelevisionSupport"
	parent.add_child(stand)
	# Centre the shelf on the actual casing footprint, including its deep tube.
	# Leave 10 cm of support in front and behind; avoid the old rear overhang.
	var depth := 1.02
	if cabinet_bounds.has_volume():
		depth = maxf(depth, cabinet_bounds.size.z + 0.20)
		stand.position = Vector3(cabinet_bounds.get_center().x, 0, cabinet_bounds.get_center().z)
	else:
		stand.position.z = -0.30
	var oak := ShaderMaterial.new()
	oak.shader = load("res://shaders/oak.gdshader")
	var floor_y := -1.25
	var bottom := floor_y + 0.10
	var inside_top := top - 0.075
	var height := maxf(inside_top - bottom, 0.12)
	var shelf := soft_box(stand, Vector3(2.02, 0.075, depth), Vector3(0, top - 0.0375, 0), oak, 0.02)
	shelf.name = "TopShelf"
	soft_box(stand, Vector3(1.88, 0.055, depth - 0.12), Vector3(0, bottom + 0.0275, 0), oak)
	for side in [-1, 1]:
		soft_box(stand, Vector3(0.065, height, depth - 0.12), Vector3(side * 0.91, bottom + height * 0.5, 0), oak)
		for z in [-depth * 0.5 + 0.15, depth * 0.5 - 0.15]:
			soft_box(stand, Vector3(0.11, 0.10, 0.11), Vector3(side * 0.81, floor_y + 0.05, z), matte(Color("4c3527")))
	soft_box(stand, Vector3(1.79, height, 0.025), Vector3(0, bottom + height * 0.5, -depth * 0.5 + 0.075), matte(Color("66503a")))
	soft_box(stand, Vector3(0.05, height - 0.055, depth - 0.18), Vector3(0.30, bottom + 0.055 + (height - 0.055) * 0.5, 0.02), oak)
	# A few unbranded cases/books give the shelf a lived-in scale without a room.
	var colors := [Color("963f35"), Color("436171"), Color("c1a16c"), Color("536445")]
	for i in range(4):
		var book := soft_box(stand, Vector3(0.075, minf(0.22, height - 0.07), 0.25),
			Vector3(0.48 + i * 0.09, bottom + 0.055 + minf(0.22, height - 0.07) * 0.5, depth * 0.5 - 0.195), matte(colors[i]), 0.006)
		book.rotation.z = -0.025 if i == 3 else 0.0
	soft_box(stand, Vector3(0.42, 0.055, 0.25), Vector3(-0.38, bottom + 0.0825, depth * 0.5 - 0.24), matte(Color("8a8a83")), 0.012)
	soft_box(stand, Vector3(0.15, 0.012, 0.075), Vector3(-0.38, bottom + 0.116, depth * 0.5 - 0.21), matte(Color("3a3a3e")), 0.004)
	return stand
