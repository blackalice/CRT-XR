extends Control

const Simulated = preload("res://scripts/tracking/simulated_tracking.gd")
const LinuxTracking = preload("res://scripts/tracking/xr_linux_tracking.gd")
const PosePrediction = preload("res://scripts/tracking/pose_prediction.gd")
const CRTWorld = preload("res://scripts/rendering/crt_world.gd")
const Pattern = preload("res://scripts/content/test_pattern.gd")
const Emulation = preload("res://scripts/emulation/emulation_session.gd")
const Menu = preload("res://scripts/ui/menu_controller.gd")
var menu: PanelContainer
const Showcase = preload("res://scripts/presets/showcase.gd")
const SettingsDefaults = preload("res://scripts/ui/settings_defaults.gd")
const SettingsStore = preload("res://scripts/ui/settings_store.gd")
const StartupStatus = preload("res://scripts/ui/startup_status.gd")
const PICTURE_SECTIONS := ["crt", "picture"]
const PROFILE_NAMES := ["Everyday", "Evening", "Showcase"]
var settings_store := SettingsStore.new()
var picture_baseline := ConfigFile.new()
var active_game_key := ""
var remember_game_picture := Showcase.PER_GAME_PICTURE
var selected_profile := 0
var profile_undo: ConfigFile
var settings_dirty := false
var startup_message := ""
var recovery_elapsed := 0.0
var diagnostics_elapsed := 0.0
signal screenshot_saved(path: String)
var taking_screenshot := false
var last_screenshot_path := ""
var notices: Array[Label] = []
var notice_time := 0.0
var emulator: Node
var music: Node
var power_on: Node
var signal_view: SubViewport
var was_paused_before_menu := false
var provider: TrackingProvider = Simulated.new()
var needs_center := false
var tracking_was_valid := false
var previous_tracking_status := ""
var center := Quaternion.IDENTITY
var displayed := Quaternion.IDENTITY
var stereo := false
var distance: float = Showcase.VIEW.distance
var height_offset: float = Showcase.VIEW.height_offset
var right_stick_distance: bool = Showcase.VIEW.right_stick_distance
var distance_speed: float = Showcase.VIEW.distance_speed
var distance_save_delay := -1.0
const ROOM_FIELDS := [
	["spill_strength", "Screen light spill (0 = off)", 0.0, 0.4, 0.02],
	["ambient", "Ambient fill", 0.0, 1.5, 0.05],
	["key_energy", "Warm lamp brightness", 0.0, 8.0, 0.1],
	["fill_energy", "Front fill brightness", 0.0, 4.0, 0.1],
	["warmth", "Light warmth", 0.0, 1.0, 0.05],
	["shadow_strength", "Shadow darkness", 0.0, 1.0, 0.05],
	["cabinet_ao_strength", "Casing recess shading", 0.0, 1.0, 0.05],
	["cabinet_grain_strength", "Plastic grain", 0.0, 1.0, 0.05],
	["lamp_height", "Lamp height", 0.5, 4.0, 0.1],
	["lamp_side", "Lamp side", -3.0, 3.0, 0.1],
	["floor_brightness", "Carpet / rug brightness", 0.0, 2.0, 0.05],
	["fade_begin", "Room fade begins (m)", 2.0, 10.0, 0.25],
	["fade_end", "Room fades to black (m)", 3.0, 16.0, 0.25]]
var tv_scale: float = Showcase.VIEW.tv_scale
var ipd: float = Showcase.VIEW.ipd
var convergence: float = Showcase.VIEW.convergence
var smoothing: float = Showcase.VIEW.smoothing
var motion_predict: float = Showcase.VIEW.motion_predict
var vertical_fov := 50.0
var edge_fade: float = Showcase.VIEW.edge_fade
var scanlines: float = Showcase.CRT.scanlines
var phosphor_mask: float = Showcase.CRT.phosphor_mask
var phosphor_glow: float = Showcase.CRT.phosphor_glow
var glass_reflections: float = Showcase.CRT.glass_reflections
var screen_curvature: float = Showcase.CRT.screen_curvature
var fade_material := ShaderMaterial.new()
var world: Node3D
var pattern: Node2D
var eyes: Array[Camera3D] = []
var views: Array[SubViewport] = []
var panels: Array[SubViewportContainer] = []
var diagnostics: Array[Label] = []
var metrics_visible := false:
	set(value):
		metrics_visible=value
		for label in diagnostics: label.visible=value
