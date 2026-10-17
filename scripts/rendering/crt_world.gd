extends Node3D
const Showcase = preload("res://scripts/presets/showcase.gd")

var television := Node3D.new()
var support_floor_y := -1.25
var screen_material := ShaderMaterial.new()
var glass_material := ShaderMaterial.new()
var curvature := 0.066
var imported_screen: Dictionary = {}
var distance_fade := ShaderMaterial.new()
var spill_strength: float = Showcase.ROOM.spill_strength
var screen_light := preload("res://scripts/rendering/screen_light.gd").new()
const ImportedCRT = preload("res://scripts/rendering/imported_crt.gd")
const BedroomSet = preload("res://scripts/rendering/bedroom_set.gd")
var ambient: float = Showcase.ROOM.ambient
var key_energy: float = Showcase.ROOM.key_energy
var fill_energy: float = Showcase.ROOM.fill_energy
var warmth: float = Showcase.ROOM.warmth
var lamp_height: float = Showcase.ROOM.lamp_height
var lamp_side: float = Showcase.ROOM.lamp_side
var fade_begin: float = Showcase.ROOM.fade_begin
var fade_end: float = Showcase.ROOM.fade_end
var floor_brightness: float = Showcase.ROOM.floor_brightness
var shadows: bool = Showcase.ROOM.shadows
var shadow_strength: float = Showcase.ROOM.shadow_strength
var cabinet_ao_strength: float = Showcase.ROOM.cabinet_ao_strength
var cabinet_grain_strength: float = Showcase.ROOM.cabinet_grain_strength
var show_rug: bool = Showcase.ROOM.show_rug
var room_environment: Environment
var key_light: SpotLight3D
var fill_light: OmniLight3D
var floor_node: MeshInstance3D
var rug_node: MeshInstance3D
var floor_material := ShaderMaterial.new()
var rug_material := ShaderMaterial.new()
var picture := preload("res://scripts/rendering/picture_pipeline.gd").new()

func build(signal_texture: Texture2D) -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	room_environment = environment.environment
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b1c3db")
	environment.environment.ambient_light_energy = ambient
	add_child(environment)
	distance_fade.shader = load("res://shaders/distance_black.gdshader")
	# Keep the distance blackout after the lit cabinet and furniture.
	distance_fade.render_priority = 1
	floor_node = MeshInstance3D.new()
	floor_node.name = "RoomFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(10, 8)
	floor_node.mesh = floor_mesh
	floor_node.position = Vector3(0, -0.01, -3)
	floor_material.shader = load("res://shaders/room_floor.gdshader")
	floor_material.set_shader_parameter("carpet_colour",load("res://assets/carpet/colour.jpg"))
	floor_material.set_shader_parameter("carpet_normal",load("res://assets/carpet/normal.jpg"))
	floor_material.set_shader_parameter("carpet_roughness",load("res://assets/carpet/roughness.jpg"))
	floor_node.material_override = floor_material
	add_child(floor_node)
	rug_node = MeshInstance3D.new()
	rug_node.name = "WovenRug"
	var rug_mesh := PlaneMesh.new()
	rug_mesh.size = Vector2(2.25, 1.65)
	rug_node.mesh = rug_mesh
	rug_node.position = Vector3(0.02, 0.016, 0.75)
	rug_material.shader = load("res://shaders/bedroom_rug.gdshader")
	rug_node.material_override = rug_material
	floor_node.add_child(rug_node)
	add_child(television)
	television.name = "StationaryTelevision"
	imported_screen = ImportedCRT.load_cabinet(television)
	if imported_screen.is_empty():
		_build_procedural_cabinet()
	var support := BedroomSet.build_stand(television,
		float(imported_screen.bottom) if not imported_screen.is_empty() else -0.635,
		imported_screen.cabinet_bounds if not imported_screen.is_empty()
		else AABB(Vector3(-0.85, -0.635, -0.78), Vector3(1.70, 1.27, 0.8325)))
	preload("res://scripts/rendering/console_prop.gd").build(television,support,imported_screen.cabinet_bounds if not imported_screen.is_empty() else AABB(Vector3(-.85,-.635,-.78),Vector3(1.7,1.27,.8325)))
	support_floor_y=float(support.get_meta("floor_y",-1.25))
	preload("res://scripts/rendering/room_contacts.gd").apply(self,support)
	# A black overlay fades the cabinet and furniture without changing their PBR maps.
	# The self-lit picture and glass are created afterwards and retain their contrast.
	for part in television.find_children("*", "GeometryInstance3D", true, false):
		part.material_overlay = distance_fade
	television.add_child(screen_light)
	# Only the cabinet, furniture and floor receive these lights. Picture/glass
	# are built afterwards and keep their self-lit appearance.
	for part in television.find_children("*", "MeshInstance3D", true, false):
		part.layers |= screen_light.RECEIVER_LAYER
	floor_node.layers |= screen_light.RECEIVER_LAYER
	rug_node.layers |= screen_light.RECEIVER_LAYER
	screen_light.set_strength(spill_strength)
	_build_lighting()

	screen_material.shader = load("res://shaders/crt.gdshader")
	add_child(picture)
	picture.configure(screen_material, signal_texture,
		ImportedCRT.safe_picture_rect(imported_screen) if not imported_screen.is_empty() else Rect2(0.03, 0.03, 0.94, 0.94),
		float(imported_screen.width)/float(imported_screen.height) if not imported_screen.is_empty() else 4.0/3.0)
	var screen := MeshInstance3D.new()
	screen.name = "PhosphorSurface"
	screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.mesh = curved_screen()
	screen.material_override = screen_material
	screen.position = ImportedCRT.SCREEN_ANCHOR
	television.add_child(screen)
	# Separate faceplate, 6 mm in front of the phosphor surface.
	var glass := MeshInstance3D.new()
	glass.name = "GlassFaceplate"
	glass.mesh = screen.mesh
	glass_material.shader = load("res://shaders/crt_glass.gdshader")
	glass.material_override = glass_material
	glass.position = screen.position + Vector3(0, 0, 0.006)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	television.add_child(glass)
	apply_room_settings()

