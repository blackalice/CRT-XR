extends Control

const Simulated = preload("res://scripts/tracking/simulated_tracking.gd")
const LinuxTracking = preload("res://scripts/tracking/xr_linux_tracking.gd")
const CRTWorld = preload("res://scripts/rendering/crt_world.gd")
const Pattern = preload("res://scripts/content/test_pattern.gd")
const Emulation = preload("res://scripts/emulation/emulation_session.gd")
const ROMBrowser = preload("res://scripts/ui/rom_browser.gd")
const SettingsDefaults = preload("res://scripts/ui/settings_defaults.gd")
signal screenshot_saved(path: String)
var taking_screenshot := false
var last_screenshot_path := ""
var notices: Array[Label] = []
var notice_time := 0.0
var reset_target: Control
var menu_direction := Vector2i.ZERO
var menu_dpad: Dictionary = {}
var menu_stick := Vector2.ZERO
var menu_repeat_remaining := 0.0
var menu_pad_id := -1
var emulator: Node
var signal_view: SubViewport
var rom_dialog: PanelContainer
var game_status: Label
var controller_status: Label
var was_paused_before_menu := false
var provider: TrackingProvider = Simulated.new()
var needs_center := false
var tracking_was_valid := false
var previous_tracking_status := ""
var center := Quaternion.IDENTITY
var displayed := Quaternion.IDENTITY
var stereo := false
var distance := 3.4
var height_offset := 0.0
var height_slider: HSlider
var right_stick_distance := true
var distance_speed := 1.0
var distance_save_delay := -1.0
var distance_slider: HSlider
var room_sliders: Dictionary = {}
const ROOM_FIELDS := [
	["ambient", "Ambient fill", 0.0, 1.5, 0.05],
	["key_energy", "Warm lamp brightness", 0.0, 8.0, 0.1],
	["fill_energy", "Front fill brightness", 0.0, 4.0, 0.1],
	["warmth", "Light warmth", 0.0, 1.0, 0.05],
	["lamp_height", "Lamp height", 0.5, 4.0, 0.1],
	["lamp_side", "Lamp side", -3.0, 3.0, 0.1],
	["floor_brightness", "Carpet / rug brightness", 0.0, 2.0, 0.05],
	["fade_begin", "Room fade begins (m)", 2.0, 10.0, 0.25],
	["fade_end", "Room fades to black (m)", 3.0, 16.0, 0.25]]
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
var settings_tabs: TabContainer
var row: HBoxContainer
var screenshot_pending := false
var menu_view: SubViewport
var menu_overlays: Array[TextureRect] = []
var last_game_path := ""
var default_rom_dir := ""
var display_report_elapsed := 0.0
var view_diagnosed := false
var sbs_prompt: Control