var settings_panel: PanelContainer
var row: HBoxContainer
var screenshot_pending := false
var menu_view: SubViewport
var menu_overlays: Array[TextureRect] = []
var play_history := preload("res://scripts/content/play_history.gd").new()
var last_game_path := ""
var default_rom_dir := ""
var display_report_elapsed := 0.0
var view_diagnosed := false
var sbs_prompt: Control
var sbs_startup := false
var sbs_starting := false

func _ready() -> void:
	Input.use_accumulated_input = false
	var startup_args := OS.get_cmdline_user_args()
	for arg in startup_args:
		if arg in ["--sbs","--full-sbs","--sbs-session","--sbs-session-manual","--sbs-prompt"]:
			Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	sbs_startup = "--sbs-session" in startup_args or "--sbs-session-manual" in startup_args
	if "--sbs-prompt" in startup_args or sbs_startup:
		sbs_prompt = load("res://scripts/ui/sbs_prompt.gd").new()
		sbs_prompt.manual_confirmation = "--sbs-prompt-manual" in startup_args or "--sbs-session-manual" in startup_args
		sbs_prompt.in_place = sbs_startup
		sbs_prompt.z_index = 4096
		if sbs_startup: sbs_prompt.proceed_requested.connect(start_sbs_session)
		add_child(sbs_prompt)
		if "--startup-black" in startup_args: sbs_prompt.darken()
		set_process(false)
		return
	start_application()

func start_sbs_session() -> void:
	if sbs_starting: return
	sbs_starting = true
	sbs_prompt.darken()
	# Submit black before synchronous asset/core loading, keeping this window.
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_size(Vector2i(3840,1080))
	start_application()
	var resume_game: bool = emulator.loaded and not emulator.paused
	if resume_game: emulator.set_paused(true)
	set_process(true)
	# Keep the curtain until both eye viewports have actually been drawn.
	for i in range(3): await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	sbs_prompt.queue_free()
	sbs_prompt = null
	if not settings_panel.visible: power_on.begin()
	if resume_game: emulator.set_paused(false)
	get_window().grab_focus()
	print("SBS startup: same-window handover complete")

