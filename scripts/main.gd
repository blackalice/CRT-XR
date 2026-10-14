extends Control

const Simulated = preload("res://scripts/tracking/simulated_tracking.gd")
const LinuxTracking = preload("res://scripts/tracking/xr_linux_tracking.gd")
const CRTWorld = preload("res://scripts/rendering/crt_world.gd")
const Pattern = preload("res://scripts/content/test_pattern.gd")
const Emulation = preload("res://scripts/emulation/emulation_session.gd")
const ROMBrowser = preload("res://scripts/ui/rom_browser.gd")
var emulator: Node
var signal_view: SubViewport
var rom_dialog: PanelContainer
var game_status: Label
var was_paused_before_menu := false
var provider: TrackingProvider = Simulated.new()
var needs_center := false
var tracking_was_valid := false
var previous_tracking_status := ""
var center := Quaternion.IDENTITY
var displayed := Quaternion.IDENTITY
var stereo := false
var distance := 3.4
var tv_scale := 1.0
var ipd := 0.064
var convergence := 2.6
var smoothing := 0.0
var vertical_fov := 50.0
var edge_fade := 0.075
var scanlines := 0.22
var phosphor_mask := 0.10
var phosphor_glow := 0.12
var glass_reflections := 0.12
var screen_curvature := 0.55
var fade_material := ShaderMaterial.new()
var world: Node3D
var pattern: Node2D
var eyes: Array[Camera3D] = []
var views: Array[SubViewport] = []
var panels: Array[SubViewportContainer] = []
var diagnostics: Array[Label] = []
var settings_panel: PanelContainer
var row: HBoxContainer
var screenshot_pending := false
var menu_view: SubViewport
var menu_overlays: Array[TextureRect] = []
var last_game_path := ""
var display_report_elapsed := 0.0