func _process(_delta: float) -> void:
	# A small floor island follows the virtual set, including its scale control.
	floor_node.scale = television.scale
	floor_node.position = television.position + Vector3(0, (support_floor_y-.01) * television.scale.y, 0)
	screen_light.grading = picture.values
	screen_light.picture_area = picture.picture_rect().get_area()

func set_spill_strength(value: float) -> void:
	spill_strength = clampf(value, 0.0, 0.4)
	screen_light.set_strength(spill_strength)

func apply_room_settings() -> void:
	set_spill_strength(spill_strength)
	ImportedCRT.Plastic.set_detail_strengths(television, cabinet_ao_strength, cabinet_grain_strength)
	fade_end = maxf(fade_end, fade_begin + 0.5)
	room_environment.ambient_light_energy = ambient
	room_environment.ambient_light_color = Color("b1c3db").lerp(Color("e9d6b6"), warmth)
	key_light.light_energy = key_energy
	fill_light.light_energy = fill_energy
	key_light.light_color = Color.WHITE.lerp(Color("ffd29b"), warmth)
	fill_light.light_color = Color("c8dfff").lerp(Color("fff0d6"), warmth * 0.6)
	key_light.position = Vector3(lamp_side, lamp_height, 2.5)
	key_light.look_at(television.global_position + Vector3(0, -0.1, -0.2))
	key_light.shadow_enabled = shadows
	key_light.shadow_opacity = shadow_strength
	rug_node.visible = show_rug
	for material in [distance_fade, floor_material, rug_material]:
		material.set_shader_parameter("fade_begin", fade_begin)
		material.set_shader_parameter("fade_end", fade_end)
	floor_material.set_shader_parameter("brightness", floor_brightness)
	rug_material.set_shader_parameter("brightness", floor_brightness)

func _build_lighting() -> void:
	# Local lights move with the TV distance control and leave the far room dark.
	var key := SpotLight3D.new()
	key_light = key
	key.name = "WarmKeyLight"
	key.position = Vector3(-1.8, 2.6, 2.5)
	key.light_color = Color("ffe1b8")
	key.light_energy = 3.0
	key.spot_range = 7.0
	key.spot_angle = 34.0
	key.spot_angle_attenuation = 0.8
	key.shadow_enabled = true
	# A modest normal offset suppresses self-shadowing on the curved base.
	key.shadow_normal_bias = 1.5
	television.add_child(key)
	key.look_at(television.global_position + Vector3(0, -0.1, -0.2))
	var fill := OmniLight3D.new()
	fill_light = fill
	fill.name = "CoolFillLight"
	fill.position = Vector3(1.8, 1.2, 1.0)
	fill.light_color = Color("b9d5ff")
	fill.light_energy = 0.7
	fill.omni_range = 4.5
	television.add_child(fill)

func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func set_curvature(value: float) -> void:
	curvature = clampf(value, 0.0, 1.0) * 0.12
	var mesh := curved_screen()
	television.get_node("PhosphorSurface").mesh = mesh
	television.get_node("GlassFaceplate").mesh = mesh

func curved_screen() -> ArrayMesh:
	if not imported_screen.is_empty():
		return ImportedCRT.screen_mesh(imported_screen, curvature)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 32
	for y in range(steps):
		for x in range(steps):
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var uv: Vector2 = (Vector2(x, y) + corner) / float(steps)
				var p: Vector2 = uv * 2.0 - Vector2.ONE
				surface.set_uv(uv)
				# Analytic normals avoid faceted reflections across mesh triangles.
				surface.set_normal(Vector3(2.0 * curvature * p.x * (1.0 - p.y * p.y) / 0.66,
					-2.0 * curvature * p.y * (1.0 - p.x * p.x) / 0.495, 1.0).normalized())
				surface.add_vertex(Vector3(p.x * 0.66, -p.y * 0.495, curvature * (1.0 - p.x * p.x) * (1.0 - p.y * p.y)))
	return surface.commit()

func _build_procedural_cabinet() -> void:
	box(television, Vector3(1.62, 1.20, 0.76), Vector3(0, 0, -0.40), Color("333944"))
	box(television, Vector3(1.70, 1.26, 0.15), Vector3(0, 0, -0.06), Color("525762"))
	box(television, Vector3(1.42, 1.08, 0.04), Vector3(0, 0.035, 0.031), Color("10141b"))
	for i in range(12):
		box(television, Vector3(0.085, 0.016, 0.014), Vector3(0.755, 0.40 - i * 0.043, 0.026), Color("1b222c"))
	for i in range(3):
		box(television, Vector3(0.06, 0.04, 0.025), Vector3(0.755, -0.25 - i * 0.065, 0.04), Color("89909a"))
	box(television, Vector3(0.016, 0.012, 0.01), Vector3(0.755, -0.49, 0.045), Color("7de8b9"))
	var badge := Label3D.new()
	badge.text = "RETRO  /  STEREO"
	badge.font_size = 32
	badge.pixel_size = 0.00065
	badge.position = Vector3(0, -0.55, 0.035)
	television.add_child(badge)