func _ready() -> void:
	Input.use_accumulated_input = false
	if "--sbs-prompt" in OS.get_cmdline_user_args():
		sbs_prompt = load("res://scripts/ui/sbs_prompt.gd").new()
		sbs_prompt.manual_confirmation = "--sbs-prompt-manual" in OS.get_cmdline_user_args()
		add_child(sbs_prompt)
		set_process(false)
		return
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
		var notice := Label.new()
		notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		notice.offset_top = -75
		notice.offset_bottom = -12
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice.add_theme_color_override("font_shadow_color", Color.BLACK)
		notice.add_theme_constant_override("shadow_offset_x", 2)
		notice.add_theme_constant_override("shadow_offset_y", 2)
		notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notice.hide()
		panel.add_child(notice)
		notices.append(notice)
	emulator = Emulation.new()
	add_child(emulator)
	Input.joy_connection_changed.connect(func(device, connected):
		if not connected:
			emulator.gamepad.disconnect_device(device)
			if device == menu_pad_id: clear_menu_gamepad()
		print("Controller ", device, " connected: ", Input.get_joy_name(device) if connected else "disconnected"))
	for device in Input.get_connected_joypads():
		print("Controller ", device, ": ", Input.get_joy_name(device))
	emulator.content_changed.connect(func(texture):
		world.set_spill_texture(texture)
		world.screen_material.set_shader_parameter("signal_texture", texture)
		world.screen_material.set_shader_parameter("signal_size", Vector2(texture.get_width(), texture.get_height())))
	emulator.game_changed.connect(func(active):
		pattern.visible = not active
		if active:
			last_game_path = emulator.rom_path
			if save_library() != OK: show_notice("Could not save the recent game location")
		if not active:
			world.set_spill_texture(signal_view.get_texture())
			world.screen_material.set_shader_parameter("signal_texture", signal_view.get_texture())
			world.screen_material.set_shader_parameter("signal_size", Vector2(256, 240)))
	emulator.status_changed.connect(func(message):
		if is_instance_valid(game_status): game_status.text = message)
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		right_stick_distance = bool(config.get_value("view", "right_stick_distance", true))
		distance_speed = clampf(config.get_value("view", "distance_speed", 1.0), 0.2, 2.0)
		for setting in ROOM_FIELDS:
			world.set(setting[0], clampf(config.get_value("room", setting[0], world.get(setting[0])), setting[2], setting[3]))
		world.shadows = bool(config.get_value("room", "shadows", true))
		world.show_rug = bool(config.get_value("room", "show_rug", true))
		emulator.run_ahead = bool(config.get_value("emulation", "run_ahead", true))
		distance = clampf(config.get_value("view", "distance", 3.4), 1.2, 5.0)
		height_offset = clampf(config.get_value("view", "height_offset", 0.0), -1.5, 1.5)
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
		world.set_spill_strength(config.get_value("crt", "screen_spill", 0.10))
		glass_reflections = clampf(config.get_value("crt", "glass", 0.12), 0.0, 0.4)
		screen_curvature = clampf(config.get_value("crt", "curvature", 0.55), 0.0, 1.0)
	world.apply_room_settings()
	fade_material.set_shader_parameter("fade_width", edge_fade)
	world.screen_material.set_shader_parameter("scanlines", scanlines)
	world.screen_material.set_shader_parameter("mask_strength", phosphor_mask)
	world.screen_material.set_shader_parameter("glow_strength", phosphor_glow)
	world.glass_material.set_shader_parameter("reflection_strength", glass_reflections)
	world.set_curvature(screen_curvature)
	var recent := ConfigFile.new()
	if recent.load("user://recent.cfg") == OK:
		last_game_path = str(recent.get_value("library", "last_game", ""))
		default_rom_dir = str(recent.get_value("library", "default_rom_dir", ""))
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
	if "--last-game" in arguments and not "--rom" in arguments and not last_game_path.is_empty() and FileAccess.file_exists(last_game_path):
		emulator.load_rom(last_game_path)

