extends Node3D
## A world-anchored first-player VMU LCD. No viewport or game-image overlay.
const DEFAULTS := {"enabled":true,"horizontal":0.0,"vertical":-0.8,"forward":0.8,"width":0.36}
var enabled := true
var horizontal := 0.0
var vertical := -0.8
var forward := 0.8
var width := 0.36
var active := false
var last_pixels := PackedByteArray()
var texture: ImageTexture
var lcd := StandardMaterial3D.new()
var poll_elapsed := 0.0
var texture_updates := 0

func quad(size: Vector2, colour: Color, depth: float) -> MeshInstance3D:
 var part := MeshInstance3D.new()
 var shape := QuadMesh.new(); shape.size = size; part.mesh = shape
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color = colour
 material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
 part.material_override = material
 part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 part.position.z = depth
 add_child(part)
 return part

func _ready() -> void:
 name = "VMUDisplay"
 quad(Vector2(1.12,0.79),Color("41483f"),0.0)
 var screen := quad(Vector2(1.0,2.0/3.0),Color.WHITE,0.002)
 lcd = screen.material_override
 apply_layout()
 hide()

func apply_layout() -> void:
 position = Vector3(horizontal,vertical,forward)
 scale = Vector3.ONE * width
 rotation.x = deg_to_rad(-25.0)
 visible = enabled and active and not last_pixels.is_empty()

func clear() -> void:
 active = false
 last_pixels = PackedByteArray()
 texture = null
 lcd.albedo_texture = null
 poll_elapsed = 0.0
 hide()

func update_lcd(pixels: PackedByteArray) -> void:
 if pixels.size() != 48 * 32:
  if not last_pixels.is_empty(): clear()
  return
 if pixels == last_pixels:
  apply_layout()
  return
 last_pixels = pixels.duplicate()
 var rgba := PackedByteArray(); rgba.resize(48 * 32 * 4)
 for y in range(32):
  for x in range(48):
   # Flycast's decoded LCD rows run bottom to top. Zero is a dark LCD pixel.
   var light := pixels[(31-y)*48+x] != 0
   var offset := (y*48+x)*4
   rgba[offset] = 145 if light else 35
   rgba[offset+1] = 162 if light else 44
   rgba[offset+2] = 131 if light else 34
   rgba[offset+3] = 255
 var image := Image.create_from_data(48,32,false,Image.FORMAT_RGBA8,rgba)
 if texture == null:
  texture = ImageTexture.create_from_image(image)
  lcd.albedo_texture = texture
 else: texture.update(image)
 texture_updates += 1
 apply_layout()

func tick(delta: float, session: Node) -> void:
 var playing: bool = session.loaded and session.system_id == "dreamcast"
 if not playing:
  if active or not last_pixels.is_empty(): clear()
  return
 active = true
 apply_layout()
 if not enabled: return
 poll_elapsed += delta
 if poll_elapsed < 1.0/30.0: return
 poll_elapsed = fmod(poll_elapsed,1.0/30.0)
 update_lcd(session.core.vmu_lcd(0))