func _ready() -> void:
	fade_material.shader = load("res://shaders/eye_fade.gdshader")
	if OS.get_name() == "Linux" and not "--simulate" in OS.get_cmdline_user_args():
		use_tracking(true)
	signal_view = SubViewport.new()
	signal_view.size = Vector2i(256, 240)
	signal_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	signal_view.disable_3d = true
	add_child(signal_view)
	pattern = Pattern.new()
	signal_view.add_child(pattern)
	row = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	for i in range(2):
		var panel := SubViewportContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.stretch = true
		row.add_child(panel)
		panels.append(panel)
		var view := SubViewport.new()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		panel.add_child(view)
		views.append(view)
		if i == 0:
			world = CRTWorld.new()
			view.add_child(world)
			world.build(signal_view.get_texture())
		else:
			view.world_3d = views[0].world_3d
		var camera := Camera3D.new()
		view.add_child(camera)
		camera.current = true
		eyes.append(camera)
		var hud := Label.new()
		hud.position = Vector2(22, 18)
		hud.add_theme_font_size_override("font_size", 16)
		hud.add_theme_color_override("font_shadow_color", Color.BLACK)
		hud.add_theme_constant_override("shadow_offset_x", 1)
		hud.add_theme_constant_override("shadow_offset_y", 1)
		panel.add_child(hud)
		diagnostics.append(hud)
		# Each eye gets its own full-rect fade, including at the SBS join.
		var fade := ColorRect.new()
		fade.name = "EyeEdgeFade"
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.material = fade_material
		fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(fade)
	emulator = Emulation.new()
	add_child(emulator)
	emulator.content_changed.connect(func(texture):
		world.screen_material.set_shader_parameter("signal_texture", texture)
		world.screen_material.set_shader_parameter("signal_size", Vector2(texture.get_width(), texture.get_height())))
	emulator.game_changed.connect(func(active):
		pattern.visible = not active
		if active:
			last_game_path = emulator.rom_path
			var recent := ConfigFile.new()
			recent.set_value("library", "last_game", last_game_path)
			recent.save("user://recent.cfg")
		if not active:
			world.screen_material.set_shader_parameter("signal_texture", signal_view.get_texture())
			world.screen_material.set_shader_parameter("signal_size", Vector2(256, 240)))
	emulator.status_changed.connect(func(message):
		if is_instance_valid(game_status): game_status.text = message)
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		distance = clampf(config.get_value("view", "distance", 3.4), 1.2, 5.0)
		tv_scale = clampf(config.get_value("view", "scale", 1.0), 0.5, 1.6)
		ipd = clampf(config.get_value("view", "ipd", 0.064), 0.0, 0.080)
		convergence = clampf(config.get_value("view", "convergence", 2.6), 1.0, 10.0)
		edge_fade = clampf(config.get_value("view", "edge_fade", 0.075), 0.0, 0.2)
		vertical_fov = clampf(config.get_value("view", "vertical_fov", vertical_fov), 18.0, 70.0)
		smoothing = clampf(config.get_value("view", "smoothing", 0.0), 0.0, 0.15)
		for axis in ["yaw", "pitch", "roll"]:
			provider.set("invert_" + axis, bool(config.get_value("tracking", "invert_" + axis, false)))
		scanlines = clampf(config.get_value("crt", "scanlines", 0.22), 0.0, 0.7)
		phosphor_mask = clampf(config.get_value("crt", "mask", 0.1), 0.0, 0.5)
		phosphor_glow = clampf(config.get_value("crt", "glow", 0.12), 0.0, 0.4)
		glass_reflections = clampf(config.get_value("crt", "glass", 0.12), 0.0, 0.4)
		screen_curvature = clampf(config.get_value("crt", "curvature", 0.55), 0.0, 1.0)
	fade_material.set_shader_parameter("fade_width", edge_fade)
	world.screen_material.set_shader_parameter("scanlines", scanlines)
	world.screen_material.set_shader_parameter("mask_strength", phosphor_mask)
	world.screen_material.set_shader_parameter("glow_strength", phosphor_glow)
	world.glass_material.set_shader_parameter("reflection_strength", glass_reflections)
	world.set_curvature(screen_curvature)
	var recent := ConfigFile.new()
	if recent.load("user://recent.cfg") == OK:
		last_game_path = str(recent.get_value("library", "last_game", ""))
	menu_view = SubViewport.new()
	menu_view.name = "SharedMenu"
	menu_view.size = Vector2i(960, 720)
	menu_view.transparent_bg = true
	menu_view.disable_3d = true
	menu_view.gui_embed_subwindows = true
	add_child(menu_view)
	build_settings()
	for panel in panels:
		var overlay := TextureRect.new()
		overlay.texture = menu_view.get_texture()
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(overlay)
		menu_overlays.append(overlay)
	set_stereo("--sbs" in OS.get_cmdline_user_args())
	if "--full-sbs" in OS.get_cmdline_user_args():
		set_stereo(true)
		DisplayServer.window_set_size(Vector2i(3840, 1080))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("RetroCRT ready / Godot ", Engine.get_version_info().string, " / ", OS.get_name())
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--rom": emulator.load_rom(arguments[index + 1])