func start_application() -> void:
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
		# One shadow-casting lamp: give it a full quadrant instead of reserving
		# tiny slots for dozens of lights. Same total atlas size, finer edges.
		view.positional_shadow_atlas_size = 2048
		view.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
		view.positional_shadow_atlas_quad_1 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED
		view.positional_shadow_atlas_quad_2 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED
		view.positional_shadow_atlas_quad_3 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED
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
		hud.visible=metrics_visible
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
	music=preload("res://scripts/audio/music_player.gd").new()
	add_child(music)
	music.game_player=emulator.player
	power_on=preload("res://scripts/rendering/tv_power_on.gd").new()
	add_child(power_on)
	power_on.setup(world.screen_material,world.screen_light,emulator.tv_audio)
	Input.joy_connection_changed.connect(func(device, connected):
		if not connected:
			emulator.gamepad.disconnect_device(device)
			clear_menu_gamepad()
			show_notice("Controller disconnected. Reconnect it to continue; Escape opens settings with a keyboard.")
		print("Controller ", device, " connected: ", Input.get_joy_name(device) if connected else "disconnected"))
	for device in Input.get_connected_joypads():
		print("Controller ", device, ": ", Input.get_joy_name(device))
	emulator.content_changed.connect(func(texture):
		world.picture.set_source(texture))
	emulator.frame_presented.connect(world.screen_light.set_image)
	emulator.game_changed.connect(func(active):
		change_game_preferences(active)
		pattern.visible = not active
		pattern.set_process(not active)
		signal_view.render_target_update_mode = SubViewport.UPDATE_DISABLED if active else SubViewport.UPDATE_ALWAYS
		if active:
			world.picture.source_rate = emulator.fps
			world.picture.source_aspect = emulator.display_aspect
			world.picture.refresh()
			last_game_path = emulator.rom_path
			if not play_history.played(last_game_path): show_notice("Could not save recently played games")
			if save_library() != OK: show_notice("Could not save the recent game location")
		if not active:
			world.picture.source_rate = 60.0
			world.picture.source_aspect = 4.0 / 3.0
			world.screen_light.set_image(null)
			world.picture.set_source(signal_view.get_texture()))
	emulator.status_changed.connect(func(_message): refresh_startup_status())
	var defaults := capture_settings()
	var showcase_defaults := Showcase.config()
	SettingsStore.copy_sections(showcase_defaults,defaults,showcase_defaults.get_sections())
	apply_settings(settings_store.read("user://settings.cfg", defaults))
	picture_baseline = capture_settings()
	var recent := settings_store.read("user://recent.cfg")
	if recent.has_section("library"):
		last_game_path = str(recent.get_value("library", "last_game", ""))
		default_rom_dir = str(recent.get_value("library", "default_rom_dir", ""))
	play_history.read(last_game_path)
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(request_exit)
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
	set_stereo(sbs_startup or "--sbs" in OS.get_cmdline_user_args() or "--full-sbs" in OS.get_cmdline_user_args())
	if "--full-sbs" in OS.get_cmdline_user_args() or sbs_startup:
		set_stereo(true)
		DisplayServer.window_set_size(Vector2i(3840, 1080))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("RetroCRT ready / Godot ", Engine.get_version_info().string, " / ", OS.get_name())
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--rom":
			load_game(arguments[index + 1])
	if "--last-game" in arguments and not "--rom" in arguments and not last_game_path.is_empty() and FileAccess.file_exists(last_game_path):
		if not settings_panel.visible: toggle_settings()
		menu.select_file(last_game_path)
	startup_message = settings_store.warning if startup_message.is_empty() else startup_message
	if not emulator.loaded and not settings_panel.visible and not "--capture" in arguments:
		toggle_settings()
	refresh_startup_status()
	if "--capture" in arguments:
		power_on.started=true; power_on.set_progress(1.0)
	elif not settings_panel.visible and not is_instance_valid(sbs_prompt): power_on.begin()

func apply_settings(config: ConfigFile) -> void:
	for key in music.DEFAULTS: music.set(key,config.get_value("music",key,music.DEFAULTS[key]))
	music.apply()
	metrics_visible=bool(config.get_value("preferences","metrics_visible",false))
	power_on.enabled=bool(config.get_value("atmosphere","power_on",true))
	power_on.sound_level=float(config.get_value("atmosphere","power_sound",0.60))
	power_on.apply()
	for key in emulator.tv_audio.DEFAULTS:
		emulator.tv_audio.set(key,config.get_value("audio",key,emulator.tv_audio.DEFAULTS[key]))
	emulator.tv_audio.apply()
	right_stick_distance = bool(config.get_value("view", "right_stick_distance", Showcase.VIEW.right_stick_distance))
	distance_speed = clampf(config.get_value("view", "distance_speed", Showcase.VIEW.distance_speed), 0.2, 2.0)
	for setting in ROOM_FIELDS:
		world.set(setting[0], clampf(config.get_value("room", setting[0], world.get(setting[0])), setting[2], setting[3]))
	world.shadows = bool(config.get_value("room", "shadows", true))
	world.show_rug = bool(config.get_value("room", "show_rug", true))
	var preview_depth = config.get_value("emulation", "run_ahead", 1)
	emulator.run_ahead = clampi(int(preview_depth), 0, 2)
	distance = clampf(config.get_value("view", "distance", Showcase.VIEW.distance), 1.2, 5.0)
	height_offset = clampf(config.get_value("view", "height_offset", Showcase.VIEW.height_offset), -1.5, 1.5)
	tv_scale = clampf(config.get_value("view", "scale", Showcase.VIEW.tv_scale), 0.5, 1.6)
	ipd = clampf(config.get_value("view", "ipd", Showcase.VIEW.ipd), 0.0, 0.080)
	convergence = clampf(config.get_value("view", "convergence", Showcase.VIEW.convergence), 1.0, 10.0)
	edge_fade = clampf(config.get_value("view", "edge_fade", Showcase.VIEW.edge_fade), 0.0, 0.2)
	vertical_fov = clampf(config.get_value("view", "vertical_fov", vertical_fov), 18.0, 70.0)
	smoothing = clampf(config.get_value("view", "smoothing", Showcase.VIEW.smoothing), 0.0, 0.15)
	motion_predict = clampf(config.get_value("view", "motion_predict", Showcase.VIEW.motion_predict), 0.0, 0.08)
	for axis in ["yaw", "pitch", "roll"]:
		provider.set("invert_" + axis, bool(config.get_value("tracking", "invert_" + axis, false)))
	scanlines = clampf(config.get_value("crt", "scanlines", Showcase.CRT.scanlines), 0.0, 0.7)
	phosphor_mask = clampf(config.get_value("crt", "mask", Showcase.CRT.phosphor_mask), 0.0, 0.5)
	phosphor_glow = clampf(config.get_value("crt", "glow", Showcase.CRT.phosphor_glow), 0.0, 0.4)
	glass_reflections = clampf(config.get_value("crt", "glass", Showcase.CRT.glass_reflections), 0.0, 0.4)
	screen_curvature = clampf(config.get_value("crt", "curvature", Showcase.CRT.screen_curvature), 0.0, 1.0)
	for field in world.picture.all_fields():
		world.picture.values[field[0]] = clampf(config.get_value("picture", field[0], field[5]), field[2], field[3])
	world.picture.mode = clampi(config.get_value("picture", "connection", Showcase.CONNECTION), 0, 3)
	world.picture.keep_aspect = bool(config.get_value("picture", "keep_aspect", true))
	remember_game_picture = bool(config.get_value("preferences", "per_game_picture", Showcase.PER_GAME_PICTURE))
	world.picture.refresh()
	world.apply_room_settings()
	fade_material.set_shader_parameter("fade_width", edge_fade)
	world.screen_material.set_shader_parameter("scanlines", scanlines)
	world.screen_material.set_shader_parameter("mask_strength", phosphor_mask)
	world.screen_material.set_shader_parameter("glow_strength", phosphor_glow)
	world.glass_material.set_shader_parameter("reflection_strength", glass_reflections)
	world.set_curvature(screen_curvature)

