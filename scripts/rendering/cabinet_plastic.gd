extends RefCounted
## Apply only to known casing meshes; their shared atlas is also used by metal
## connectors and badges, which must keep their original imported materials.
const CASING_PARTS := ["Front_section", "Front_buttons", "rear_section"]
const SHADER = preload("res://shaders/cabinet_plastic.gdshader")
static var grain_texture: ImageTexture

static func apply(scene: Node) -> void:
	var replacements := {}
	var grain := make_grain_texture()
	var baked_maps := {"front": load_baked_ao("tvfront_ao.png"), "back": load_baked_ao("tvback_ao.png")}
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		if not str(part.get_parent().name) in CASING_PARTS: continue
		for surface in range(part.mesh.get_surface_count()):
			var original := part.get_active_material(surface) as StandardMaterial3D
			if original == null: continue
			var back := str(part.get_parent().name) == "rear_section"
			var key := str(original.get_instance_id()) + ("back" if back else "front")
			if not replacements.has(key):
				var material := ShaderMaterial.new()
				material.shader = SHADER
				material.set_shader_parameter("grain_map", grain)
				material.set_shader_parameter("has_grain", true)
				material.set_shader_parameter("albedo_map", original.albedo_texture)
				material.set_shader_parameter("base_colour", original.albedo_color)
				material.set_shader_parameter("surface_map", original.roughness_texture)
				material.set_shader_parameter("normal_map", original.normal_texture)
				material.set_shader_parameter("has_normal", original.normal_enabled and original.normal_texture != null)
				material.set_shader_parameter("normal_depth", original.normal_scale * (0.55 if back else 0.65))
				material.set_shader_parameter("roughness_limits", Vector2(0.56, 0.86) if back else Vector2(0.40, 0.76))
				var baked: Texture2D = baked_maps["back" if back else "front"]
				material.set_shader_parameter("has_baked_ao", baked != null)
				if baked != null: material.set_shader_parameter("baked_ao_map", baked)
				replacements[key] = material
			part.set_surface_override_material(surface, replacements[key])

static func load_baked_ao(filename: String) -> Texture2D:
	var base := ProjectSettings.globalize_path("res://build/crt-model/ao") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("assets/ao")
	# Prefer the BC4 conversion from scripts/prepare-cabinet-ao.gd (about a third
	# of the memory, no decode at startup); the PNG remains the fallback.
	var compressed := base.path_join(filename.get_basename() + ".res")
	if FileAccess.file_exists(compressed):
		var texture := ResourceLoader.load(compressed, "Texture2D") as Texture2D
		if texture != null: return texture
	var path := base.path_join(filename)
	if not FileAccess.file_exists(path): return null
	var image := Image.load_from_file(path)
	if image == null: return null
	# Single-channel linear data, not colour; ~5.3 MiB per 2K map including mips.
	image.convert(Image.FORMAT_L8)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func set_detail_strengths(scene: Node, ao_strength: float, grain_strength: float) -> void:
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in range(part.mesh.get_surface_count()):
			var material := part.get_active_material(surface) as ShaderMaterial
			if material != null and material.shader == SHADER:
				material.set_shader_parameter("baked_ao_strength", clampf(ao_strength, 0.0, 1.0))
				material.set_shader_parameter("grain_strength", clampf(grain_strength, 0.0, 1.0))

static func make_grain_texture() -> ImageTexture:
	if grain_texture != null: return grain_texture
	# Original seeded texture, shared by all casing parts. R stores smooth
	# finish variation; G/B store fine height slopes, centred on neutral 0.5.
	var random := RandomNumberGenerator.new()
	random.seed = 1989
	var broad := PackedFloat32Array()
	var fine := PackedFloat32Array()
	for i in range(32*32): broad.append(random.randf())
	for i in range(256*256): fine.append(random.randf())
	var bytes := PackedByteArray()
	bytes.resize(256*256*4)
	for y in range(256):
		for x in range(256):
			var cell := Vector2(float(x)/8.0, float(y)/8.0)
			var ix := int(cell.x)
			var iy := int(cell.y)
			var t := cell - Vector2(ix,iy)
			t = t*t*(Vector2.ONE*3.0-t*2.0)
			var a := lerpf(broad[iy*32+ix],broad[iy*32+(ix+1)%32],t.x)
			var b := lerpf(broad[((iy+1)%32)*32+ix],broad[((iy+1)%32)*32+(ix+1)%32],t.x)
			var dx := (fine[y*256+(x+1)%256]-fine[y*256+(x+255)%256])*.5
			var dy := (fine[((y+1)%256)*256+x]-fine[((y+255)%256)*256+x])*.5
			var index := (y*256+x)*4
			bytes[index] = int(roundf(lerpf(a,b,t.y)*255.0))
			bytes[index+1] = int(roundf((.5+dx*.5)*255.0))
			bytes[index+2] = int(roundf((.5+dy*.5)*255.0))
			bytes[index+3] = 255
	var image := Image.create_from_data(256,256,false,Image.FORMAT_RGBA8,bytes)
	image.generate_mipmaps()
	grain_texture = ImageTexture.create_from_image(image)
	return grain_texture