func _process(delta: float) -> void:
	notice_time = maxf(0.0, notice_time - delta)
	for notice in notices: notice.visible = notice_time > 0.0
	var menu_open := settings_panel.visible or (is_instance_valid(rom_dialog) and rom_dialog.visible)
	if settings_panel.visible and menu_direction != Vector2i.ZERO:
		menu_repeat_remaining -= delta
		if menu_repeat_remaining <= 0.0:
			navigate_settings(menu_direction)
			menu_repeat_remaining = 0.10
	elif not settings_panel.visible: clear_menu_gamepad()
	if right_stick_distance and not menu_open:
		adjust_distance(emulator.gamepad.view_distance_axis() * distance_speed * delta)
	if distance_save_delay >= 0.0:
		distance_save_delay -= delta
		if distance_save_delay < 0.0: save_settings()
	for overlay in menu_overlays: overlay.visible = menu_open
	for hud in diagnostics: hud.modulate.a = 0.0 if menu_open else 1.0
	if is_instance_valid(controller_status) and menu_open:
		var pads := Input.get_connected_joypads()
		controller_status.text = "Controller: choose a Gamepad layout in Steam" if pads.is_empty() else "Controller: " + Input.get_joy_name(emulator.gamepad.active_device if emulator.gamepad.active_device in pads else pads[0])
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
	world.television.position = Vector3(0, 1.25 + height_offset, -distance)
	world.television.scale = Vector3.ONE * tv_scale
	for i in range(2):
		var offset := (-0.5 if i == 0 else 0.5) * ipd if stereo else 0.0
		eyes[i].transform = Transform3D(Basis(displayed), Vector3(0, 1.25, 0) + displayed * Vector3(offset, 0, 0))
		# Parallel axes, asymmetric frusta; no toe-in. Convergence is zero disparity distance.
		var near_plane := 0.05
		eyes[i].set_frustum(2.0 * near_plane * tan(deg_to_rad(vertical_fov) / 2.0), Vector2(-offset * near_plane / convergence, 0), near_plane, 50.0)
		var a := displayed.get_euler() * 180.0 / PI
		diagnostics[i].text = "RETROCRT XR   /   %s\n%s\nYaw %+.1f   Pitch %+.1f   Roll %+.1f\n%.2fm  /  IPD %.0fmm  /  %.0f fps\nL + R + Start / Esc: menu   R3 / R: recenter" % ["LEFT" if stereo and i == 0 else ("RIGHT" if stereo else "DESKTOP"), provider.status, a.y, a.x, a.z, distance, ipd * 1000, Engine.get_frames_per_second()]
	if "--capture" in OS.get_cmdline_user_args() and Engine.get_process_frames() == 30 and not screenshot_pending:
		screenshot_pending = true
		capture.call_deferred()
	if "--diagnose-view" in OS.get_cmdline_user_args() and Engine.get_process_frames() >= 180 and not view_diagnosed:
		view_diagnosed = true
		diagnose_view.call_deferred()

func diagnose_view() -> void:
	print("View diagnostic requested: frame=", Engine.get_process_frames(), " pose=", displayed,
		" tracking=", provider.valid)
	await RenderingServer.frame_post_draw
	var image := views[0].get_texture().get_image()
	var lit := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			if image.get_pixel(x, y).get_luminance() > 0.02: lit += 1
	print("View diagnostic: size=", image.get_size(), " lit_samples=", lit,
		" camera=", eyes[0].global_transform, " tv=", world.television.global_position,
		" fps=", Engine.get_frames_per_second(), " renderer=", DisplayServer.get_name())

func capture() -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://build/preview.png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("Preview capture: ", path, " result=", result)
	get_tree().quit(result)