func _process(delta: float) -> void:
	notice_time = maxf(0.0, notice_time - delta)
	for notice in notices: notice.visible = notice_time > 0.0
	var menu_open := settings_panel.visible
	recovery_elapsed += delta
	if recovery_elapsed >= 1.0:
		recovery_elapsed = 0.0
		refresh_startup_status()
	world.picture.paused = menu_open or (emulator.paused if emulator.loaded else pattern.paused)
	if right_stick_distance and not menu_open:
		adjust_distance(emulator.gamepad.view_distance_axis() * distance_speed * delta)
	if distance_save_delay >= 0.0:
		distance_save_delay -= delta
		if distance_save_delay < 0.0: save_settings()
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
	var previously_valid := tracking_was_valid
	provider.update(delta)
	if previously_valid and not provider.valid and provider is LinuxTracking:
		show_notice("Tracking lost — holding the view steady. Open Game for Retry glasses tracking or Fixed view.")
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
	# Extrapolate the recent head rotation toward the frame that will reach
	# the eyes. Body-frame velocity is unchanged by the center rotation, so
	# it applies directly; the raw pose still drives recentering above.
	if motion_predict > 0.001 and provider.valid:
		target = PosePrediction.extrapolate(target, provider.angular_velocity, motion_predict)
	displayed = displayed.slerp(target, 1.0 - exp(-delta / smoothing)) if smoothing > 0.001 else target
	world.television.position = Vector3(0, 1.25 + height_offset, -distance)
	world.television.scale = Vector3.ONE * tv_scale
	emulator.tv_audio.update_pose(displayed,Vector3(0,1.25,0),world.television.position,delta)
	music.update_pose(displayed,Vector3(0,1.25,0),world.television.position,delta)
	diagnostics_elapsed += delta
	var refresh_diagnostics := diagnostics_elapsed >= .1
	if refresh_diagnostics: diagnostics_elapsed = 0.0
	for i in range(2):
		var offset := (-0.5 if i == 0 else 0.5) * ipd if stereo else 0.0
		eyes[i].transform = Transform3D(Basis(displayed), Vector3(0, 1.25, 0) + displayed * Vector3(offset, 0, 0))
		# Parallel axes, asymmetric frusta; no toe-in. Convergence is zero disparity distance.
		var near_plane := 0.05
		eyes[i].set_frustum(2.0 * near_plane * tan(deg_to_rad(vertical_fov) / 2.0), Vector2(-offset * near_plane / convergence, 0), near_plane, 50.0)
		if refresh_diagnostics and diagnostics[i].visible and not menu_open:
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
	if is_instance_valid(menu): menu.release_input(event)
	if is_instance_valid(sbs_prompt): return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F6:
		take_screenshot()
		get_viewport().set_input_as_handled()
		return
	if emulator.gamepad.handle_event(event):
		toggle_settings()
		get_viewport().set_input_as_handled()
		return
	if settings_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			close_settings()
		elif menu.handle(event): pass
		elif event is InputEventMouse:
			for panel in panels:
				if panel.visible and panel.get_global_rect().has_point(event.position):
					var factor := minf(panel.size.x / 960.0, panel.size.y / 720.0)
					var origin := panel.global_position + (panel.size - Vector2(960,720)*factor)*.5
					var forwarded: InputEventMouse = event.duplicate()
					forwarded.position = (event.position-origin)/factor
					forwarded.global_position = forwarded.position
					if forwarded is InputEventMouseMotion: forwarded.relative /= factor
					menu_view.push_input(forwarded,true)
					break
		else: menu_view.push_input(event.duplicate(),true)
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
			KEY_F5:
				if emulator.loaded:
					emulator.save_state()
					show_notice(emulator.status)
			KEY_F8:
				if emulator.loaded:
					toggle_settings()
					menu.state_action(false)
			KEY_ESCAPE:
				toggle_settings()
			KEY_F1:
				metrics_visible=not metrics_visible
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

