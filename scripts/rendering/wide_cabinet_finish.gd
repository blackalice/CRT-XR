extends RefCounted
## Opaque printing shares the cabinet's existing surfaces and lighting.
const BLACK_FASCIA = preload("res://assets/models/widescreen-crt/fascia-black.png")
const BLACK_SPEAKER = preload("res://assets/models/widescreen-crt/speaker-black.png")
static var black_materials: Dictionary = {}

static func apply(scene: Node, finish: int) -> void:
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in range(part.mesh.get_surface_count()):
			if finish == 0:
				part.set_surface_override_material(surface, null)
				continue
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null: continue
			var name := original.resource_name
			var key := original.get_instance_id()
			if not black_materials.has(key):
				var material := original.duplicate() as StandardMaterial3D
				if name.begins_with("Printed silver fascia"):
					material.albedo_texture = BLACK_FASCIA
					material.albedo_color = Color.WHITE
				elif name.begins_with("Graphite silver moulded plastic"):
					material.albedo_color = Color(.026,.029,.034).linear_to_srgb()
				elif name == "Charcoal rear and recess":
					material.albedo_color = Color(.008,.009,.011).linear_to_srgb()
				elif name.begins_with("Speaker mesh"):
					material.albedo_texture = BLACK_SPEAKER
					material.albedo_color = Color.WHITE
				black_materials[key] = material
			part.set_surface_override_material(surface, black_materials[key])
