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
## The soft bloom around the tube; it fades out as the room's own lights come up.
var screen_bloom: float = Showcase.ROOM.screen_bloom
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
const FLOOR_STYLES := ["90s confetti", "Wool carpet", "Floorboards"]
var floor_style: int = Showcase.ROOM.floor_style
var show_clock_radio: bool = Showcase.ROOM.show_clock_radio
var clock_24_hour: bool = Showcase.ROOM.clock_24_hour
var show_vcr: bool = Showcase.ROOM.show_vcr
var show_game_boxes: bool = Showcase.ROOM.show_game_boxes
## The playing game's own cover on the top box, when your scrapes have one.
var show_game_cover: bool = Showcase.ROOM.show_game_cover
var game_cover: Texture2D
## The lighting follows the real time of day, around the values above.
var follow_clock: bool = Showcase.ROOM.follow_clock
## Room sound (RoomAmbience.CHOICES), its level, and the tube's whine.
var ambience: int = Showcase.ROOM.ambience
var ambience_level: float = Showcase.ROOM.ambience_level
var crt_whine: bool = Showcase.ROOM.crt_whine
var room_sound := preload("res://scripts/audio/room_ambience.gd").new()
var clock_radio: MeshInstance3D
var video_recorder: MeshInstance3D
var game_boxes: MeshInstance3D
var clock_elapsed := 1.0
var shown_minute := -1
## Seconds into the playing video, shown on the VCR as its tape counter; -1
## while no video plays, when the VCR shows the time like the clock radio.
var vcr_counter := -1
## The transport icon beside the counter (see VideoSession.transport()).
var vcr_transport := 0
var shown_transport := 0
var shown_counter := -2
var room_environment: Environment
var key_light: SpotLight3D
var fill_light: OmniLight3D
var floor_node: MeshInstance3D
var floor_material := ShaderMaterial.new()
var picture := preload("res://scripts/rendering/picture_pipeline.gd").new()
var fade_parts: Array[GeometryInstance3D] = []
var fade_dirty := true
var last_tv_transform := Transform3D()
var last_eye := Vector3.INF

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
	# The floor sits under everything; it has nothing to shadow.
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_material.shader = load("res://shaders/room_floor.gdshader")
	floor_material.set_shader_parameter("carpet_colour",load("res://assets/carpet/colour.jpg"))
	floor_material.set_shader_parameter("carpet_normal",load("res://assets/carpet/normal.jpg"))
	floor_material.set_shader_parameter("carpet_roughness",load("res://assets/carpet/roughness.jpg"))
	floor_node.material_override = floor_material
	add_child(floor_node)
	add_child(television)
	add_child(room_sound)
	television.name = "StationaryTelevision"
	imported_screen = ImportedCRT.load_cabinet(television)
	if imported_screen.is_empty():
		_build_procedural_cabinet()
	var support := BedroomSet.build_stand(television,
		float(imported_screen.bottom) if not imported_screen.is_empty() else -0.635,
		imported_screen.cabinet_bounds if not imported_screen.is_empty()
		else AABB(Vector3(-0.85, -0.635, -0.78), Vector3(1.70, 1.27, 0.8325)))
	# Console prop is parked for launch; keep its source/preparation tools for later.
	support_floor_y=float(support.get_meta("floor_y",-1.25))
	preload("res://scripts/rendering/room_contacts.gd").apply(self,support)
	_build_props(support)
	# A black overlay fades the cabinet and furniture without changing their PBR maps.
	# The self-lit picture and glass are created afterwards and retain their contrast.
	# The overlay is a second blended draw, so it is attached only to parts that
	# reach past fade_begin (see update_fade_overlays).
	for part in television.find_children("*", "GeometryInstance3D", true, false):
		# A black overlay on a multiply contact patch would darken its whole quad.
		if not part.has_meta("contact_patch"): fade_parts.append(part)
	television.add_child(screen_light)
	# Only the cabinet, furniture and floor receive these lights. Picture/glass
	# are built afterwards and keep their self-lit appearance.
	for part in television.find_children("*", "MeshInstance3D", true, false):
		if not part.has_meta("contact_patch"): part.layers |= screen_light.RECEIVER_LAYER
	floor_node.layers |= screen_light.RECEIVER_LAYER
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
	_build_halo()
	apply_room_settings()