func request_exit() -> void:
	if not emulator.save_auto() or not save_settings():
		if not settings_panel.visible: toggle_settings()
		menu.show_error("Could not save before exiting. Check free space and save-folder permissions, then try Exit again.")
		return
	get_tree().quit()

func _exit_tree() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(emulator) and is_instance_valid(settings_panel): save_settings()
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
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN if value else Input.MOUSE_MODE_VISIBLE
	panels[1].visible = value
	views[1].render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	close_settings()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(Vector2i(1280, 360) if value else Vector2i(1280, 720))

func toggle_settings() -> void:
	if settings_panel.visible:
		close_settings()
		return
	settings_dirty = false
	was_paused_before_menu = emulator.paused
	if emulator.loaded: emulator.set_paused(true)
	emulator.gamepad.set_menu_active(true)
	settings_panel.show()
	menu.open_pause()
	refresh_startup_status()

func close_settings() -> void:
	if not is_instance_valid(settings_panel) or not settings_panel.visible: return
	if not save_settings():
		menu.show_error("Settings could not be saved. Check free space and user-folder permissions. Your changes are still here.")
		return
	menu.error_label.hide()
	clear_menu_gamepad()
	settings_panel.hide()
	emulator.gamepad.set_menu_active(false)
	if emulator.loaded: emulator.set_paused(was_paused_before_menu)
	if not is_instance_valid(sbs_prompt): power_on.begin()

func preview_power_on() -> void:
	var already_started: bool = power_on.started
	close_settings()
	if not settings_panel.visible and already_started: power_on.begin(true)

func choose_rom() -> void:
	if not settings_panel.visible: toggle_settings()
	menu.open_library()

func load_game(path: String) -> bool:
	startup_message = ""
	var restore_paused := was_paused_before_menu
	var opened: bool = emulator.load_rom(path)
	if not opened:
		startup_message = "Could not open the game. Check the ROM location and emulator files. " + emulator.status
		if not settings_panel.visible: toggle_settings()
		if emulator.loaded: was_paused_before_menu = restore_paused
		menu.show_error(startup_message)
	elif settings_panel.visible:
		emulator.set_paused(true)
		was_paused_before_menu = false
		menu.refresh()
	refresh_startup_status()
	return opened

func save_library() -> Error:
	var recent := settings_store.read("user://recent.cfg")
	recent.set_value("library", "last_game", last_game_path)
	recent.set_value("library", "default_rom_dir", default_rom_dir)
	return SettingsStore.write("user://recent.cfg", recent)