func _input(event: InputEvent) -> void:
	if is_instance_valid(sbs_prompt): return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F6:
		take_screenshot()
		get_viewport().set_input_as_handled()
		return
	if emulator.gamepad.handle_event(event):
		if is_instance_valid(rom_dialog) and rom_dialog.visible:
			rom_dialog.hide()
			emulator.set_paused(was_paused_before_menu)
			emulator.gamepad.set_menu_active(false)
		else: toggle_settings()
		get_viewport().set_input_as_handled()
		return
	var menu_open := settings_panel.visible or (is_instance_valid(rom_dialog) and rom_dialog.visible)
	if menu_open:
		if settings_panel.visible and event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y:
			if event.pressed: reset_selected_option.call_deferred()
			get_viewport().set_input_as_handled()
			return
		if settings_panel.visible and event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			if event.pressed:
				clear_menu_gamepad()
				var direction := -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1
				settings_tabs.current_tab = posmod(settings_tabs.current_tab + direction, settings_tabs.get_tab_count())
			get_viewport().set_input_as_handled()
			return
		if settings_panel.visible and handle_settings_gamepad(event):
			get_viewport().set_input_as_handled()
			return
		var cancel: bool = (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
		if cancel:
			if is_instance_valid(rom_dialog) and rom_dialog.visible:
				rom_dialog.hide()
				emulator.set_paused(was_paused_before_menu)
				emulator.gamepad.set_menu_active(false)
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
		else: menu_view.push_input(event.duplicate(), true)
		get_viewport().set_input_as_handled()
		return
	provider.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_PAGEUP: adjust_distance(-0.10)
			KEY_PAGEDOWN: adjust_distance(0.10)
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
			JOY_BUTTON_RIGHT_STICK: recenter()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(emulator):
		emulator.gamepad.clear()
		clear_menu_gamepad()

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
	if distance_save_delay >= 0.0 and is_instance_valid(emulator): save_settings()
	provider.close()

func adjust_distance(amount: float) -> void:
	var next := clampf(distance + amount, 1.2, 5.0)
	if is_equal_approx(distance, next): return
	distance = next
	distance_save_delay = 0.75

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
	clear_menu_gamepad()
	settings_panel.visible = not settings_panel.visible
	emulator.gamepad.set_menu_active(settings_panel.visible)
	if settings_panel.visible:
		sync_slider(distance_slider, distance)
		sync_slider(height_slider, height_offset)
		was_paused_before_menu = emulator.paused
		if emulator.loaded: emulator.set_paused(true)
		focus_settings_tab()
	elif emulator.loaded:
		emulator.set_paused(was_paused_before_menu)

func close_settings() -> void:
	clear_menu_gamepad()
	if is_instance_valid(settings_panel) and settings_panel.visible:
		settings_panel.hide()
		emulator.gamepad.set_menu_active(false)
		if emulator.loaded: emulator.set_paused(was_paused_before_menu)

func choose_rom() -> void:
	close_settings()
	emulator.gamepad.set_menu_active(true)
	was_paused_before_menu = emulator.paused
	if emulator.loaded: emulator.set_paused(true)
	if rom_dialog == null:
		rom_dialog = ROMBrowser.new()
		rom_dialog.file_selected.connect(func(path):
			emulator.load_rom(path)
			emulator.gamepad.set_menu_active(false))
		rom_dialog.canceled.connect(func():
			emulator.set_paused(was_paused_before_menu)
			emulator.gamepad.set_menu_active(false))
		rom_dialog.default_folder_changed.connect(func(path):
			default_rom_dir = path
			if save_library() != OK: rom_dialog.message.text = "Could not save the default folder. Check that your user storage is writable.")
		menu_view.add_child(rom_dialog)
	rom_dialog.default_dir = default_rom_dir
	if not last_game_path.is_empty(): rom_dialog.current_dir = last_game_path.get_base_dir()
	rom_dialog.popup_centered(Vector2i(860, 600))

func save_library() -> Error:
	var recent := ConfigFile.new()
	recent.load("user://recent.cfg")
	recent.set_value("library", "last_game", last_game_path)
	recent.set_value("library", "default_rom_dir", default_rom_dir)
	return recent.save("user://recent.cfg")

func build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(180, 25)
	settings_panel.custom_minimum_size.x = 370
	var background := StyleBoxFlat.new()
	background.bg_color = Color("151c29")
	background.set_content_margin_all(14)
	settings_panel.add_theme_stylebox_override("panel", background)
	menu_view.add_child(settings_panel)
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(570, 630)
	layout.add_theme_constant_override("separation", 10)
	settings_panel.add_child(layout)
	var title := Label.new()
	title.text = "RETROCRT / SETTINGS"
	layout.add_child(title)
	settings_tabs = TabContainer.new()
	settings_tabs.name = "Tabs"
	settings_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(settings_tabs)
	var options := settings_page("Game")
	game_status = Label.new()
	game_status.text = emulator.status
	game_status.custom_minimum_size.x = 370
	game_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options.add_child(game_status)
	controller_status = Label.new()
	options.add_child(controller_status)
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
	button(options, "Screenshot", "Save clean screenshot  [F6]", func(): take_screenshot())
	button(options, "TestSignal", "Stop game / return to test signal", func(): emulator.stop(); close_settings())
	var responsive := CheckButton.new()
	responsive.name = "InputPreview"
	responsive.text = "Reduce input delay (1-frame preview)"
	responsive.button_pressed = emulator.run_ahead
	responsive.toggled.connect(func(v): emulator.run_ahead = v)
	make_resettable(responsive, func(): responsive.button_pressed = true)
	options.add_child(responsive)
	options = settings_page("View")
	button(options, "Recenter", "Recenter head  [R / R3]", recenter)
	button(options, "Stereo", "Switch mono / SBS  [F2]", func(): set_stereo(not stereo))
	button(options, "Fullscreen", "Toggle fullscreen  [F11]", toggle_fullscreen)
	distance_slider = slider(options, "TV distance (m)", 1.2, 5.0, 0.1, distance, func(v): distance = v)
	height_slider = slider(options, "Screen height offset (m)", -1.5, 1.5, 0.05, height_offset, func(v): height_offset = v)
	var stick := CheckButton.new()
	stick.text = "Right stick: screen closer / farther"
	stick.button_pressed = right_stick_distance
	stick.toggled.connect(func(v): right_stick_distance = v)
	make_resettable(stick, func(): stick.button_pressed = true)
	options.add_child(stick)
	slider(options, "Distance adjustment speed", 0.2, 2.0, 0.1, distance_speed, func(v): distance_speed = v)
	var pad_hint := Label.new()
	pad_hint.text = "Stick up: closer · down: farther\nTrackpad layouts can map Page Up / Page Down."
	options.add_child(pad_hint)
	slider(options, "TV scale", 0.5, 1.6, 0.05, tv_scale, func(v): tv_scale = v)
	slider(options, "IPD (m)", 0.0, 0.080, 0.001, ipd, func(v): ipd = v)
	slider(options, "Convergence (m)", 1.0, 10.0, 0.1, convergence, func(v): convergence = v)
	slider(options, "Vertical field of view", 18.0, 70.0, 0.5, vertical_fov, func(v): vertical_fov = v)
	slider(options, "Soft view edges", 0.0, 0.2, 0.005, edge_fade, func(v): edge_fade = v; fade_material.set_shader_parameter("fade_width", v))
	slider(options, "Smoothing (seconds)", 0.0, 0.15, 0.01, smoothing, func(v): smoothing = v)
	options = settings_page("Picture")
	slider(options, "Scanlines", 0.0, 0.7, 0.05, scanlines, func(v): scanlines = v; world.screen_material.set_shader_parameter("scanlines", v))
	slider(options, "Phosphor mask", 0.0, 0.5, 0.05, phosphor_mask, func(v): phosphor_mask = v; world.screen_material.set_shader_parameter("mask_strength", v))
	slider(options, "Phosphor glow", 0.0, 0.4, 0.02, phosphor_glow, func(v): phosphor_glow = v; world.screen_material.set_shader_parameter("glow_strength", v))
	# Screen light spill is deferred; its code is retained behind the world feature flag.
	slider(options, "Glass reflections", 0.0, 0.4, 0.02, glass_reflections, func(v): glass_reflections = v; world.glass_material.set_shader_parameter("reflection_strength", v))
	slider(options, "Screen curvature (0 = flat)", 0.0, 1.0, 0.05, screen_curvature, func(v): screen_curvature = v; world.set_curvature(v))
	options = settings_page("Room")
	var presets := HBoxContainer.new()
	options.add_child(presets)
	button(presets, "Warm", "Warm bedroom", func(): room_preset("warm"))
	button(presets, "Bright", "Bright inspection", func(): room_preset("bright"))
	button(presets, "Dim", "Dim XR", func(): room_preset("dim"))
	for setting in ROOM_FIELDS:
		var property: String = setting[0]
		room_sliders[property] = slider(options, setting[1], setting[2], setting[3], setting[4], world.get(property),
			func(v): set_room_value(property, v))
	var shadow_toggle := CheckButton.new()
	shadow_toggle.text = "Lamp shadows"
	shadow_toggle.button_pressed = world.shadows
	shadow_toggle.toggled.connect(func(v): world.shadows = v; world.apply_room_settings())
	make_resettable(shadow_toggle, func(): shadow_toggle.button_pressed = true)
	options.add_child(shadow_toggle)
	var rug_toggle := CheckButton.new()
	rug_toggle.text = "Bedroom rug"
	rug_toggle.button_pressed = world.show_rug
	rug_toggle.toggled.connect(func(v): world.show_rug = v; world.apply_room_settings())
	make_resettable(rug_toggle, func(): rug_toggle.button_pressed = true)
	options.add_child(rug_toggle)
	options = settings_page("Setup")
	button(options, "RealTracking", "Use glasses tracking / retry", func(): use_tracking(true); close_settings())
	button(options, "Simulation", "Use simulated tracking", func(): use_tracking(false); close_settings())
	button(options, "Diagnostics", "Show / hide orientation diagnostics", func():
		for label in diagnostics: label.visible = not label.visible)
	button(options, "ResetAll", "Reset all settings to defaults", func(): reset_all_options.call_deferred())
	var invert := CheckButton.new()
	invert.text = "Invert tracking yaw"
	invert.button_pressed = provider.invert_yaw
	invert.toggled.connect(func(v): provider.invert_yaw = v)
	make_resettable(invert, func(): invert.button_pressed = false)
	options.add_child(invert)
	for axis in ["pitch", "roll"]:
		var check := CheckButton.new()
		check.text = "Invert tracking " + axis
		check.button_pressed = provider.get("invert_" + axis)
		check.toggled.connect(func(v): provider.set("invert_" + axis, v))
		make_resettable(check, func(): check.button_pressed = false)
		options.add_child(check)
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	layout.add_child(footer)
	button(footer, "Close", "Save settings & close", func(): save_settings(); close_settings())
	button(footer, "ResetOption", "Reset option  [Y]", func(): reset_selected_option.call_deferred())
	button(footer, "Quit", "Exit RetroCRT", func(): get_tree().quit())
	var hint := Label.new()
	hint.text = "L1/R1: tabs   ·   A: select   ·   B: back   ·   Y: reset option"
	layout.add_child(hint)
	settings_tabs.tab_changed.connect(func(_index): focus_settings_tab.call_deferred())
	settings_panel.hide()

func make_resettable(control: Control, action: Callable) -> void:
	control.set_meta("reset_default", action)
	control.focus_entered.connect(func(): reset_target = control)

func reset_selected_option() -> void:
	if not settings_panel.visible: return
	var focused := menu_view.gui_get_focus_owner()
	# The footer button uses the last selected option on this tab.
	if is_instance_valid(focused) and focused.has_meta("reset_default"): reset_target = focused
	elif not is_instance_valid(focused) or focused.name != "ResetOption":
		show_notice("Select a slider or switch, then press Y to reset it")
		return
	if not is_instance_valid(reset_target) or not settings_tabs.get_current_tab_control().is_ancestor_of(reset_target):
		show_notice("Select a slider or switch, then press Y to reset it")
		return
	reset_target.get_meta("reset_default").call()
	reset_target.grab_focus()
	show_notice("Selected option restored to its default")

func reset_all_options() -> void:
	if not settings_panel.visible: return
	var tab := settings_tabs.current_tab
	for index in range(5): SettingsDefaults.apply(self, index)
	# Rebuild from live values so every slider, toggle and label matches the reset.
	settings_panel.hide()
	settings_panel.queue_free()
	room_sliders.clear()
	build_settings()
	settings_tabs.current_tab = tab
	settings_panel.show()
	focus_settings_tab.call_deferred()
	show_notice("All settings reset to defaults")

func show_notice(message: String) -> void:
	for notice in notices: notice.text = message
	notice_time = 4.0
	if is_instance_valid(game_status): game_status.text = message

func screenshot_directory() -> String:
	var override := OS.get_environment("RETROCRT_SCREENSHOT_DIR")
	if not override.is_empty(): return override
	var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures.is_empty(): return ProjectSettings.globalize_path("user://Screenshots")
	return pictures.path_join("RetroCRT XR")

func take_screenshot() -> String:
	if taking_screenshot: return ""
	taking_screenshot = true
	# Read only the 3D eye viewport: HUD, settings and the SBS join are outside it.
	# Keep the running display mode and the game's current pause state intact.
	await RenderingServer.frame_post_draw
	var image := views[0].get_texture().get_image()
	var folder := screenshot_directory()
	var error := DirAccess.make_dir_recursive_absolute(folder)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var stem := "RetroCRT-%s-%03d" % [stamp, Time.get_ticks_msec() % 1000]
	var path := folder.path_join(stem + ".png")
	var suffix := 2
	while FileAccess.file_exists(path):
		path = folder.path_join("%s-%d.png" % [stem, suffix])
		suffix += 1
	if error == OK: error = image.save_png(path)
	taking_screenshot = false
	if error != OK:
		show_notice("Screenshot could not be saved: %s" % error_string(error))
		return ""
	last_screenshot_path = path
	print("Screenshot saved: ", path)
	show_notice("Screenshot saved to %s" % folder)
	screenshot_saved.emit(path)
	return path

func settings_page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.custom_minimum_size = Vector2(570, 480)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_tabs.add_child(scroll)
	var options := VBoxContainer.new()
	options.name = "Options"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 10)
	scroll.add_child(options)
	return options

