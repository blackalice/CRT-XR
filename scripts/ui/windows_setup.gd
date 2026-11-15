extends Control
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const GlyphText = preload("res://scripts/ui/glyph_text.gd")
const VitureSdk = preload("res://scripts/tracking/viture_sdk.gd")
## Explicit display choice and a black curtain across a physical SBS mode change.
signal xr_ready(size: Vector2i)
signal desktop_ready
var selected_screen := 0
var selected_row := 1
var armed := false
var armed_screen_count := 0
var proceeding := false
var elapsed := 0.0
var armed_at := 0.0
var stable_time := 0.0
var last_size := Vector2i.ZERO
var canvas: Control
var column: VBoxContainer
var display_button: Button
var hint: Control
var buttons: Array[Button] = []
var sdk_button: Button
var sdk_status: Label
## Shown on the black curtain until the glasses switch to SBS.
var curtain_note: Label

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
	instructions.text = "Connect your glasses, choose their display and select Open glasses view.\nThen switch them to SBS (full side-by-side) when asked.\nUse this setup screen on your normal monitor."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size",24)
	MenuSkin.weigh(instructions,MenuSkin.REGULAR)
	column.add_child(instructions)
	selected_screen = likely_glasses_screen(get_window().current_screen)
	display_button = add_button("", func(): change_screen(1))
	add_button("Open glasses view", begin)
	add_button("Play on this screen without glasses", func():
		if not proceeding:
			proceeding=true
			desktop_ready.emit())
	sdk_button = add_button("", choose_sdk)
	add_button("Exit", func(): get_tree().quit())
	sdk_status = Label.new()
	sdk_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sdk_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sdk_status.custom_minimum_size.x = 760
	sdk_status.add_theme_font_size_override("font_size", 20)
	column.add_child(sdk_status)
	column.move_child(sdk_status, column.get_child_count() - 1)
	refresh_sdk()
	# Controls drawn as the menus draw them, with the keyboard keys alongside.
	hint = GlyphText.new("Display: {←→} / Left Right     Select: {↑↓} / Up Down     Open: {A} / Enter\nIf it stays black, return the glasses to 2D and press {B} / Escape to come back here.", 20, MenuSkin.TEXT)
	hint.centred = true
	column.add_child(hint)
	curtain_note = Label.new()
	curtain_note.text = "Now switch your glasses to SBS (full side-by-side)"
	curtain_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	curtain_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	curtain_note.add_theme_font_size_override("font_size", 28)
	curtain_note.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	curtain_note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain_note.hide()
	add_child(curtain_note)
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

## The display most likely to be the glasses: one already in a full-SBS mode,
## else the other display when there are exactly two, else `fallback`.
static func likely_glasses_screen(fallback: int) -> int:
	var count := DisplayServer.get_screen_count()
	for i in range(count):
		if i != fallback and usable_sbs(DisplayServer.screen_get_size(i)): return i
	if usable_sbs(DisplayServer.screen_get_size(fallback)): return fallback
	if count == 2: return 1 - clampi(fallback, 0, 1)
	return fallback

func refresh_sdk() -> void:
	var ready := VitureSdk.available()
	sdk_button.text = "VITURE tracking: set up  ·  Choose again…" if ready else "Set up VITURE head tracking…"
	var words := "Other glasses: use OpenTrack (View & glasses › Tracking) after opening the view."
	if not ready: words = "VITURE head tracking needs VITURE's free Windows SDK. Download it from viture.com/developer, then choose its ZIP here. " + words
	if VitureSdk.spacewalker_running(): words = "Close SpaceWalker before opening the glasses view: it holds the glasses' tracking.\n" + words
	sdk_status.text = words

func choose_sdk() -> void:
	VitureSdk.choose(func(result: Dictionary):
		refresh_sdk()
		sdk_status.text = str(result.message) + "\n" + sdk_status.text)

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
	armed_at=elapsed
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
	# Some glasses reconnect as a new display when they switch to SBS: follow
	# whichever display is now in a full-SBS mode rather than waiting for ever.
	if DisplayServer.get_screen_count()!=armed_screen_count or selected_screen>=DisplayServer.get_screen_count():
		armed_screen_count=DisplayServer.get_screen_count()
		var moved := likely_glasses_screen(mini(selected_screen, armed_screen_count-1))
		stable_time=0.0
		if moved!=selected_screen or get_window().current_screen!=moved:
			selected_screen=moved
			get_window().mode=Window.MODE_WINDOWED
			get_window().current_screen=selected_screen
			get_window().mode=Window.MODE_FULLSCREEN
		return
	var size := DisplayServer.screen_get_size(selected_screen)
	curtain_note.visible = not usable_sbs(size) and elapsed - armed_at > 1.0
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
		curtain_note.hide()
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
				curtain_note.hide()
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