func build_settings() -> void:
	menu = Menu.new()
	menu.host = self
	music.playback_error.connect(func(message):
		if is_instance_valid(menu) and menu.visible: menu.show_error(message)
		else: show_notice(message))
	music.transport_changed.connect(func():
		if is_instance_valid(menu) and menu.visible and menu.mode=="pause": menu.refresh())
	music.status_changed.connect(func():
		if is_instance_valid(menu) and menu.visible: menu.refresh_labels())
	settings_panel = menu
	menu_view.add_child(menu)
	refresh_startup_status()

func profile_path() -> String:
	return "user://presets/slot-%d.cfg" % selected_profile

func save_profile(title: String) -> bool:
	var config := ConfigFile.new()
	SettingsStore.copy_sections(capture_settings(), config, PackedStringArray(["view","room","crt","picture","emulation"]))
	config.set_value("meta","name",title.strip_edges().left(32) if not title.strip_edges().is_empty() else PROFILE_NAMES[selected_profile])
	if SettingsStore.write(profile_path(),config) == OK:
		show_notice("Setup saved: " + str(config.get_value("meta","name")))
		return true
	show_notice("Setup could not be saved. Check free space and user-folder permissions.")
	return false

func load_profile() -> void:
	if not FileAccess.file_exists(profile_path()) and not FileAccess.file_exists(profile_path()+".bak"):
		show_notice("This setup slot is empty. Save a setup here first.")
		return
	var reader := SettingsStore.new()
	var saved := reader.read(profile_path())
	if not saved.has_section("view"):
		show_notice("Setup could not be read. Current settings are unchanged.")
		return
	profile_undo = capture_settings()
	var merged := capture_settings()
	SettingsStore.copy_sections(saved,merged,PackedStringArray(["view","room","crt","picture","emulation"]))
	# Validate against live types before applying user-editable files.
	var validator := ConfigFile.new()
	validator.parse(merged.encode_to_text())
	apply_settings(validated_settings(validator,profile_undo))
	if active_game_key.is_empty(): picture_baseline = capture_settings()
	rebuild_settings()
	show_notice("Setup loaded. Undo is available in Saved setups." + (" " + reader.warning if not reader.warning.is_empty() else ""))

func validated_settings(config: ConfigFile, fallback: ConfigFile) -> ConfigFile:
	for section in fallback.get_sections():
		for key in fallback.get_section_keys(section):
			var old = fallback.get_value(section,key)
			var value = config.get_value(section,key,old)
			var valid := typeof(value) == typeof(old)
			if typeof(old) in [TYPE_INT,TYPE_FLOAT]: valid = typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))
			if not valid: config.set_value(section,key,old)
	return config

func undo_profile() -> void:
	if profile_undo == null:
		show_notice("Load a saved setup first; then you can undo it here.")
		return
	apply_settings(profile_undo)
	profile_undo = null
	if active_game_key.is_empty(): picture_baseline = capture_settings()
	rebuild_settings()
	show_notice("Previous setup restored")

func save_game_preferences() -> bool:
	if active_game_key.is_empty(): return true
	var config := ConfigFile.new()
	SettingsStore.copy_sections(capture_settings(),config,PICTURE_SECTIONS)
	var path := "user://games/"+active_game_key+".cfg"
	var baseline := ConfigFile.new()
	SettingsStore.copy_sections(picture_baseline,baseline,PICTURE_SECTIONS)
	if config.encode_to_text() == baseline.encode_to_text():
		# No override means future global changes also apply to this game.
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(path+suffix) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix)) != OK:
				show_notice("Could not clear the game's picture override. Check user-folder permissions.")
				return false
		return true
	var error := SettingsStore.write(path,config)
	if error != OK: show_notice("Game picture settings could not be saved. Check free space.")
	return error == OK

func change_game_preferences(active: bool) -> void:
	if not active_game_key.is_empty():
		save_game_preferences()
		var restore := capture_settings()
		SettingsStore.copy_sections(picture_baseline,restore,PICTURE_SECTIONS)
		apply_settings(restore)
	active_game_key = emulator.rom_hash if active and remember_game_picture else ""
	if not active_game_key.is_empty():
		var path := "user://games/"+active_game_key+".cfg"
		var defaults := capture_settings()
		var reader := SettingsStore.new()
		var saved := reader.read(path,defaults)
		var merged := capture_settings()
		SettingsStore.copy_sections(saved,merged,PICTURE_SECTIONS)
		apply_settings(merged)
		if not reader.warning.is_empty(): startup_message = reader.warning
	settings_dirty = true