func focus_settings_tab() -> void:
	if not settings_panel.visible: return
	var page := settings_tabs.get_current_tab_control()
	for control in page.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree():
			control.grab_focus()
			return

func clear_menu_gamepad() -> void:
	menu_direction = Vector2i.ZERO
	menu_dpad.clear()
	menu_stick = Vector2.ZERO
	menu_repeat_remaining = 0.0
	menu_pad_id = -1

func handle_settings_gamepad(event: InputEvent) -> bool:
	# Controller UI is explicit: no platform ui_accept mapping, pointer emulation,
	# or mouse hover is required to activate the selected control.
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return false
	if event.device != menu_pad_id:
		clear_menu_gamepad()
		menu_pad_id = event.device
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_A:
			if event.pressed:
				var focused := menu_view.gui_get_focus_owner()
				if focused is BaseButton and not focused.disabled:
					if focused.toggle_mode: focused.button_pressed = not focused.button_pressed
					focused.pressed.emit()
			return true
		if not event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]: return false
		menu_dpad[event.button_index] = event.pressed
	elif event.axis == JOY_AXIS_LEFT_X: menu_stick.x = event.axis_value
	elif event.axis == JOY_AXIS_LEFT_Y: menu_stick.y = event.axis_value
	else: return false
	var next := Vector2i(int(menu_dpad.get(JOY_BUTTON_DPAD_RIGHT, false)) - int(menu_dpad.get(JOY_BUTTON_DPAD_LEFT, false)),
		int(menu_dpad.get(JOY_BUTTON_DPAD_DOWN, false)) - int(menu_dpad.get(JOY_BUTTON_DPAD_UP, false)))
	if next == Vector2i.ZERO and menu_stick.length() > 0.55:
		next = Vector2i(int(signf(menu_stick.x)), 0) if absf(menu_stick.x) > absf(menu_stick.y) else Vector2i(0, int(signf(menu_stick.y)))
	if next != menu_direction:
		menu_direction = next
		menu_repeat_remaining = 0.35
		if next != Vector2i.ZERO: navigate_settings(next)
	return true