func _process(delta: float) -> void:
	var menu_open := settings_panel.visible or (is_instance_valid(rom_dialog) and rom_dialog.visible)
	for overlay in menu_overlays: overlay.visible = menu_open
	for hud in diagnostics: hud.modulate.a = 0.0 if menu_open else 1.0
	menu_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if menu_open else SubViewport.UPDATE_DISABLED
	provider.enabled = not menu_open and not emulator.loaded
	display_report_elapsed += delta
	if display_report_elapsed >= 1.0:
		display_report_elapsed = 0.0
		var report_path := OS.get_environment("RETROCRT_DISPLAY_STATUS")
		if not report_path.is_empty():
			var report := FileAccess.open(report_path, FileAccess.WRITE)
			if report:
				report.store_string(JSON.stringify({"stereo": stereo, "width": get_window().size.x,
					"height": get_window().size.y, "frames": Engine.get_process_frames()}))
				report.close()
	provider.update(delta)
	if provider.valid and (needs_center or not tracking_was_valid):
		# Keep the view continuous after a driver reconnect or local reference reset.
		if provider is LinuxTracking:
			center = provider.orientation * displayed.inverse()
		needs_center = false
	tracking_was_valid = provider.valid
	if provider.status != previous_tracking_status:
		print("Tracking: ", provider.status)
		previous_tracking_status = provider.status
	var target: Quaternion = center.inverse() * provider.orientation if provider.valid else displayed
	displayed = displayed.slerp(target, 1.0 - exp(-delta / smoothing)) if smoothing > 0.001 else target
	world.television.position = Vector3(0, 1.25, -distance)
	world.television.scale = Vector3.ONE * tv_scale
	for i in range(2):
		var offset := (-0.5 if i == 0 else 0.5) * ipd if stereo else 0.0
		eyes[i].transform = Transform3D(Basis(displayed), Vector3(0, 1.25, 0) + displayed * Vector3(offset, 0, 0))
		# Parallel axes, asymmetric frusta; no toe-in. Convergence is zero disparity distance.
		var near_plane := 0.05
		eyes[i].set_frustum(2.0 * near_plane * tan(deg_to_rad(vertical_fov) / 2.0), Vector2(-offset * near_plane / convergence, 0), near_plane, 50.0)
		var a := displayed.get_euler() * 180.0 / PI
		diagnostics[i].text = "RETROCRT XR   /   %s\n%s\nYaw %+.1f   Pitch %+.1f   Roll %+.1f\n%.2fm  /  IPD %.0fmm  /  %.0f fps\n%s" % ["LEFT" if stereo and i == 0 else ("RIGHT" if stereo else "DESKTOP"), provider.status, a.y, a.x, a.z, distance, ipd * 1000, Engine.get_frames_per_second(), "L3 / Esc: menu   R3 / R: recenter" if emulator.loaded else "Tab / Start: settings   R / Y: recenter"]
	if "--capture" in OS.get_cmdline_user_args() and Engine.get_process_frames() == 30 and not screenshot_pending:
		screenshot_pending = true
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://build/preview.png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("Preview capture: ", path, " result=", result)
	get_tree().quit(result)

func _input(event: InputEvent) -> void:
	var menu_open := settings_panel.visible or (is_instance_valid(rom_dialog) and rom_dialog.visible)
	if menu_open:
		var cancel: bool = (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_LEFT_STICK])
		if cancel:
			if is_instance_valid(rom_dialog) and rom_dialog.visible:
				rom_dialog.hide()
				emulator.set_paused(was_paused_before_menu)
			else: close_settings()
		elif event is InputEventMouse:
			for panel in panels:
				if panel.visible and panel.get_global_rect().has_point(event.position):
					var factor := minf(panel.size.x / 960.0, panel.size.y / 720.0)
					var origin := panel.global_position + (panel.size - Vector2(960, 720) * factor) * 0.5
					var forwarded: InputEventMouse = event.duplicate()
					forwarded.position = (event.position - origin) / factor
					forwarded.global_position = forwarded.position
					if forwarded is InputEventMouseMotion: forwarded.relative /= factor
					menu_view.push_input(forwarded, true)
					break
		else: menu_view.push_input(event, true)
		get_viewport().set_input_as_handled()
		return
	provider.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: recenter()
			KEY_TAB:
				if not emulator.loaded: toggle_settings()
			KEY_F2: set_stereo(not stereo)
			KEY_F11: toggle_fullscreen()
			KEY_SPACE:
				if emulator.loaded: emulator.set_paused(not emulator.paused)
				else: pattern.paused = not pattern.paused
			KEY_F5: emulator.save_state()
			KEY_F8: emulator.load_state()
			KEY_ESCAPE:
				toggle_settings()
			KEY_F1:
				for label in diagnostics: label.visible = not label.visible
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_Y:
				if not emulator.loaded: recenter()
			JOY_BUTTON_START:
				if not emulator.loaded: toggle_settings()
			JOY_BUTTON_BACK:
				if not emulator.loaded: set_stereo(not stereo)
			JOY_BUTTON_LEFT_STICK: toggle_settings()
			JOY_BUTTON_RIGHT_STICK: recenter()

func recenter() -> void:
	if not provider.valid:
		needs_center = true
		return
	center = provider.orientation
	displayed = Quaternion.IDENTITY