func set_remember_game_picture(enabled: bool) -> void:
	if enabled == remember_game_picture: return
	if not enabled: change_game_preferences(false)
	remember_game_picture = enabled
	if enabled and emulator.loaded: change_game_preferences(true)
	settings_dirty = true

func forget_game_picture() -> void:
	if active_game_key.is_empty():
		show_notice("Load a game with per-game picture enabled first.")
		return
	var merged := capture_settings()
	SettingsStore.copy_sections(picture_baseline,merged,PICTURE_SECTIONS)
	apply_settings(merged)
	save_game_preferences()
	rebuild_settings()
	show_notice("This game now uses the global picture settings")

func refresh_startup_status() -> void:
	if not is_instance_valid(menu): return
	var gaming_mode := not OS.get_environment("GAMESCOPE_WAYLAND_DISPLAY").is_empty()
	for key in ["XDG_CURRENT_DESKTOP","XDG_SESSION_DESKTOP","DESKTOP_SESSION"]:
		gaming_mode = gaming_mode or OS.get_environment(key).to_lower().contains("gamescope")
	var state := StartupStatus.describe(emulator.loaded,default_rom_dir,last_game_path,
		provider is LinuxTracking,provider.valid,provider.status,stereo,get_window().size,gaming_mode)
	menu.status_title = state.title
	menu.status_detail = state.detail + (" " + startup_message if not startup_message.is_empty() else "")
	if menu.visible: menu.refresh_labels()

func reset_selected_option() -> void:
	menu.reset_option()

func reset_all_options() -> void:
	if not settings_panel.visible: return
	for index in range(5): SettingsDefaults.apply(self,index)
	emulator.tv_audio.reset_defaults()
	music.reset_defaults()
	power_on.enabled=true; power_on.sound_level=.60; power_on.apply()
	rebuild_settings()
	show_notice("All settings reset to defaults")

func rebuild_settings() -> void:
	settings_dirty = false
	if is_instance_valid(menu): menu.refresh()

func load_showcase_setup() -> void:
	profile_undo=capture_settings()
	var merged := capture_settings()
	SettingsStore.copy_sections(Showcase.config(),merged,PackedStringArray(["view","room","crt","picture","audio","atmosphere","emulation"]))
	merged.set_value("preferences","metrics_visible",false)
	apply_settings(merged)
	if active_game_key.is_empty(): picture_baseline=capture_settings()
	rebuild_settings()
	show_notice("Deck Showcase loaded. Undo is available in Saved setups.")

func apply_picture_preset(name: String) -> void:
	if name=="showcase":
		var merged := capture_settings()
		SettingsStore.copy_sections(Showcase.config(),merged,PICTURE_SECTIONS)
		# Picture presets retain this game's carefully adjusted fitting.
		for field in world.picture.FIT_FIELDS: merged.set_value("picture",field[0],world.picture.values[field[0]])
		apply_settings(merged)
		rebuild_settings(); show_notice("Deck Showcase (PAL) picture preset"); return
	world.picture.preset(name)
	scanlines = 0.0 if name == "clean" else 0.70
	phosphor_mask = 0.0 if name == "clean" else (0.50 if name == "rgb" else 0.40)
	phosphor_glow = 0.0 if name == "clean" else 0.25
	world.screen_material.set_shader_parameter("scanlines", scanlines)
	world.screen_material.set_shader_parameter("mask_strength", phosphor_mask)
	world.screen_material.set_shader_parameter("glow_strength", phosphor_glow)
	rebuild_settings()
	show_notice("%s picture preset" % name.capitalize())

