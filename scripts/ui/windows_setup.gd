extends Control
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const GlyphText = preload("res://scripts/ui/glyph_text.gd")
## Explicit display choice and a black curtain across a physical SBS mode change.
signal xr_ready(size: Vector2i)
signal desktop_ready
var selected_screen := 0
var selected_row := 1
var armed := false
var armed_screen_count := 0
var proceeding := false
var elapsed := 0.0
var stable_time := 0.0
var last_size := Vector2i.ZERO
var canvas: Control
var column: VBoxContainer
var display_button: Button
var hint: Control
var buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	canvas = Control.new()
	canvas.size = Vector2(1280,720)
	add_child(canvas)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202126")
	style.set_corner_radius_all(12)
	style.content_margin_left=36; style.content_margin_right=36
	style.content_margin_top=28; style.content_margin_bottom=28
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	column.add_child(preload("res://scripts/ui/startup_brand.gd").logo())
	var title := Label.new()
	title.text = "Welcome to CRT XR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",32)
	MenuSkin.weigh(title,MenuSkin.BOLD)
	column.add_child(title)
	var instructions := Label.new()
	instructions.text = "Switch your glasses to SBS before launching CRT XR.\nChoose their display below, then select Open glasses view.\nUse this setup screen on your normal monitor."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size",24)
	MenuSkin.weigh(instructions,MenuSkin.REGULAR)
	column.add_child(instructions)
	selected_screen = get_window().current_screen
	display_button = add_button("", func(): change_screen(1))
	add_button("Open glasses view", begin)
	add_button("Play on this screen without glasses", func():
		if not proceeding:
			proceeding=true
			desktop_ready.emit())
	add_button("Exit", func(): get_tree().quit())
	# Controls drawn as the menus draw them, with the keyboard keys alongside.
	hint = GlyphText.new("Display: {←→} / Left Right     Select: {↑↓} / Up Down     Open: {A} / Enter\nIf it stays black, return the glasses to mono and press {B} / Escape to retry.", 20, MenuSkin.TEXT)
	hint.centred = true
	column.add_child(hint)
	get_window().size_changed.connect(resize_canvas)
	refresh_display()
	resize_canvas()
	focus_row()

func add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text=text
	button.custom_minimum_size=Vector2(760,52)
	button.add_theme_font_size_override("font_size",24)
	MenuSkin.weigh(button,MenuSkin.SEMIBOLD)
	var focus := StyleBoxFlat.new()
	focus.bg_color=Color("49402d")
	focus.border_color=Color("e8ae59")
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus",focus)
	button.pressed.connect(action)
	button.focus_entered.connect(func(): selected_row=buttons.find(button))
	column.add_child(button)
	buttons.append(button)
	return button

func resize_canvas() -> void:
	var layout := preload("res://scripts/ui/sbs_prompt.gd").prompt_layout(get_viewport_rect().size)
	canvas.scale=Vector2.ONE*layout.scale
	canvas.position=layout.position

func refresh_display() -> void:
	selected_screen=clampi(selected_screen,0,maxi(0,DisplayServer.get_screen_count()-1))
	var size := DisplayServer.screen_get_size(selected_screen)
	display_button.text="‹  Display %d of %d — %d × %d  ›" % [selected_screen+1,DisplayServer.get_screen_count(),size.x,size.y]

func change_screen(direction: int) -> void:
	selected_screen=posmod(selected_screen+direction,maxi(1,DisplayServer.get_screen_count()))
	refresh_display()

func focus_row() -> void:
	buttons[selected_row].grab_focus()

func darken() -> void:
	canvas.hide()

func begin() -> void:
	if armed or proceeding or elapsed<0.7: return
	armed=true
	armed_screen_count=DisplayServer.get_screen_count()
	stable_time=0.0
	last_size=Vector2i.ZERO
	darken()
	# Draw black before moving or resizing the window.
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	get_window().mode=Window.MODE_WINDOWED
	get_window().current_screen=selected_screen
	get_window().mode=Window.MODE_FULLSCREEN

static func usable_sbs(size: Vector2i) -> bool:
	# User explicitly chooses the physical SBS display. This is a plausibility
	# check after that choice, not automatic glasses or optical-mode detection.
	return size.x>=1280 and size.x<=16384 and size.x%2==0 and size.y>=480 and size.y<=8192 and float(size.x)/size.y>=2.5

func _process(delta: float) -> void:
	elapsed+=delta
	if not armed or proceeding: return
	if DisplayServer.get_screen_count()!=armed_screen_count or selected_screen>=DisplayServer.get_screen_count():
		stable_time=0.0
		return
	var size := DisplayServer.screen_get_size(selected_screen)
	if not usable_sbs(size):
		stable_time=0.0
		last_size=size
		return
	if size!=last_size:
		last_size=size
		stable_time=0.0
		get_window().size=size
		return
	stable_time+=delta
	if stable_time>=1.5 and get_window().size==size:
		proceeding=true
		xr_ready.emit(size)

func _input(event: InputEvent) -> void:
	var action := ""
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: action="up"
			JOY_BUTTON_DPAD_DOWN: action="down"
			JOY_BUTTON_DPAD_LEFT: action="left"
			JOY_BUTTON_DPAD_RIGHT: action="right"
			JOY_BUTTON_A: action="accept"
			JOY_BUTTON_B: action="back"
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_UP: action="up"
			KEY_DOWN: action="down"
			KEY_LEFT: action="left"
			KEY_RIGHT: action="right"
			KEY_ENTER, KEY_SPACE: action="accept"
			KEY_ESCAPE: action="back"
	if action.is_empty(): return
	get_viewport().set_input_as_handled()
	if proceeding: return
	if armed:
		if action=="back":
			# Only reveal flat instructions once the selected display is mono again.
			if not usable_sbs(DisplayServer.screen_get_size(get_window().current_screen)):
				armed=false
				get_window().mode=Window.MODE_WINDOWED
				get_window().size=Vector2i(1280,720)
				canvas.show()
				refresh_display()
				focus_row()
		return
	match action:
		"up": selected_row=maxi(0,selected_row-1); focus_row()
		"down": selected_row=mini(buttons.size()-1,selected_row+1); focus_row()
		"left":
			if selected_row==0: change_screen(-1)
		"right":
			if selected_row==0: change_screen(1)
		"accept":
			if elapsed>=0.7: buttons[selected_row].pressed.emit()
		"back": get_tree().quit()