func settings_focusables() -> Array[Control]:
	var controls: Array[Control] = []
	for control in settings_tabs.get_current_tab_control().find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree(): controls.append(control)
	for control in settings_panel.find_child("Footer", true, false).get_children():
		if control.focus_mode == Control.FOCUS_ALL: controls.append(control)
	return controls

func navigate_settings(direction: Vector2i) -> void:
	var controls := settings_focusables()
	if controls.is_empty(): return
	var focused := menu_view.gui_get_focus_owner()
	var index := controls.find(focused)
	if index == -1:
		controls[0].grab_focus()
		return
	if direction.y != 0:
		controls[posmod(index + direction.y, controls.size())].grab_focus()
	elif focused is Range:
		focused.value += direction.x * maxf(focused.step, 0.01)
	elif focused is BaseButton and focused.toggle_mode:
		focused.button_pressed = direction.x > 0
	else:
		var candidate := controls[posmod(index + direction.x, controls.size())]
		if candidate.get_parent() == focused.get_parent(): candidate.grab_focus()

func button(parent: Control, node_name: String, text: String, action: Callable) -> void:
	var control := Button.new()
	control.name = node_name
	control.text = text
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.pressed.connect(action)
	parent.add_child(control)

func slider(parent: Control, text: String, low: float, high: float, step: float, initial: float, action: Callable) -> HSlider:
	var line := HBoxContainer.new()
	parent.add_child(line)
	var label := Label.new()
	label.custom_minimum_size.x = 300
	label.text = "%s: %.3f" % [text, initial]
	line.add_child(label)
	var control := HSlider.new()
	control.custom_minimum_size.x = 150
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.min_value = low
	control.max_value = high
	control.step = step
	control.value = initial
	control.value_changed.connect(func(v): label.text = "%s: %.3f" % [text, v]; action.call(v))
	line.add_child(control)
	control.set_meta("caption", text)
	control.set_meta("value_label", label)
	if SettingsDefaults.slider_default(text, self) != null:
		make_resettable(control, func(): control.value = SettingsDefaults.slider_default(text, self))
	return control

