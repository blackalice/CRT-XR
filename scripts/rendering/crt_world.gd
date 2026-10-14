extends Node3D

var television := Node3D.new()
var screen_material := ShaderMaterial.new()
var glass_material := ShaderMaterial.new()
var curvature := 0.066
var imported_screen: Dictionary = {}
var distance_fade := ShaderMaterial.new()
var screen_spill := ShaderMaterial.new()
const SCREEN_SPILL_ENABLED := false # Deferred until the lighting effect is convincing in the glasses.
var spill_strength := 0.0
var spill_transform := Transform3D.IDENTITY
var spill_receivers: Array[GeometryInstance3D] = []
var spill_average: SubViewport
const ImportedCRT = preload("res://scripts/rendering/imported_crt.gd")
const BedroomSet = preload("res://scripts/rendering/bedroom_set.gd")
var ambient := 0.45
var key_energy := 4.5
var fill_energy := 1.6
var warmth := 0.70
var lamp_height := 2.6
var lamp_side := -1.8
var fade_begin := 4.5
var fade_end := 9.0
var floor_brightness := 1.15
var shadows := true
var show_rug := true
var room_environment: Environment
var key_light: SpotLight3D
var fill_light: OmniLight3D
var floor_node: MeshInstance3D
var rug_node: MeshInstance3D
var floor_material := ShaderMaterial.new()
var rug_material := ShaderMaterial.new()

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
	# The blackout must composite after the additive spill, including at long range.
	distance_fade.render_priority = 1
	floor_node = MeshInstance3D.new()
	floor_node.name = "RoomFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(10, 8)
	floor_node.mesh = floor_mesh
	floor_node.position = Vector3(0, -0.01, -3)
	floor_material.shader = load("res://shaders/room_floor.gdshader")
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
	BedroomSet.build_stand(television, float(imported_screen.bottom) if not imported_screen.is_empty() else -0.635)
	# A black overlay fades the cabinet and furniture without changing their PBR maps.
	# The self-lit picture and glass are created afterwards and retain their contrast.
	for part in television.find_children("*", "GeometryInstance3D", true, false):
		part.material_overlay = distance_fade
	if SCREEN_SPILL_ENABLED: _build_screen_spill()
	_build_lighting()

	screen_material.shader = load("res://shaders/crt.gdshader")
	screen_material.set_shader_parameter("signal_texture", signal_texture)
	set_spill_texture(signal_texture)
	var screen := MeshInstance3D.new()
	screen.name = "PhosphorSurface"
	screen.mesh = curved_screen()
	screen.material_override = screen_material
	screen.position = Vector3(-0.07, 0.035, 0.06)
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

func _build_screen_spill() -> void:
	# Retained for future experiments; disabled in the active scene.
	spill_average = load("res://scripts/rendering/screen_spill_average.gd").new()
	screen_spill.shader = load("res://shaders/screen_spill.gdshader")
	add_child(spill_average)
	screen_spill.set_shader_parameter("average_texture", spill_average.get_texture())
	screen_spill.next_pass = distance_fade
	screen_spill.set_shader_parameter("screen_half_size", Vector2(0.66,
		float(imported_screen.height) * 0.5 if not imported_screen.is_empty() else 0.495))
	screen_spill.set_shader_parameter("world_to_tv", television.global_transform.affine_inverse())
	var cabinet: Node = television.get_node_or_null("ImportedCabinet")
	for part in (cabinet if cabinet != null else television).find_children("*", "GeometryInstance3D", true, false):
		if not television.get_node("TelevisionSupport").is_ancestor_of(part):
			spill_receivers.append(part)
			part.material_overlay = screen_spill

func _process(_delta: float) -> void:
	# A small floor island follows the virtual set, including its scale control.
	floor_node.scale = television.scale
	floor_node.position = television.position - Vector3(0, 1.26 * television.scale.y, 0)
	if SCREEN_SPILL_ENABLED and not spill_transform.is_equal_approx(television.global_transform):
		spill_transform = television.global_transform
		screen_spill.set_shader_parameter("world_to_tv", spill_transform.affine_inverse())

func set_spill_texture(texture: Texture2D) -> void:
	if not SCREEN_SPILL_ENABLED: return
	spill_average.set_signal(texture)

func set_spill_strength(value: float) -> void:
	if not SCREEN_SPILL_ENABLED:
		spill_strength = 0.0
		return
	spill_strength = clampf(value, 0.0, 0.4)
	screen_spill.set_shader_parameter("strength", spill_strength)
	spill_average.render_target_update_mode = SubViewport.UPDATE_ALWAYS if spill_strength > 0.0 else SubViewport.UPDATE_DISABLED
	for part in spill_receivers:
		part.material_overlay = screen_spill if spill_strength > 0.0 else distance_fade

func apply_room_settings() -> void:
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
	key.spot_angle = 48.0
	key.spot_angle_attenuation = 0.8
	key.shadow_enabled = true
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
	box(television, Vector3(1.42, 1.08, 0.04), Vector3(-0.07, 0.035, 0.031), Color("10141b"))
	for i in range(12):
		box(television, Vector3(0.085, 0.016, 0.014), Vector3(0.755, 0.40 - i * 0.043, 0.026), Color("1b222c"))
	for i in range(3):
		box(television, Vector3(0.06, 0.04, 0.025), Vector3(0.755, -0.25 - i * 0.065, 0.04), Color("89909a"))
	box(television, Vector3(0.016, 0.012, 0.01), Vector3(0.755, -0.49, 0.045), Color("7de8b9"))
	var badge := Label3D.new()
	badge.text = "RETRO  /  STEREO"
	badge.font_size = 32
	badge.pixel_size = 0.00065
	badge.position = Vector3(-0.08, -0.55, 0.035)
	television.add_child(badge)