func fit_tv_to_view() -> void:
	var aspect := float(maxi(views[0].size.x, 1))/float(maxi(views[0].size.y, 1))
	var vertical := tan(deg_to_rad(vertical_fov)*0.5)*0.85
	var horizontal := vertical*aspect
	var eye_margin := ipd*0.5*(1.0+5.0/convergence)
	var scale_limit := minf((4.8*vertical-absf(height_offset))/0.65, (4.8*horizontal-eye_margin)/0.9)
	if scale_limit < 0.5:
		height_offset = 0.0
		scale_limit = minf(4.8*vertical/0.65, (4.8*horizontal-eye_margin)/0.9)
	tv_scale = clampf(minf(tv_scale, scale_limit), 0.5, 1.6)
	distance = clampf(maxf((0.65*tv_scale+absf(height_offset))/vertical, (0.9*tv_scale+eye_margin)/horizontal)+0.2, 1.2, 5.0)
	recenter()
	rebuild_settings.call_deferred()
	show_notice("TV fitted to neutral view")

func show_notice(message: String) -> void:
	for notice in notices: notice.text = message
	notice_time = 4.0
	if is_instance_valid(menu): menu.notify(message)

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

func clear_menu_gamepad() -> void:
	if is_instance_valid(menu): menu.clear_input()

func handle_settings_gamepad(event: InputEvent) -> bool:
	return menu.handle(event)

func navigate_settings(direction: Vector2i) -> void:
	menu.navigate(direction)

func set_room_value(property: String, value: float) -> void:
	world.set(property, value)
	if property == "fade_end": world.fade_begin = minf(world.fade_begin, value - 0.5)
	world.apply_room_settings()

func room_preset(preset: String) -> void:
	var values: Array = [0.45, 4.5, 1.6, 0.70, 1.15, 4.5, 9.0]
	if preset == "bright": values = [0.85, 5.0, 2.3, 0.40, 1.25, 6.0, 12.0]
	elif preset == "dim": values = [0.15, 2.5, 0.5, 0.80, 0.8, 3.5, 7.0]
	var keys := ["ambient", "key_energy", "fill_energy", "warmth", "floor_brightness", "fade_begin", "fade_end"]
	for i in keys.size(): world.set(keys[i], values[i])
	world.apply_room_settings()

func capture_settings() -> ConfigFile:
	var config := ConfigFile.new()
	for key in music.DEFAULTS: config.set_value("music",key,music.get(key))
	config.set_value("atmosphere","power_on",power_on.enabled)
	config.set_value("atmosphere","power_sound",power_on.sound_level)
	for key in emulator.tv_audio.DEFAULTS: config.set_value("audio",key,emulator.tv_audio.get(key))
	config.set_value("preferences", "per_game_picture", remember_game_picture)
	config.set_value("preferences","metrics_visible",metrics_visible)
	config.set_value("emulation", "run_ahead", emulator.run_ahead)
	config.set_value("view", "right_stick_distance", right_stick_distance)
	config.set_value("view", "distance_speed", distance_speed)
	for setting in ROOM_FIELDS: config.set_value("room", setting[0], world.get(setting[0]))
	config.set_value("room", "shadows", world.shadows)
	config.set_value("room", "show_rug", world.show_rug)
	for pair in [["distance", distance], ["height_offset", height_offset], ["scale", tv_scale], ["ipd", ipd], ["convergence", convergence], ["edge_fade", edge_fade], ["vertical_fov", vertical_fov], ["smoothing", smoothing], ["motion_predict", motion_predict]]:
		config.set_value("view", pair[0], pair[1])
	for axis in ["yaw", "pitch", "roll"]:
		config.set_value("tracking", "invert_" + axis, provider.get("invert_" + axis))
	config.set_value("crt", "scanlines", scanlines)
	config.set_value("crt", "mask", phosphor_mask)
	config.set_value("crt", "glow", phosphor_glow)
	for field in world.picture.all_fields(): config.set_value("picture", field[0], world.picture.values[field[0]])
	config.set_value("picture", "connection", world.picture.mode)
	config.set_value("picture", "keep_aspect", world.picture.keep_aspect)
	config.set_value("crt", "glass", glass_reflections)
	config.set_value("crt", "curvature", screen_curvature)
	return config

func save_settings() -> bool:
	var config := capture_settings()
	if remember_game_picture and not active_game_key.is_empty():
		if not save_game_preferences(): return false
		SettingsStore.copy_sections(picture_baseline, config, PICTURE_SECTIONS)
	else: picture_baseline = config
	var error := SettingsStore.write("user://settings.cfg", config)
	if error != OK:
		show_notice("Settings could not be saved. Check free space and user-folder permissions.")
		return false
	return true
