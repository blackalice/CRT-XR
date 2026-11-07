extends Control
## The menu's screensaver: after a spell with no input the page fades away and
## the logo drifts over the space backdrop, turning a new colour each time it
## meets an edge. Any input brings the page straight back (menu_controller).
const LOGO := preload("res://assets/branding/logo/boot-logo.svg")
## The full logo: the card plus its red, green and blue diamonds, as the boot
## sequence leaves it.
const DIAMONDS := [preload("res://assets/branding/logo/boot-diamond-0.svg"), preload("res://assets/branding/logo/boot-diamond-1.svg"), preload("res://assets/branding/logo/boot-diamond-2.svg")]
const LOGO_SIZE := Vector2(163, 187)
## Pixels per second along each axis, so the path runs at 45 degrees.
const SPEED := 90.0
## Reduced animation: no drifting, just a fresh resting place now and then.
const HOP_SECONDS := 8.0
## The card's white lines take the tint; its black face stays black and the
## diamonds keep their own colours (self_modulate does not reach them).
const TINTS := [Color("ffffff"), Color("ff5a5a"), Color("ffb347"), Color("ffe066"), Color("6be37a"), Color("5ad1ff"), Color("8a7dff"), Color("ff7ad9")]
var menu: PanelContainer
var logo: TextureRect
var velocity := Vector2(SPEED, SPEED)
var tint := 0
var hop := 0.0
var layout: Control
var layout_alpha := 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	layout = menu.heading.get_parent().get_parent()
	layout_alpha = layout.modulate.a
	layout.modulate.a = 0.0
	logo = make_layer(LOGO)
	logo.size = LOGO_SIZE
	add_child(logo)
	for texture in DIAMONDS:
		var diamond := make_layer(texture)
		logo.add_child(diamond)
		diamond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Start somewhere different each time, heading in a random diagonal.
	tint = randi() % TINTS.size()
	velocity = Vector2(SPEED if randf() < 0.5 else -SPEED, SPEED if randf() < 0.5 else -SPEED)
	logo.position = random_spot()
	logo.self_modulate = TINTS[tint]

func make_layer(texture: Texture2D) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer

func room() -> Vector2:
	return (size - LOGO_SIZE).max(Vector2.ZERO)

func random_spot() -> Vector2:
	return Vector2(randf() * room().x, randf() * room().y).snapped(Vector2(2, 2))

func _process(delta: float) -> void:
	if menu.host.menu_reduced_motion:
		hop += delta
		if hop >= HOP_SECONDS:
			hop = 0.0
			logo.position = random_spot()
			next_tint()
		return
	step(minf(delta, 0.1))

## Explicit steps also let tests drive the bounce deterministically.
func step(delta: float) -> void:
	var limit := room()
	var at := logo.position + velocity * delta
	var bounced := false
	for axis in [0, 1]:
		if at[axis] <= 0.0:
			at[axis] = -at[axis]; velocity[axis] = absf(velocity[axis]); bounced = true
		elif at[axis] >= limit[axis]:
			at[axis] = 2.0 * limit[axis] - at[axis]; velocity[axis] = -absf(velocity[axis]); bounced = true
	logo.position = at.clamp(Vector2.ZERO, limit)
	if bounced: next_tint()

func next_tint() -> void:
	tint = (tint + 1) % TINTS.size()
	logo.self_modulate = TINTS[tint]

func finish() -> void:
	if is_instance_valid(layout): layout.modulate.a = layout_alpha
	queue_free()