func _build_halo() -> void:
	var size := Vector2(float(imported_screen.width), float(imported_screen.height)) if not imported_screen.is_empty() else Vector2(1.32, 0.99)
	var reach := 0.24
	var halo := MeshInstance3D.new()
	halo.name = "ScreenHalo"
	var quad := QuadMesh.new()
	quad.size = size + Vector2.ONE * reach * 2.0
	halo.mesh = quad
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/screen_halo.gdshader")
	material.set_shader_parameter("screen_half", size * 0.5)
	material.set_shader_parameter("reach", reach)
	# After the glass, so the bloom adds over everything around the tube.
	material.render_priority = 2
	halo.material_override = material
	# Just in front of the casing's face, so its own bezel lip never hides it.
	var front := float(imported_screen.cabinet_bounds.end.z) if not imported_screen.is_empty() else 0.015
	halo.position = Vector3(ImportedCRT.SCREEN_ANCHOR.x, ImportedCRT.SCREEN_ANCHOR.y, maxf(front, ImportedCRT.SCREEN_ANCHOR.z + 0.008) + 0.004)
	halo.visible = false
	television.add_child(halo)
	screen_light.halo = halo

func _build_props(support: Node3D) -> void:
	# Free tabletop either side of the TV: clock radio left, where the music's
	# default "Radio position" puts its sound; game boxes right. A full-size VCR
	# sits on a lower shelf under the TV, resting on the table's rails.
	var Props := preload("res://scripts/rendering/room_props.gd")
	var cabinet: AABB = imported_screen.cabinet_bounds if not imported_screen.is_empty() else AABB(Vector3(-0.85, -0.635, -0.78), Vector3(1.70, 1.27, 0.8325))
	var top := float(imported_screen.bottom) if not imported_screen.is_empty() else -0.635
	var table := AABB(cabinet.position - Vector3(0.4, 0, 0.1), cabinet.size + Vector3(0.8, 0, 0.2))
	if support.has_node("TopShelf"):
		var shelf := support.get_node("TopShelf") as MeshInstance3D
		table = television.global_transform.affine_inverse() * (shelf.global_transform * shelf.get_aabb())
	var front := table.end.z
	clock_radio = Props.clock_radio(television, top, (table.position.x + cabinet.position.x) * 0.5, front - 0.32)
	game_boxes = Props.game_boxes(television, top, (cabinet.end.x + table.end.x) * 0.5, front - 0.47)
	var shelf_top := support_floor_y + 0.155 # the procedural fallback stand's own bottom shelf
	if support.has_node("TopShelf") and support.has_meta("source"):
		# The imported table's lower front/back rails, measured in its proportions:
		# rail tops at 33.7% of the height, legs' inner faces at 85.5% of the
		# half-width, rails 7.3% in from the front and 7.5% from the back.
		var board := AABB(Vector3(table.get_center().x - table.size.x * 0.4275, table.position.y + table.size.y * 0.3368, table.position.z + table.size.z * 0.075),
			Vector3(table.size.x * 0.855, 0.05, table.size.z * 0.852))
		var shelf_material := (support.get_node("TopShelf") as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		Props.shelf(television, board, Props.average_colour(shelf_material.albedo_texture if shelf_material != null else null))
		shelf_top = board.end.y
	video_recorder = Props.vcr(television, shelf_top, cabinet.get_center().x, front - 0.1 - Props.VCR_SIZE.z * Props.SET_SCALE * 0.5)

func _update_prop_clocks(delta: float) -> void:
	if video_recorder != null and vcr_transport != shown_transport:
		shown_transport = vcr_transport
		(video_recorder.material_override as ShaderMaterial).set_shader_parameter("transport", vcr_transport)
	if video_recorder != null and vcr_counter != shown_counter:
		shown_counter = vcr_counter
		if vcr_counter >= 0: _show_tape_counter(vcr_counter)
		else: shown_minute = -1 # back to the time of day straight away
	clock_elapsed += delta
	if clock_elapsed < 1.0: return
	clock_elapsed = 0.0
	var now := Time.get_time_dict_from_system()
	var minute := int(now.hour) * 60 + int(now.minute)
	if minute == shown_minute: return
	shown_minute = minute
	if follow_clock: _apply_lighting()
	for prop in [clock_radio, video_recorder]:
		if prop == video_recorder and vcr_counter >= 0: continue
		var material := prop.material_override as ShaderMaterial
		material.set_shader_parameter("hours", int(now.hour))
		material.set_shader_parameter("minutes", int(now.minute))
		material.set_shader_parameter("pm", int(now.hour) >= 12)
		material.set_shader_parameter("twelve_hour", not clock_24_hour)

## Like a VCR's tape counter: minutes and seconds, then hours and minutes past an hour.
func _show_tape_counter(seconds: int) -> void:
	var material := video_recorder.material_override as ShaderMaterial
	var long := seconds >= 3600
	material.set_shader_parameter("hours", seconds / 3600 if long else seconds / 60)
	material.set_shader_parameter("minutes", seconds / 60 % 60 if long else seconds % 60)
	material.set_shader_parameter("twelve_hour", false)

func _process(_delta: float) -> void:
	if (show_clock_radio or show_vcr or follow_clock) and clock_radio != null: _update_prop_clocks(_delta)
	# A small floor island follows the virtual set, including its scale control.
	# Transforms are only written on change: each write dirties the render server.
	if television.transform != last_tv_transform:
		last_tv_transform = television.transform
		floor_node.scale = television.scale
		floor_node.position = television.position + Vector3(0, (support_floor_y-.01) * television.scale.y, 0)
		fade_dirty = true
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else Vector3(0, 1.25, 0)
	if fade_dirty or eye.distance_squared_to(last_eye) > 0.0025:
		update_fade_overlays(eye)
	screen_light.grading = picture.values
	screen_light.picture_area = picture.picture_rect().get_area()

func update_fade_overlays(eye: Vector3) -> void:
	fade_dirty = false; last_eye = eye
	for part in fade_parts:
		var bounds := part.global_transform * part.get_aabb()
		var farthest := 0.0
		for i in range(8): farthest = maxf(farthest, eye.distance_to(bounds.get_endpoint(i)))
		# A small margin covers head movement between updates.
		var overlay: Material = distance_fade if farthest + 0.1 > fade_begin else null
		if part.material_overlay != overlay: part.material_overlay = overlay

func has_shadow_casters() -> bool:
	for part in television.find_children("*", "GeometryInstance3D", true, false):
		if part.visible and part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: return true
	return false

func set_spill_strength(value: float) -> void:
	spill_strength = clampf(value, 0.0, 1.0)
	screen_light.set_strength(spill_strength)

func apply_room_settings() -> void:
	set_spill_strength(spill_strength)
	ImportedCRT.Plastic.set_detail_strengths(television, cabinet_ao_strength, cabinet_grain_strength)
	fade_end = maxf(fade_end, fade_begin + 0.5)
	_apply_lighting()
	key_light.position = Vector3(lamp_side, lamp_height, 2.5)
	key_light.look_at(television.global_position + Vector3(0, -0.1, -0.2))
	# Baked contact shading turns off casting on the cabinet and furniture; a shadow
	# map with no casters still costs an atlas and a pass in each eye.
	key_light.shadow_enabled = shadows and has_shadow_casters()
	key_light.shadow_opacity = shadow_strength
	floor_material.set_shader_parameter("style", clampi(floor_style, 0, FLOOR_STYLES.size() - 1))
	if clock_radio != null:
		clock_radio.visible = show_clock_radio
		video_recorder.visible = show_vcr
		game_boxes.visible = show_game_boxes
		_show_game_cover()
		shown_minute = -1; clock_elapsed = 1.0 # apply a 12/24-hour change at once
	for material in [distance_fade, floor_material]:
		material.set_shader_parameter("fade_begin", fade_begin)
		material.set_shader_parameter("fade_end", fade_end)
	floor_material.set_shader_parameter("brightness", floor_brightness)
	fade_dirty = true
	room_sound.ambience = ambience
	room_sound.level = ambience_level
	room_sound.whine = crt_whine
	room_sound.apply()

## How the time of day shifts the room: [hour, ambient x, lamp x, warmth +].
## Brighter and cooler by day, warm in the evening, dim in the small hours.
const DAYLIGHT := [[0.0, 0.6, 0.75, 0.10], [6.0, 0.7, 0.85, 0.0], [9.0, 1.6, 1.15, -0.25], [13.0, 1.8, 1.2, -0.3],
	[17.0, 1.2, 1.05, -0.05], [20.0, 1.0, 1.0, 0.10], [22.0, 0.75, 0.85, 0.12], [24.0, 0.6, 0.75, 0.10]]

## [ambient x, lamp x, warmth +] for an hour of the day (0..24, fractional).
static func time_of_day(hour: float) -> Array:
	for i in range(DAYLIGHT.size() - 1):
		var a: Array = DAYLIGHT[i]
		var b: Array = DAYLIGHT[i + 1]
		if hour >= a[0] and hour <= b[0]:
			var t: float = (hour - a[0]) / (b[0] - a[0])
			return [lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t)]
	return [1.0, 1.0, 0.0]

