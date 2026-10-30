extends RefCounted
## The menus' 16-bit look: a deep-blue system menu drawn on a 2×2-pixel grid
## (480×360 across the 960×720 menu), with dithered 15-bit panels, 1-pixel
## bevels and a dot font. Text stays sharp at full resolution, as the consoles'
## hi-res text modes did; only the graphics are chunky.
const INK := Color("000818")
const TEXT := Color("e8ecf8")
const MUTED := Color("98a8d0")
const AMBER := Color("f8c848")
const FACE := preload("res://assets/fonts/DotGothic16.ttf")
const PANEL_SHADER := preload("res://shaders/pixel_panel.gdshader")
const SPACE_SHADER := preload("res://shaders/menu_space.gdshader")
## Weights: the dot font has one, so bolder roles are emboldened a little.
const REGULAR := 400
const SEMIBOLD := 600
const BOLD := 700
## Panel kinds: [top, bottom, bevel light, bevel dark, recessed, marquee].
const PANELS := {
	"row": ["102860", "081440", "3858a0", "000418", false, false],
	"selected": ["2c58c8", "143090", "88a8e8", "000418", false, true],
	# A quick tile being adjusted: the marquee runs in amber.
	"editing": ["2c58c8", "143090", "88a8e8", "000418", false, true, ["fff0b0", "f8c048", "c07818"]],
	"chosen": ["3868d0", "1838a0", "b0c8f8", "000418", false, false],
	"well": ["081440", "000c30", "3858a0", "000418", true, false],
	"exit_row": ["b83838", "701c28", "e87870", "300810", false, false],
	"exit_selected": ["e85848", "982830", "ffc0a8", "300810", false, true, ["fff0b0", "f8c048", "c07818"]],
	"music_well": ["5b6269", "2d3339", "9ca5ad", "181c20", true, false],
	"music_row": ["80868d", "4d535a", "b4babc", "262a2d", false, false],
	"music_selected": ["aeb5b5", "6d747c", "e0e4e4", "262a2d", false, true, ["fff0b0", "f8c048", "c07818"]],
	"lcd": ["000c20", "000c20", "3858a0", "000418", true, false],
}
static var weights := {}
static var materials := {}

## One shared FontVariation per weight, so labels can be set cheaply.
static func font(weight: int) -> Font:
	if not weights.has(weight):
		var variation := FontVariation.new()
		variation.base_font = FACE
		variation.variation_embolden = 0.35 if weight >= BOLD else 0.0
		weights[weight] = variation
	return weights[weight]

static func weigh(control: Control, weight: int) -> void:
	control.add_theme_font_override("font", font(weight))

## A one-cell dark drop shadow, so text reads on any panel, lit or not.
static func shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color("000418"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

## A flat box with square corners, for the few places a shader panel is not used.
static func box(colour: Color, border := Color.TRANSPARENT, width := 0, padding := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = border
	style.set_border_width_all(width)
	style.anti_aliasing = false
	style.set_content_margin_all(padding)
	return style

## The shared material for one panel kind (see PANELS).
static func panel_material(kind: String) -> ShaderMaterial:
	if not materials.has(kind):
		var spec: Array = PANELS[kind]
		var material := ShaderMaterial.new()
		material.shader = PANEL_SHADER
		material.set_shader_parameter("top_colour", Color(spec[0]))
		material.set_shader_parameter("bottom_colour", Color(spec[1]))
		material.set_shader_parameter("hi_colour", Color(spec[2]))
		material.set_shader_parameter("lo_colour", Color(spec[3]))
		material.set_shader_parameter("recessed", spec[4])
		material.set_shader_parameter("marquee", spec[5])
		if spec.size() > 6:
			for i in range(3): material.set_shader_parameter(["cycle_a", "cycle_b", "cycle_c"][i], Color(spec[6][i]))
		materials[kind] = material
	return materials[kind]

## A panel drawn behind its parent's own content, filling it.
static func pixel_panel(kind: String) -> ColorRect:
	var panel := ColorRect.new()
	panel.name = "PixelPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = true
	panel.material = panel_material(kind)
	return panel

## The menu's space backdrop; `size` keeps the shader's grid in step.
static func space_backdrop() -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.name = "SpaceBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.show_behind_parent = true
	var material := ShaderMaterial.new()
	material.shader = SPACE_SHADER
	backdrop.material = material
	backdrop.resized.connect(func(): material.set_shader_parameter("panel_size", backdrop.size))
	materials["space"] = material
	return backdrop

## Reduce animation holds the marquee and the stars still.
static func set_motion(moving: bool) -> void:
	for kind in ["selected", "editing", "music_selected", "exit_selected"]: panel_material(kind).set_shader_parameter("marquee_speed", 8.0 if moving else 0.0)
	if materials.has("space"): materials.space.set_shader_parameter("motion", 1.0 if moving else 0.0)

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(REGULAR)
	theme.default_font_size = 22
	for type in ["Button","LineEdit"]: theme.set_font("font",type,font(SEMIBOLD))
	for type in ["Label","Button","LineEdit","ItemList"]:
		theme.set_color("font_color",type,TEXT)
		theme.set_color("font_focus_color",type,TEXT)
		theme.set_color("font_hover_color",type,TEXT)
		theme.set_color("font_disabled_color",type,Color("586890"))
	# The space backdrop draws the menu's own panel.
	theme.set_stylebox("panel","PanelContainer",StyleBoxEmpty.new())
	theme.set_stylebox("normal","Button",box(Color("102860"),Color("3858a0"),2))
	theme.set_stylebox("hover","Button",box(Color("1838a0"),Color("5878c8"),2))
	theme.set_stylebox("pressed","Button",box(Color("2850b8"),AMBER,2))
	theme.set_stylebox("focus","Button",box(Color.TRANSPARENT,AMBER,2))
	theme.set_stylebox("disabled","Button",box(Color("081440")))
	theme.set_stylebox("normal","LineEdit",box(Color("000c30"),Color("3858a0"),2))
	theme.set_stylebox("focus","LineEdit",box(Color.TRANSPARENT,AMBER,2))
	theme.set_stylebox("scroll","VScrollBar",box(Color("000c30"),Color.TRANSPARENT,0,5))
	theme.set_stylebox("grabber","VScrollBar",box(Color("3858a0"),Color.TRANSPARENT,0,5))
	theme.set_stylebox("grabber_highlight","VScrollBar",box(AMBER,Color.TRANSPARENT,0,3))
	theme.set_stylebox("grabber_pressed","VScrollBar",box(AMBER,Color.TRANSPARENT,0,3))
	return theme