func sync_slider(control: HSlider, value: float) -> void:
	if not is_instance_valid(control): return
	control.set_value_no_signal(value)
	control.get_meta("value_label").text = "%s: %.3f" % [control.get_meta("caption"), value]

func set_room_value(property: String, value: float) -> void:
	world.set(property, value)
	if property == "fade_end": world.fade_begin = minf(world.fade_begin, value - 0.5)
	world.apply_room_settings()
	for key in room_sliders: sync_slider(room_sliders[key], world.get(key))

func room_preset(preset: String) -> void:
	var values: Array = [0.45, 4.5, 1.6, 0.70, 1.15, 4.5, 9.0]
	if preset == "bright": values = [0.85, 5.0, 2.3, 0.40, 1.25, 6.0, 12.0]
	elif preset == "dim": values = [0.15, 2.5, 0.5, 0.80, 0.8, 3.5, 7.0]
	var keys := ["ambient", "key_energy", "fill_energy", "warmth", "floor_brightness", "fade_begin", "fade_end"]
	for i in keys.size(): world.set(keys[i], values[i])
	world.apply_room_settings()
	for key in room_sliders: sync_slider(room_sliders[key], world.get(key))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("emulation", "run_ahead", emulator.run_ahead)
	config.set_value("view", "right_stick_distance", right_stick_distance)
	config.set_value("view", "distance_speed", distance_speed)
	for setting in ROOM_FIELDS: config.set_value("room", setting[0], world.get(setting[0]))
	config.set_value("room", "shadows", world.shadows)
	config.set_value("room", "show_rug", world.show_rug)
	for pair in [["distance", distance], ["height_offset", height_offset], ["scale", tv_scale], ["ipd", ipd], ["convergence", convergence], ["edge_fade", edge_fade], ["vertical_fov", vertical_fov], ["smoothing", smoothing]]:
		config.set_value("view", pair[0], pair[1])
	for axis in ["yaw", "pitch", "roll"]:
		config.set_value("tracking", "invert_" + axis, provider.get("invert_" + axis))
	config.set_value("crt", "scanlines", scanlines)
	config.set_value("crt", "mask", phosphor_mask)
	config.set_value("crt", "glow", phosphor_glow)
	config.set_value("crt", "screen_spill", world.spill_strength)
	config.set_value("crt", "glass", glass_reflections)
	config.set_value("crt", "curvature", screen_curvature)
	var error := config.save("user://settings.cfg")
	if error != OK: push_error("Unable to save settings: %s" % error_string(error))
