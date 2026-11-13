extends Node
## Flat screen mode: the TV's picture straight to the window, without the room,
## for playing on a normal screen or a TV with no glasses. It shares everything
## with the TV: each frame the tube's shader values (picture settings, fitting,
## the shared composite and beam passes, power-on and channel-change moments)
## are copied from the TV's screen material, so the two never differ.
## The picture is drawn once into its own viewport, shown in each eye's panel
## under the notices and the menu, and read by screenshots. Its screen is the
## whole display (the default; the picture is fitted to the display's shape) or
## the TV's shape, centred with black around it (main.flat_shape).
const FLAT_SHADER := preload("res://shaders/crt_flat.gdshader")

var host: Node
var active := false
## The picture, drawn at the size it is shown.
var view := SubViewport.new()
var material := ShaderMaterial.new()
## One per eye panel: black surround with the picture centred on it.
var layers: Array[Control] = []
var uniform_names: PackedStringArray = []

func setup(app: Node, panels: Array) -> void:
	host = app
	view.name = "FlatScreenPicture"
	view.disable_3d = true
	view.transparent_bg = false
	view.size = Vector2i(1280, 960)
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	material.shader = FLAT_SHADER
	var picture := ColorRect.new()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.material = material
	view.add_child(picture)
	for parameter in FLAT_SHADER.get_shader_uniform_list():
		uniform_names.append(str(parameter.name))
	for panel in panels:
		var layer := ColorRect.new()
		layer.name = "FlatScreen"
		layer.color = Color.BLACK
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shown := TextureRect.new()
		shown.texture = view.get_texture()
		shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(shown)
		panel.add_child(layer)
		# Over the eye's room picture, under its notices, the dim and the menu.
		panel.move_child(layer, 1)
		layer.visible = false
		layers.append(layer)

func set_active(value: bool) -> void:
	active = value
	for layer in layers: layer.visible = value
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	if value: sync()

## Whether the flat screen is the whole display rather than the TV's shape.
func whole_display() -> bool:
	return int(host.get("flat_shape")) == 0

## The screen area the picture fits into: the tube's safe aperture, as on the TV.
func aperture() -> Rect2:
	return host.world.picture.safe_rect

## Width over height of the flat screen: the display's own, or the TV model's
## (standard or wide) shape.
func aspect() -> float:
	if whole_display():
		var shown := shown_panel_size()
		if shown.y >= 1.0: return shown.x / shown.y
	var area := aperture()
	return float(host.world.picture.tube_aspect) * area.size.x / maxf(area.size.y, 0.0001)

## The eye panel the picture is drawn into.
func shown_panel_size() -> Vector2:
	for layer in layers:
		if layer.is_visible_in_tree(): return layer.size
	return layers[0].size if not layers.is_empty() else Vector2.ZERO

## The largest picture of that shape inside the eye panel, in pixels.
func picture_size(panel_size: Vector2) -> Vector2i:
	if whole_display(): return Vector2i(maxi(int(panel_size.x), 16), maxi(int(panel_size.y), 16))
	var shape := aspect()
	var size := Vector2(panel_size.x, panel_size.x / shape)
	if size.y > panel_size.y: size = Vector2(panel_size.y * shape, panel_size.y)
	return Vector2i(maxi(int(size.x), 16), maxi(int(size.y), 16))

## picture_rect is in the tube's 0-1 coordinates; the flat picture spans only the
## aperture, so express it relative to that.
func flat_rect(tube_rect: Vector4) -> Vector4:
	var area := aperture()
	return Vector4((tube_rect.x - area.position.x) / area.size.x, (tube_rect.y - area.position.y) / area.size.y,
		tube_rect.z / area.size.x, tube_rect.w / area.size.y)

## On the whole display the picture is fitted afresh, with the display as the
## screen: Fit, Fill, Stretch, the game shape and the size and position settings
## all work as on the TV, against the display's shape instead of the tube's.
func whole_display_rect() -> Vector4:
	var area: Rect2 = host.world.picture.picture_rect_in(Rect2(0, 0, 1, 1), aspect())
	return Vector4(area.position.x, area.position.y, area.size.x, area.size.y)

func sync() -> void:
	var source: ShaderMaterial = host.world.screen_material
	for key in uniform_names:
		var value = source.get_shader_parameter(key)
		if value == null: continue
		if key == "picture_rect": value = whole_display_rect() if whole_display() else flat_rect(value)
		material.set_shader_parameter(key, value)
	for layer in layers:
		if layer.is_visible_in_tree():
			var size := picture_size(layer.size)
			if view.size != size: view.size = size
			break

func _process(_delta: float) -> void:
	if active: sync()