func use_tracking(real_tracking: bool) -> void:
	var inversion := Vector3(float(provider.invert_pitch), float(provider.invert_yaw), float(provider.invert_roll))
	var changed := real_tracking != (provider is LinuxTracking)
	provider.close()
	provider = LinuxTracking.new() if real_tracking else Simulated.new()
	provider.invert_pitch = bool(inversion.x)
	provider.invert_yaw = bool(inversion.y)
	provider.invert_roll = bool(inversion.z)
	center = Quaternion.IDENTITY
	displayed = Quaternion.IDENTITY
	needs_center = real_tracking
	tracking_was_valid = false
	if changed: vertical_fov = 24.0 if real_tracking else 50.0

func _exit_tree() -> void:
	provider.close()

func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_stereo(value: bool) -> void:
	if not value and not OS.get_environment("RETROCRT_DISPLAY_STATUS").is_empty():
		return # The managed glasses session keeps its physical and rendered modes aligned.
	stereo = value
	panels[1].visible = value
	views[1].render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	close_settings()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(Vector2i(1280, 360) if value else Vector2i(1280, 720))

func toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	if settings_panel.visible:
		was_paused_before_menu = emulator.paused
		if emulator.loaded: emulator.set_paused(true)
		settings_panel.get_node("Scroll/Options/Recenter").grab_focus()
	elif emulator.loaded:
		emulator.set_paused(was_paused_before_menu)

func close_settings() -> void:
	if is_instance_valid(settings_panel) and settings_panel.visible:
		settings_panel.hide()
		if emulator.loaded: emulator.set_paused(was_paused_before_menu)

func choose_rom() -> void:
	close_settings()
	was_paused_before_menu = emulator.paused
	if emulator.loaded: emulator.set_paused(true)
	if rom_dialog == null:
		rom_dialog = ROMBrowser.new()
		rom_dialog.file_selected.connect(func(path): emulator.load_rom(path))
		rom_dialog.canceled.connect(func(): emulator.set_paused(was_paused_before_menu))
		menu_view.add_child(rom_dialog)
	if not last_game_path.is_empty(): rom_dialog.current_dir = last_game_path.get_base_dir()
	rom_dialog.popup_centered(Vector2i(860, 600))