## Your room values, shifted by the time of day when the room follows the clock.
func _apply_lighting() -> void:
	var mood := [1.0, 1.0, 0.0]
	if follow_clock:
		var now := Time.get_time_dict_from_system()
		mood = time_of_day(float(now.hour) + float(now.minute) / 60.0)
	var warm := clampf(warmth + mood[2], 0.0, 1.0)
	room_environment.ambient_light_energy = ambient * mood[0]
	room_environment.ambient_light_color = Color("b1c3db").lerp(Color("e9d6b6"), warm)
	key_light.light_energy = key_energy * mood[1]
	fill_light.light_energy = fill_energy * mood[1]
	key_light.light_color = Color.WHITE.lerp(Color("ffd29b"), warm)
	fill_light.light_color = Color("c8dfff").lerp(Color("fff0d6"), warm * 0.6)
	screen_light.set_bloom(screen_bloom * room_darkness(ambient * mood[0], key_energy * mood[1], fill_energy * mood[1]))

## 1 in a room lit by the TV alone, falling to 0 once the room's own lights are
## up (about Dim XR); the eye only sees a bloom around a bright tube in the dark.
static func room_darkness(ambient_energy: float, lamp: float, fill: float) -> float:
	return 1.0 - smoothstep(0.0, 0.8, ambient_energy + lamp * 0.1 + fill * 0.2)

## The playing game's cover on the top box, or its own print when there is none.
func set_game_cover(texture: Texture2D) -> void:
	game_cover = texture
	_show_game_cover()

func _show_game_cover() -> void:
	if game_boxes == null: return
	var material := game_boxes.material_override as ShaderMaterial
	var shown := show_game_cover and game_cover != null
	material.set_shader_parameter("game_cover_on", shown)
	if not shown: return
	var image := game_cover.get_image()
	var aspect := float(image.get_width()) / maxf(1.0, image.get_height())
	# The box tint is the cover's average colour, for its spine and border.
	var average := image.duplicate() as Image
	if average.is_compressed(): average.decompress()
	average.clear_mipmaps()
	# Halving step by step averages every pixel; one jump to 1x1 samples the centre.
	while average.get_width() > 1 or average.get_height() > 1:
		average.resize(maxi(1, average.get_width() / 2), maxi(1, average.get_height() / 2), Image.INTERPOLATE_BILINEAR)
	material.set_shader_parameter("game_cover", game_cover)
	material.set_shader_parameter("game_cover_aspect", aspect)
	material.set_shader_parameter("game_cover_tint", average.get_pixel(0, 0))

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