func build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(210, 45)
	settings_panel.custom_minimum_size.x = 370
	var background := StyleBoxFlat.new()
	background.bg_color = Color("151c29")
	background.set_content_margin_all(14)
	settings_panel.add_theme_stylebox_override("panel", background)
	menu_view.add_child(settings_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(540, 620)
	scroll.follow_focus = true
	settings_panel.add_child(scroll)
	var options := VBoxContainer.new()
	options.name = "Options"
	options.add_theme_constant_override("separation", 8)
	scroll.add_child(options)
	var title := Label.new()
	title.text = "RETROCRT / VIEW SETUP"
	options.add_child(title)
	game_status = Label.new()
	game_status.text = emulator.status
	game_status.custom_minimum_size.x = 370
	game_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options.add_child(game_status)
	button(options, "OpenROM", "Open SNES ROM…", choose_rom)
	button(options, "LastROM", "Play last game", func():
		if FileAccess.file_exists(last_game_path):
			close_settings()
			emulator.load_rom(last_game_path)
		else: game_status.text = "Open a ROM first, or reconnect its folder.")
	button(options, "Pause", "Pause / resume game  [Space]", func():
		was_paused_before_menu = not was_paused_before_menu
		emulator.set_paused(was_paused_before_menu)
		close_settings())
	button(options, "SaveState", "Save state / slot 0  [F5]", func(): emulator.save_state())
	button(options, "LoadState", "Load state / slot 0  [F8]", func(): emulator.load_state())
	button(options, "TestSignal", "Stop game / return to test signal", func(): emulator.stop(); close_settings())
	button(options, "Diagnostics", "Show / hide orientation diagnostics", func():
		for label in diagnostics: label.visible = not label.visible)
	button(options, "Recenter", "Recenter head  [R / Y]", recenter)
	button(options, "Stereo", "Switch mono / SBS  [F2 / Select]", func(): set_stereo(not stereo))
	button(options, "Fullscreen", "Toggle fullscreen  [F11]", toggle_fullscreen)
	button(options, "RealTracking", "Use glasses tracking / retry", func(): use_tracking(true); close_settings())
	button(options, "Simulation", "Use simulated tracking", func(): use_tracking(false); close_settings())
	slider(options, "TV distance (m)", 1.2, 5.0, 0.1, distance, func(v): distance = v)
	slider(options, "TV scale", 0.5, 1.6, 0.05, tv_scale, func(v): tv_scale = v)
	slider(options, "IPD (m)", 0.0, 0.080, 0.001, ipd, func(v): ipd = v)
	slider(options, "Convergence (m)", 1.0, 10.0, 0.1, convergence, func(v): convergence = v)
	slider(options, "Vertical field of view", 18.0, 70.0, 0.5, vertical_fov, func(v): vertical_fov = v)
	slider(options, "Soft view edges", 0.0, 0.2, 0.005, edge_fade, func(v): edge_fade = v; fade_material.set_shader_parameter("fade_width", v))
	slider(options, "Smoothing (seconds)", 0.0, 0.15, 0.01, smoothing, func(v): smoothing = v)
	slider(options, "Scanlines", 0.0, 0.7, 0.05, scanlines, func(v): scanlines = v; world.screen_material.set_shader_parameter("scanlines", v))
	slider(options, "Phosphor mask", 0.0, 0.5, 0.05, phosphor_mask, func(v): phosphor_mask = v; world.screen_material.set_shader_parameter("mask_strength", v))
	slider(options, "Phosphor glow", 0.0, 0.4, 0.02, phosphor_glow, func(v): phosphor_glow = v; world.screen_material.set_shader_parameter("glow_strength", v))
	slider(options, "Glass reflections", 0.0, 0.4, 0.02, glass_reflections, func(v): glass_reflections = v; world.glass_material.set_shader_parameter("reflection_strength", v))
	slider(options, "Screen curvature (0 = flat)", 0.0, 1.0, 0.05, screen_curvature, func(v): screen_curvature = v; world.set_curvature(v))
	var invert := CheckButton.new()
	invert.text = "Invert tracking yaw"
	invert.button_pressed = provider.invert_yaw
	invert.toggled.connect(func(v): provider.invert_yaw = v)
	options.add_child(invert)
	for axis in ["pitch", "roll"]:
		var check := CheckButton.new()
		check.text = "Invert tracking " + axis
		check.button_pressed = provider.get("invert_" + axis)
		check.toggled.connect(func(v): provider.set("invert_" + axis, v))
		options.add_child(check)
	button(options, "Close", "Save settings & close", func(): save_settings(); close_settings())
	button(options, "Quit", "Exit RetroCRT", func(): get_tree().quit())
	settings_panel.hide()

func button(parent: Control, node_name: String, text: String, action: Callable) -> void:
	var control := Button.new()
	control.name = node_name
	control.text = text
	control.pressed.connect(action)
	parent.add_child(control)

func slider(parent: Control, text: String, low: float, high: float, step: float, initial: float, action: Callable) -> void:
	var line := HBoxContainer.new()
	parent.add_child(line)
	var label := Label.new()
	label.custom_minimum_size.x = 200
	label.text = "%s: %.3f" % [text, initial]
	line.add_child(label)
	var control := HSlider.new()
	control.custom_minimum_size.x = 150
	control.min_value = low
	control.max_value = high
	control.step = step
	control.value = initial
	control.value_changed.connect(func(v): label.text = "%s: %.3f" % [text, v]; action.call(v))
	line.add_child(control)

func save_settings() -> void:
	var config := ConfigFile.new()
	for pair in [["distance", distance], ["scale", tv_scale], ["ipd", ipd], ["convergence", convergence], ["edge_fade", edge_fade], ["vertical_fov", vertical_fov], ["smoothing", smoothing]]:
		config.set_value("view", pair[0], pair[1])
	for axis in ["yaw", "pitch", "roll"]:
		config.set_value("tracking", "invert_" + axis, provider.get("invert_" + axis))
	config.set_value("crt", "scanlines", scanlines)
	config.set_value("crt", "mask", phosphor_mask)
	config.set_value("crt", "glow", phosphor_glow)
	config.set_value("crt", "glass", glass_reflections)
	config.set_value("crt", "curvature", screen_curvature)
	var error := config.save("user://settings.cfg")
	if error != OK: push_error("Unable to save settings: %s" % error_string(error))
