extends Control

const Simulated = preload("res://scripts/tracking/simulated_tracking.gd")
const WindowsTracking = preload("res://scripts/tracking/xr_windows_tracking.gd")
const LinuxTracking = preload("res://scripts/tracking/xr_linux_tracking.gd")
const OpenTrackTracking = preload("res://scripts/tracking/opentrack_tracking.gd")
const PosePrediction = preload("res://scripts/tracking/pose_prediction.gd")
const SbsExit = preload("res://scripts/ui/sbs_exit.gd")
const CRTWorld = preload("res://scripts/rendering/crt_world.gd")
const Pattern = preload("res://scripts/content/test_pattern.gd")
const LoadingScreen = preload("res://scripts/content/loading_screen.gd")
const Emulation = preload("res://scripts/emulation/emulation_session.gd")
const VideoSession = preload("res://scripts/video/video_session.gd")
const VideoLibrary = preload("res://scripts/video/video_library.gd")
const VideoBar = preload("res://scripts/ui/video_bar.gd")
const FfmpegInstaller = preload("res://scripts/video/ffmpeg_installer.gd")
const Menu = preload("res://scripts/ui/menu_controller.gd")
var menu: PanelContainer
const Showcase = preload("res://scripts/presets/showcase.gd")
const SettingsDefaults = preload("res://scripts/ui/settings_defaults.gd")
const SettingsStore = preload("res://scripts/ui/settings_store.gd")
const CoreRegistry = preload("res://scripts/emulation/core_registry.gd")
const StartupStatus = preload("res://scripts/ui/startup_status.gd")
const PICTURE_SECTIONS := ["crt", "picture"]
## Picture profile used for every video, kept apart from games and the test signal.
const VIDEO_PROFILE := "video"
const VIDEO_CHECKPOINT_SECONDS := 30.0
const PROFILE_NAMES := ["Everyday", "Evening", "Bright room"]
var settings_store := SettingsStore.new()
var picture_baseline := ConfigFile.new()
var active_game_key := ""
var remember_game_picture := Showcase.PER_GAME_PICTURE
var selected_profile := 0
var profile_undo: ConfigFile
var settings_dirty := false
var capture_requested := "--capture" in OS.get_cmdline_user_args()
var diagnose_requested := "--diagnose-view" in OS.get_cmdline_user_args()
var startup_message := ""
var recovery_elapsed := 0.0
var diagnostics_elapsed := 0.0
signal screenshot_saved(path: String)
var taking_screenshot := false
var last_screenshot_path := ""
var notices: Array[Label] = []
var video_bars: Array = []
var notice_time := 0.0
var picture_preset_id := ""
var picture_preset_signature := ""
## The room preset in use and the room it set, as for picture presets.
var room_preset_id := ""
var room_preset_signature := ""
var rooms = preload("res://scripts/ui/room_presets.gd").new()
## Box art from the player's own scrapes, for game rows and Continue.
var box_art: Node
var menu_large_text := false
var menu_high_contrast := false
var menu_reduced_motion := false
var menu_sounds := false
## The menu floats in front of the TV with lifted selections and a dimmed room.
var menu_depth := true
## With menu depth on, the menu bends gently towards you at its sides.
var menu_curve := false
## The menu on the TV itself (menu_on_tv.gd), or floating in front of it.
var menu_on_tv := true
var tv_menu: Node
var menu_was_open := false
## A light controller tick as the menu selection moves, and on confirm.
var menu_haptics := false
## How strong those ticks are, 10% to 100% of the motors' range.
var haptic_strength := 0.8
var menu_depth_view: Node
## The settings as the menu opened, so closing it only says "Saved" after a change.
var settings_on_open := ""
var emulator: Node
var video: Node
var music: Node
var power_on: Node
## Channel changes, degauss and power-off (scripts/rendering/tv_effects.gd).
var tv_effects: Node
var exiting := false
var signal_view: SubViewport
## The loading card as the tube shows it: its 256x240 graphics three times over
## with hard pixels, and its words sharp on top (loading_text.gd), 720 lines
## like the menu.
var card_view: SubViewport
var was_paused_before_menu := false
var provider: TrackingProvider = Simulated.new()
## "glasses" (XR Gaming on Linux, VITURE SDK on Windows) or "opentrack" (UDP 4242).
var tracking_source := "glasses"
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
## Room settings that are on or off, besides shadows.
const ROOM_SWITCHES := ["show_clock_radio", "clock_24_hour", "show_vcr", "show_game_boxes", "show_game_cover", "follow_clock", "crt_whine"]
const ROOM_FIELDS := [
	["spill_strength", "Screen glow (0 = off)", 0.0, 1.0, 0.05],
	["screen_bloom", "Screen bloom in the dark (0 = off)", 0.0, 1.0, 0.05],
	["ambient", "Ambient fill", 0.0, 1.5, 0.02],
	["key_energy", "Warm lamp brightness", 0.0, 8.0, 0.1],
	["fill_energy", "Front fill brightness", 0.0, 4.0, 0.1],
	["warmth", "Light warmth", 0.0, 1.0, 0.05],
	["shadow_strength", "Shadow darkness", 0.0, 1.0, 0.05],
	["cabinet_ao_strength", "Casing recess shading", 0.0, 1.0, 0.05],
	["cabinet_grain_strength", "Plastic grain", 0.0, 1.0, 0.05],
	["lamp_height", "Lamp height", 0.5, 4.0, 0.1],
	["lamp_side", "Lamp side", -3.0, 3.0, 0.1],
	["floor_brightness", "Floor brightness", 0.0, 2.0, 0.05],
	["fade_begin", "Room fade begins (m)", 2.0, 10.0, 0.25],
	["fade_end", "Room fades to black (m)", 3.0, 16.0, 0.25]]
var tv_scale: float = Showcase.VIEW.tv_scale
var ipd: float = Showcase.VIEW.ipd
var convergence: float = Showcase.VIEW.convergence
var smoothing: float = Showcase.VIEW.smoothing
var motion_predict: float = Showcase.VIEW.motion_predict
var vertical_fov := 50.0
var desktop_fov := 50.0
var xr_fov := 24.0
var edge_fade: float = Showcase.VIEW.edge_fade
var scanlines: float = Showcase.CRT.scanlines
var phosphor_mask: float = Showcase.CRT.phosphor_mask
var phosphor_glow: float = Showcase.CRT.phosphor_glow
var glass_reflections: float = Showcase.CRT.glass_reflections
var screen_curvature: float = Showcase.CRT.screen_curvature
var fade_material := ShaderMaterial.new()
var world: Node3D
var pattern: Node2D
## Disc games show a loading card on the TV while they unpack and boot, until
## their picture starts: never a black screen. loading_path is the game it is for.
var loading_screen: Node2D
var loading_path := ""
var loading_started := 0
## A game still black after this long is shown anyway, whatever it draws.
const LOADING_TIMEOUT_MSEC := 30000
## True while load_game swaps games behind the card, which must stay up.
var loading_game := false
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
## Videos are opt-in: nothing appears in the library until a folder is chosen.
var video_dir := ""
var video_style := 0
var video_lines := 240
var video_hardware := true
## 0 shows interlaced video field by field (TV motion), 1 blends the fields.
var video_interlace := 0
## Turn on a video's first subtitle option unless it has its own remembered choice.
var video_subtitles := false
## Green VCR mode text (PLAY, PAUSE, FF, REW) drawn on the video picture.
var video_osd := true
## VHS tape look for videos: 0 off, 1 VHS, 2 worn VHS.
var video_tape := 0
## The VCR's mechanism sounds while videos play.
var video_vcr_sounds := true
var vcr_sounds: Node
## Videos share one picture of their own (true), or use the global picture.
var video_own_picture := true
var ffmpeg_installer: Node
var video_library := VideoLibrary.new()
var video_checkpoint := 0.0
## Held D-pad or arrow direction while watching: repeats seeks to scrub.
var video_scrub := 0
var video_scrub_held := 0.0
var video_scrub_wait := 0.0
const SCRUB_DELAY := 0.45
const SCRUB_REPEAT := 0.15
var default_rom_dir := "":
	set(value):
		default_rom_dir = value
		CoreRegistry.library_root = value
var display_report_elapsed := 0.0
var view_diagnosed := false
var sbs_prompt: Control
var sbs_startup := false
var sbs_starting := false
var startup_loading := false
var windows_sbs_size := Vector2i.ZERO
var windows_fixed_start := false

func _ready() -> void:
	# A previously downloaded FFmpeg (Windows) is found before anything asks
	# whether video playback is available.
	FfmpegInstaller.finish_removal()
	FfmpegInstaller.use_installed()
	var migration := preload("res://scripts/content/user_data_migration.gd").migrate()
	if migration.error!=OK: startup_message="Previous settings could not be fully copied. Original data is safe; check storage permissions."
	Input.use_accumulated_input = false
	var startup_args := OS.get_cmdline_user_args()
	for arg in startup_args:
		if arg in ["--sbs","--full-sbs","--sbs-session","--sbs-session-manual","--sbs-prompt"]:
			Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	if OS.get_name()=="Windows" and ("--windows-xr" in startup_args or (not OS.has_feature("editor") and not "--script" in OS.get_cmdline_args())):
		sbs_prompt=preload("res://scripts/ui/windows_setup.gd").new()
		sbs_prompt.z_index=4096
		sbs_prompt.xr_ready.connect(func(size: Vector2i):
			windows_sbs_size=size
			sbs_startup=true
			start_sbs_session())
		sbs_prompt.desktop_ready.connect(func():
			windows_fixed_start=true
			start_application()
			sbs_prompt.queue_free()
			sbs_prompt=null
			set_process(true))
		add_child(sbs_prompt)
		set_process(false)
		return
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
	# Engine boot remains black. Draw branding only once we can control eye layout.
	if not OS.has_feature("editor") and DisplayServer.get_name()!="headless" and not "--script" in OS.get_cmdline_args():
		startup_loading=true;set_process(false)
		var brand=preload("res://scripts/ui/startup_brand.gd").new()
		brand.stereo="--sbs" in startup_args or "--full-sbs" in startup_args
		brand.z_index=4096;add_child(brand)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		start_application()
		brand.queue_free();startup_loading=false;set_process(true)
	else: start_application()

func sbs_target_size() -> Vector2i:
	if windows_sbs_size!=Vector2i.ZERO: return windows_sbs_size
	# The probe profile is explicit; never infer optical SBS from aspect ratio alone.
	if not OS.get_environment("CRT_XR_DISPLAY_PROBE").is_empty():
		var parts := OS.get_environment("CRT_XR_SBS_SIZE").split("x")
		if parts.size()==2:
			var size := Vector2i(int(parts[0]),int(parts[1]))
			if size.x>=640 and size.x<=16384 and size.x%2==0 and size.y>=480 and size.y<=8192: return size
	return Vector2i(3840,1080)

func start_sbs_session() -> void:
	if sbs_starting: return
	sbs_starting = true
	sbs_prompt.darken()
	# Submit black before synchronous asset/core loading, keeping this window.
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_size(sbs_target_size())
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
	if not windows_fixed_start and OS.get_name() in ["Linux", "Windows"] and not "--simulate" in OS.get_cmdline_user_args():
		use_tracking(true)
	signal_view = SubViewport.new()
	signal_view.size = Vector2i(256, 240)
	signal_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	signal_view.disable_3d = true
	add_child(signal_view)
	pattern = Pattern.new()
	signal_view.add_child(pattern)
	loading_screen = LoadingScreen.new()
	loading_screen.visible = false
	loading_screen.set_process(false)
	signal_view.add_child(loading_screen)
	card_view = SubViewport.new()
	card_view.size = Vector2i(768, 720)
	card_view.disable_3d = true
	card_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(card_view)
	var card_pixels := TextureRect.new()
	card_pixels.texture = signal_view.get_texture()
	card_pixels.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_pixels.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_pixels.stretch_mode = TextureRect.STRETCH_SCALE
	card_pixels.size = Vector2(card_view.size)
	card_view.add_child(card_pixels)
	var card_words := preload("res://scripts/content/loading_text.gd").new()
	card_words.card = loading_screen
	card_view.add_child(card_words)
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
		# Each eye fades at its own edges, including at the SBS join.
		panel.material = fade_material
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
		var bar := VideoBar.new()
		panel.add_child(bar)
		video_bars.append(bar)
	emulator = Emulation.new()
	add_child(emulator)
	music=preload("res://scripts/audio/music_player.gd").new()
	add_child(music)
	music.game_player=emulator.player
	power_on=preload("res://scripts/rendering/tv_power_on.gd").new()
	add_child(power_on)
	power_on.setup(world.screen_material,world.screen_light,emulator.tv_audio)
	tv_effects=preload("res://scripts/rendering/tv_effects.gd").new()
	add_child(tv_effects)
	tv_effects.setup(world.screen_material,world.screen_light,emulator.tv_audio)
	tv_effects.power_on=power_on
	Input.joy_connection_changed.connect(func(device, connected):
		if not connected:
			emulator.gamepad.disconnect_device(device)
			clear_menu_gamepad()
			show_notice("Controller disconnected. Reconnect it to continue; Escape opens settings with a keyboard.")
		print("Controller ", device, " connected: ", Input.get_joy_name(device) if connected else "disconnected"))
	for device in Input.get_connected_joypads():
		print("Controller ", device, ": ", Input.get_joy_name(device))
	emulator.content_changed.connect(func(texture):
		if loading_path.is_empty(): world.picture.set_source(texture, true))
	emulator.frame_presented.connect(func(image: Image):
		# The loading card stays up through a disc's black boot frames.
		if not loading_path.is_empty():
			if not picture_started(image): return
			end_loading()
		if tv_menu == null or tv_menu.lights_room(): world.screen_light.set_image(image)
		world.picture.frame_presented(image))
	emulator.game_changed.connect(func(active):
		# A game stopped from the menu takes its loading card with it.
		if not active and not loading_game: end_loading()
		show_game_cover(emulator.rom_path if active else "")
		change_game_preferences(active)
		show_programme(active, emulator.fps, emulator.display_aspect)
		if active:
			last_game_path = emulator.rom_path
			if not play_history.played(last_game_path): show_notice("Could not save recently played games")
			if save_library() != OK: show_notice("Could not save the recent game location"))
	video = VideoSession.new()
	add_child(video)
	ffmpeg_installer = FfmpegInstaller.new()
	add_child(ffmpeg_installer)
	video.audio_source = emulator.player
	vcr_sounds = preload("res://scripts/video/vcr_sounds.gd").new()
	vcr_sounds.enabled = video_vcr_sounds
	vcr_sounds.video = video
	add_child(vcr_sounds)
	# The mechanism follows the game volume, like the video's own sound.
	video.mechanism.connect(func(event):
		vcr_sounds.volume_db = emulator.player.volume_db
		vcr_sounds.mechanism(event))
	video.content_changed.connect(func(texture): world.picture.set_source(texture, true))
	video.frame_presented.connect(func(image: Image):
		if tv_menu == null or tv_menu.lights_room(): world.screen_light.set_image(image))
	video.frame_presented.connect(world.picture.frame_presented)
	# The decoder always delivers a 4:3 frame; display styles are applied inside it.
	video.active_changed.connect(func(active):
		change_game_preferences(active, VIDEO_PROFILE)
		show_programme(active, video.field_rate(), 4.0 / 3.0))
	video.finished.connect(func():
		# Watched to the end: the next play starts from the beginning.
		video_library.remember(video.path, float(video.info.duration), float(video.info.duration), video.style)
		flash_video_bar("Finished · A plays it again · B opens the menu"))
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
	video_dir = str(recent.get_value("video", "folder", ""))
	video_style = clampi(int(recent.get_value("video", "style", 0)), 0, VideoSession.STYLES.size() - 1)
	# "line_count" replaces "lines": the old key held the earlier 480 default,
	# which hid the scanlines, so it is not carried over.
	video_lines = 480 if int(recent.get_value("video", "line_count", 240)) == 480 else 240
	video_hardware = bool(recent.get_value("video", "hardware", true))
	video_interlace = clampi(int(recent.get_value("video", "interlace", 0)), 0, VideoSession.INTERLACE_MODES.size() - 1)
	video_subtitles = bool(recent.get_value("video", "subtitles", false))
	video_osd = bool(recent.get_value("video", "osd", true))
	video_tape = clampi(int(recent.get_value("video", "tape", 0)), 0, 2)
	video_vcr_sounds = bool(recent.get_value("video", "vcr_sounds", true))
	if vcr_sounds != null: vcr_sounds.enabled = video_vcr_sounds
	video_own_picture = bool(recent.get_value("video", "own_picture", true))
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
	rooms.host = self
	box_art = preload("res://scripts/content/box_art.gd").new()
	box_art.name = "BoxArt"
	add_child(box_art)
	box_art.cover_ready.connect(func(rom_path, texture):
		if emulator.loaded and emulator.rom_path == rom_path: world.set_game_cover(texture))
	build_settings()
	music.restore_resume()
	for panel in panels:
		var overlay := TextureRect.new()
		overlay.texture = menu_view.get_texture()
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(overlay)
		menu_overlays.append(overlay)
	menu_depth_view = preload("res://scripts/ui/menu_depth.gd").new()
	menu_depth_view.name = "MenuDepth"
	add_child(menu_depth_view)
	menu_depth_view.setup(self, menu_overlays, panels)
	tv_menu = preload("res://scripts/ui/menu_on_tv.gd").new()
	tv_menu.name = "MenuOnTV"
	tv_menu.host = self
	add_child(tv_menu)
	set_stereo(sbs_startup or "--sbs" in OS.get_cmdline_user_args() or "--full-sbs" in OS.get_cmdline_user_args())
	if "--full-sbs" in OS.get_cmdline_user_args() or sbs_startup:
		set_stereo(true)
		DisplayServer.window_set_size(sbs_target_size())
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("CRT XR ready / Godot ", Engine.get_version_info().string, " / ", OS.get_name())
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--rom":
			load_game(arguments[index + 1])
		elif arguments[index] == "--video":
			# Developer flag until videos are in the library menu.
			if not play_video(arguments[index + 1]): show_notice(video.status)
	if "--last-game" in arguments and not "--rom" in arguments and not last_game_path.is_empty() and FileAccess.file_exists(last_game_path):
		if not settings_panel.visible: toggle_settings()
		menu.games.select_file(last_game_path)
	startup_message = settings_store.warning if startup_message.is_empty() else startup_message
	if not emulator.loaded and not video.loaded and not settings_panel.visible and not "--capture" in arguments:
		toggle_settings()
	refresh_startup_status()
	if "--capture" in arguments:
		power_on.started=true; power_on.set_progress(1.0)
	elif not settings_panel.visible and not is_instance_valid(sbs_prompt): power_on.begin()

func apply_settings(config: ConfigFile) -> void:
	SettingsStore.migrate_view_fov(config)
	SettingsStore.migrate_screen_glow(config)
	picture_preset_id=str(config.get_value("menu","picture_preset_id",""))
	picture_preset_signature=str(config.get_value("menu","picture_preset_signature",""))
	room_preset_id=str(config.get_value("menu","room_preset_id",""))
	room_preset_signature=str(config.get_value("menu","room_preset_signature",""))
	for key in ["menu_large_text","menu_high_contrast","menu_reduced_motion","menu_sounds","menu_haptics","menu_curve"]: set(key,bool(config.get_value("accessibility",key,false)))
	menu_depth = bool(config.get_value("accessibility","menu_depth",true))
	menu_on_tv = bool(config.get_value("accessibility","menu_on_tv",true))
	haptic_strength = clampf(float(config.get_value("accessibility","haptic_strength",0.8)),0.1,1.0)
	for key in music.DEFAULTS: music.set(key,config.get_value("music",key,music.DEFAULTS[key]))
	music.apply()
	metrics_visible=bool(config.get_value("preferences","metrics_visible",false))
	power_on.enabled=bool(config.get_value("atmosphere","power_on",true))
	power_on.sound_level=float(config.get_value("atmosphere","power_sound",0.60))
	power_on.reduced_motion=menu_reduced_motion
	power_on.apply()
	tv_effects.channel_change=bool(config.get_value("atmosphere","channel_change",true))
	tv_effects.power_off_effect=bool(config.get_value("atmosphere","power_off",true))
	tv_effects.reduced_motion=menu_reduced_motion
	for key in emulator.tv_audio.DEFAULTS:
		emulator.tv_audio.set(key,config.get_value("audio",key,emulator.tv_audio.DEFAULTS[key]))
	emulator.tv_audio.apply()
	right_stick_distance = bool(config.get_value("view", "right_stick_distance", Showcase.VIEW.right_stick_distance))
	distance_speed = clampf(config.get_value("view", "distance_speed", Showcase.VIEW.distance_speed), 0.2, 2.0)
	for setting in ROOM_FIELDS:
		world.set(setting[0], clampf(config.get_value("room", setting[0], world.get(setting[0])), setting[2], setting[3]))
	world.shadows = bool(config.get_value("room", "shadows", true))
	world.floor_style = clampi(int(config.get_value("room", "floor_style", Showcase.ROOM.floor_style)), 0, world.FLOOR_STYLES.size() - 1)
	for key in ROOM_SWITCHES:
		world.set(key, bool(config.get_value("room", key, Showcase.ROOM[key])))
	world.ambience = clampi(int(config.get_value("room", "ambience", Showcase.ROOM.ambience)), 0, world.room_sound.CHOICES.size() - 1)
	world.ambience_level = clampf(float(config.get_value("room", "ambience_level", Showcase.ROOM.ambience_level)), 0.0, 1.0)
	var preview_depth = config.get_value("emulation", "run_ahead", 1)
	emulator.run_ahead = clampi(int(preview_depth), 0, 2)
	emulator.set_separate_preview(bool(config.get_value("emulation", "separate_preview", true)))
	distance = clampf(config.get_value("view", "distance", Showcase.VIEW.distance), 1.2, 5.0)
	height_offset = clampf(config.get_value("view", "height_offset", Showcase.VIEW.height_offset), -1.5, 1.5)
	tv_scale = clampf(config.get_value("view", "scale", Showcase.VIEW.tv_scale), 0.5, 1.6)
	ipd = clampf(config.get_value("view", "ipd", Showcase.VIEW.ipd), 0.0, 0.080)
	convergence = clampf(config.get_value("view", "convergence", Showcase.VIEW.convergence), 1.0, 10.0)
	edge_fade = clampf(config.get_value("view", "edge_fade", Showcase.VIEW.edge_fade), 0.0, 0.2)
	desktop_fov = clampf(config.get_value("view", "desktop_fov", desktop_fov),18.0,70.0)
	xr_fov = clampf(config.get_value("view", "xr_fov", xr_fov),18.0,70.0)
	# "glasses" uses the platform's own source (XR Gaming on Linux, the VITURE
	# SDK on Windows); "opentrack" listens for OpenTrack UDP from another tool.
	var source := str(config.get_value("tracking", "source", "glasses"))
	if source != tracking_source:
		tracking_source = source if source in ["glasses", "opentrack"] else "glasses"
		if provider.real: use_tracking(true)
	vertical_fov = xr_fov if provider.real else desktop_fov
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
	if video.loaded and not video.paused:
		video_checkpoint += delta
		if video_checkpoint >= VIDEO_CHECKPOINT_SECONDS: remember_video_position()
	if video.loaded and video_scrub != 0 and not settings_panel.visible:
		# Holding scrubs: after a short delay, repeat 10 s steps, then 30 s ones.
		video_scrub_held += delta
		video_scrub_wait -= delta
		if video_scrub_held >= SCRUB_DELAY and video_scrub_wait <= 0.0:
			video_scrub_wait = SCRUB_REPEAT
			video.seek_by(video_scrub * (30.0 if video_scrub_held > 2.0 else 10.0))
			flash_video_bar()
	var bar_allowed: bool = video.loaded and not settings_panel.visible
	world.vcr_counter = int(video.clock) if video.loaded else -1
	world.vcr_transport = video.transport()
	for bar in video_bars:
		bar.track(video.path.get_file().get_basename(), video.clock, float(video.info.get("duration", 0.0)), video.paused, delta, bar_allowed)
	for notice in notices: notice.visible = notice_time > 0.0
	var menu_open := settings_panel.visible
	tv_menu.update(delta)
	recovery_elapsed += delta
	if recovery_elapsed >= 1.0:
		recovery_elapsed = 0.0
		refresh_startup_status()
	# The menu on the TV is a live picture, so the tube keeps updating under it.
	world.picture.paused = (menu_open and not tv_menu.active) or (emulator.paused if emulator.loaded else pattern.paused) and not tv_menu.active
	if right_stick_distance and not menu_open:
		adjust_distance(emulator.gamepad.view_distance_axis() * distance_speed * delta)
	if distance_save_delay >= 0.0:
		distance_save_delay -= delta
		if distance_save_delay < 0.0: save_settings()
	for overlay in menu_overlays: overlay.visible = menu_open and not tv_menu.active
	for hud in diagnostics: hud.modulate.a = 0.0 if menu_open else 1.0
	var menu_mode := SubViewport.UPDATE_ALWAYS if menu_open else SubViewport.UPDATE_DISABLED
	# A page re-rendered while the menu is up lays its rows out over a few
	# frames; keep showing the last finished picture until it has settled, so
	# changing a setting does not flicker. (Not on opening: that would show a
	# stale menu.)
	if menu.hold_frames > 0:
		menu.hold_frames -= 1
		if menu_open and menu_was_open: menu_mode = SubViewport.UPDATE_DISABLED
	menu_was_open = menu_open
	if menu_view.render_target_update_mode != menu_mode: menu_view.render_target_update_mode = menu_mode
	provider.enabled = not menu_open and not emulator.loaded
	display_report_elapsed += delta
	if display_report_elapsed >= 1.0:
		display_report_elapsed = 0.0
		var report_path := OS.get_environment("CRT_XR_DISPLAY_STATUS")
		if not report_path.is_empty():
			var report := FileAccess.open(report_path, FileAccess.WRITE)
			if report:
				report.store_string(JSON.stringify({"stereo": stereo, "width": get_window().size.x,
					"height": get_window().size.y, "frames": Engine.get_process_frames()}))
				report.close()
	var previously_valid := tracking_was_valid
	provider.update(delta)
	if previously_valid and not provider.valid and provider.real:
		show_notice("Tracking lost — holding the view steady. Open Game for Retry glasses tracking or Fixed view.")
	if provider.valid and (needs_center or not tracking_was_valid):
		# A sample gap (including a blocked restore) does not move the room's
		# anchor. Rebase only for initial centering or a possible driver reset.
		if provider.real and (needs_center or not provider.recovery_keeps_reference()):
			center = provider.orientation * displayed.inverse()
		provider.acknowledge_recovery()
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
	# Write only on change: each transform write dirties the TV subtree and its lights.
	var tv_position: Vector3 = tv_menu.lean_position(Vector3(0, 1.25 + height_offset, -distance))
	if world.television.position != tv_position: world.television.position = tv_position
	if world.television.scale != Vector3.ONE * tv_scale: world.television.scale = Vector3.ONE * tv_scale
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
			diagnostics[i].text = "CRT XR   /   %s\n%s\nYaw %+.1f   Pitch %+.1f   Roll %+.1f\n%.2fm  /  IPD %.0fmm  /  %.0f fps\nL + R + Start / Esc: menu   R3 / R: recenter" % ["LEFT" if stereo and i == 0 else ("RIGHT" if stereo else "DESKTOP"), provider.status, a.y, a.x, a.z, distance, ipd * 1000, Engine.get_frames_per_second()]
	if capture_requested and Engine.get_process_frames() == 30 and not screenshot_pending:
		screenshot_pending = true
		capture.call_deferred()
	if diagnose_requested and Engine.get_process_frames() >= 180 and not view_diagnosed:
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
	if startup_loading: return
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
	if video.loaded and video_input(event):
		get_viewport().set_input_as_handled()
		return
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
					menu.play.state_action(false)
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
		if is_instance_valid(music): music.save_resume()

func recenter() -> void:
	if not provider.valid:
		needs_center = true
		return
	center = provider.orientation
	displayed = Quaternion.IDENTITY

## Switches between the glasses' own tracking and OpenTrack UDP, at once if tracking is on.
func set_tracking_source(source: String) -> void:
	tracking_source = source
	if provider.real: use_tracking(true)
	settings_dirty = true

func use_tracking(real_tracking: bool) -> void:
	var inversion := Vector3(float(provider.invert_pitch), float(provider.invert_yaw), float(provider.invert_roll))
	var changed := real_tracking != provider.real
	if changed:
		if provider.real: xr_fov=vertical_fov
		else: desktop_fov=vertical_fov
	provider.close()
	if not real_tracking: provider = Simulated.new()
	elif tracking_source == "opentrack": provider = OpenTrackTracking.new()
	else: provider = WindowsTracking.new() if OS.get_name() == "Windows" else LinuxTracking.new()
	provider.invert_pitch = bool(inversion.x)
	provider.invert_yaw = bool(inversion.y)
	provider.invert_roll = bool(inversion.z)
	center = Quaternion.IDENTITY
	displayed = Quaternion.IDENTITY
	needs_center = real_tracking
	tracking_was_valid = false
	if changed: vertical_fov = xr_fov if real_tracking else desktop_fov

func request_exit() -> void:
	remember_video_position()
	if not emulator.save_auto() or not save_settings():
		if not settings_panel.visible: toggle_settings()
		menu.show_error("Could not save before exiting. Check free space and save-folder permissions, then try Exit again.")
		return
	# The tube switches off before the window closes, once.
	if exiting: return
	exiting = true
	if tv_effects.play("power_off"): await tv_effects.finished
	# Glasses switched by their own button are still in SBS: ask for it before
	# Steam comes back doubled (glasses the driver switches, it switches back).
	var probe := OS.get_environment("CRT_XR_DISPLAY_PROBE")
	if stereo and SbsExit.needed(probe, OS.get_environment("CRT_XR_AUTO_SBS"), Time.get_unix_time_from_system()):
		if emulator.loaded: emulator.set_paused(true)
		var note := SbsExit.new()
		note.probe_path = probe
		note.z_index = 4096
		note.done.connect(get_tree().quit)
		add_child(note)
		return
	get_tree().quit()

func _exit_tree() -> void:
	if video_library != null: video_library.stop_thumbnails()
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

## A short rumble on every connected controller, when Controller vibration is on.
## Both motors run at the same strength: Steam Input passes only a faint
## version through to the Deck's haptics, so a weak motor alone barely registers.
func menu_vibrate(strength: float, seconds: float) -> void:
	if not menu_haptics: return
	var level := clampf(strength * haptic_strength, 0.0, 1.0)
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, level, level, seconds)

func set_stereo(value: bool) -> void:
	if not value and not OS.get_environment("CRT_XR_DISPLAY_STATUS").is_empty():
		return # The managed glasses session keeps its physical and rendered modes aligned.
	stereo = value
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN if value else Input.MOUSE_MODE_VISIBLE
	panels[1].visible = value
	views[1].render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	close_settings()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(Vector2i(1280, 360) if value else (Vector2i(1280,800) if "--deck-mono" in OS.get_cmdline_user_args() else Vector2i(1280,720)))

func toggle_settings() -> void:
	if settings_panel.visible:
		close_settings()
		return
	settings_dirty = false
	was_paused_before_menu = emulator.paused
	if emulator.loaded: emulator.set_paused(true)
	if video.loaded:
		was_paused_before_menu = video.paused
		video.set_paused(true, true)
		remember_video_position()
	emulator.gamepad.set_menu_active(true)
	settings_on_open = capture_settings().encode_to_text()
	settings_panel.show()
	menu.open_pause()
	refresh_startup_status()

func close_settings() -> void:
	if not is_instance_valid(settings_panel) or not settings_panel.visible: return
	if not save_settings():
		menu.show_error("Settings could not be saved. Check free space and user-folder permissions. Your changes are still here.")
		return
	menu.error_label.hide()
	if not settings_on_open.is_empty() and capture_settings().encode_to_text() != settings_on_open: show_notice("Settings saved")
	settings_on_open = ""
	clear_menu_gamepad()
	settings_panel.hide()
	emulator.gamepad.set_menu_active(false)
	if emulator.loaded: emulator.set_paused(was_paused_before_menu)
	if video.loaded and not video.ended: video.set_paused(was_paused_before_menu, true)
	if not is_instance_valid(sbs_prompt): power_on.begin()

## Degauss: closes the menu so the wobble and colour swirl show on the picture.
func degauss() -> void:
	close_settings()
	if not settings_panel.visible: tv_effects.play("degauss")

## The playing game's cover on the box beside the TV; "" puts the box's own print back.
func show_game_cover(rom_path: String) -> void:
	world.set_game_cover(null)
	if rom_path.is_empty(): return
	box_art.set_root(default_rom_dir)
	var cover: Texture2D = box_art.cover(rom_path)
	if cover != null: world.set_game_cover(cover)

func preview_power_on() -> void:
	var already_started: bool = power_on.started
	close_settings()
	if not settings_panel.visible and already_started: power_on.begin(true)

func choose_rom() -> void:
	if not settings_panel.visible: toggle_settings()
	menu.games.open_library()

## Switches the TV between the test signal and a programme (a game or a video).
func show_programme(active: bool, rate: float, aspect: float) -> void:
	var loading := not loading_path.is_empty()
	pattern.visible = not active and not loading
	pattern.set_process(pattern.visible)
	signal_view.render_target_update_mode = SubViewport.UPDATE_DISABLED if active and not loading else SubViewport.UPDATE_ALWAYS
	# Switching programmes is a channel change; the first is the power-on instead.
	# A game behind the loading card is the same channel.
	if active and not loading and power_on.progress >= 1.0: tv_effects.play("channel")
	if active:
		world.picture.source_rate = rate
		world.picture.source_aspect = aspect
		world.picture.refresh()
	else:
		world.picture.source_rate = 60.0
		world.picture.source_aspect = 4.0 / 3.0
		world.screen_light.set_image(null)
		# A disc's card has its own picture (card_view); the test signal is underneath it.
		world.picture.set_source(card_view.get_texture() if loading else signal_view.get_texture())

## Puts the loading card for a disc game on the TV, with progress 0..1 while it
## unpacks or negative while it boots (which restarts the black-screen timeout).
func show_loading(path: String, progress := -1.0) -> void:
	var starting := loading_path != path
	loading_path = path
	loading_started = Time.get_ticks_msec()
	loading_screen.title = path.get_file().get_basename()
	loading_screen.progress = progress
	if starting: loading_screen.elapsed = 0.0
	loading_screen.visible = true
	loading_screen.set_process(true)
	pattern.visible = false
	pattern.set_process(false)
	signal_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	card_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.screen_light.set_image(null)
	world.picture.source_rate = 60.0
	world.picture.source_aspect = 4.0 / 3.0
	world.picture.set_source(card_view.get_texture())
	if starting and power_on.progress >= 1.0: tv_effects.play("channel")

func update_loading(path: String, progress: float) -> void:
	if loading_path == path: loading_screen.progress = progress

## Takes the card down: to the game's picture once it runs, else the test signal.
func end_loading() -> void:
	if loading_path.is_empty(): return
	loading_path = ""
	loading_screen.visible = false
	loading_screen.set_process(false)
	card_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if emulator.loaded and emulator.texture != null:
		signal_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		world.picture.source_rate = emulator.fps
		world.picture.source_aspect = emulator.display_aspect
		world.picture.set_source(emulator.texture, true)
	elif not emulator.loaded and not video.loaded: show_programme(false, 60.0, 4.0 / 3.0)

## A game's picture has started once a frame shows something other than black,
## sampled on a coarse grid; after the timeout any frame counts.
func picture_started(image: Image) -> bool:
	if Time.get_ticks_msec() - loading_started > LOADING_TIMEOUT_MSEC: return true
	if image == null or image.is_empty(): return false
	var lit := 0
	for row in range(12):
		for column in range(16):
			var colour := image.get_pixel((column * 2 + 1) * image.get_width() / 32, (row * 2 + 1) * image.get_height() / 24)
			if maxf(colour.r, maxf(colour.g, colour.b)) > 0.12: lit += 1
	return lit >= 4

## Before a zipped disc unpacks: the playing game is saved and stopped (it would
## play on behind the card), any video too, and the card goes up.
func stop_for_disc(path: String) -> bool:
	if video.loaded: stop_video()
	if not emulator.save_auto(): return false
	emulator.stop()
	show_loading(path, 0.0)
	return true

func play_video(path: String, from_seconds := 0.0) -> bool:
	startup_message = ""
	end_loading()
	if emulator.loaded:
		emulator.save_auto()
		emulator.stop()
	remember_video_position()
	# Music would talk over the programme; it stays paused where it was.
	if music.player.playing and not music.player.stream_paused: music.toggle_playback()
	video.lines = video_lines
	video.hardware = video_hardware
	video.interlace = video_interlace
	video.osd_enabled = video_osd
	video.set_tape(video_tape)
	var saved_style := video_library.style(path)
	video.style = saved_style if saved_style >= 0 else video_style
	if not video.open(path):
		startup_message = video.status
		return false
	if from_seconds > 0.0: video.seek_to(from_seconds)
	# A choice made for this video before wins; otherwise the default applies.
	var remembered = video_library.subtitle(path)
	var names: PackedStringArray = video.subtitle_names()
	if remembered is String: video.select_subtitles(names.find(remembered))
	elif video_subtitles and not names.is_empty(): video.select_subtitles(0)
	video_checkpoint = 0.0
	return true

func stop_video() -> void:
	remember_video_position()
	video.stop()

## Saves where the current video is and its display style; cheap enough to call often.
func remember_video_position() -> void:
	video_checkpoint = 0.0
	if not video.loaded: return
	var length := float(video.info.duration)
	var position: float = length if video.ended else video.clock
	if video_library.remember(video.path, position, length, video.style) != OK:
		show_notice("Could not save the video position. Check user-folder permissions.")

func flash_video_bar(note := "") -> void:
	for bar in video_bars: bar.flash(note)

## Selects subtitle option `index` (wrapping, with off between the last option and
## the first) for the playing video and remembers it; returns its name.
func choose_subtitles(index: int) -> String:
	var names: PackedStringArray = video.subtitle_names()
	if names.is_empty(): return "none in this video"
	var choice := posmod(index + 1, names.size() + 1) - 1
	video.select_subtitles(choice)
	video_library.set_subtitle(video.path, names[choice] if choice >= 0 else "")
	return names[choice] if choice >= 0 else "Off"

func video_input(event: InputEvent) -> bool:
	# Controller first: A pauses, the D-pad seeks (up/down by a minute, so the
	# L+R+Start menu chord stays free; hold left/right to scrub), Y changes the
	# picture shape, X the audio track.
	var action := ""
	if event is InputEventJoypadButton:
		if event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			var direction := -1 if event.button_index == JOY_BUTTON_DPAD_LEFT else 1
			if event.pressed: video_scrub = direction; video_scrub_held = 0.0; video_scrub_wait = 0.0
			elif video_scrub == direction: video_scrub = 0
		if event.pressed:
			action = {JOY_BUTTON_A:"pause",JOY_BUTTON_DPAD_LEFT:"back",JOY_BUTTON_DPAD_RIGHT:"forward",JOY_BUTTON_DPAD_UP:"forward_long",
				JOY_BUTTON_DPAD_DOWN:"back_long",JOY_BUTTON_Y:"style",JOY_BUTTON_X:"audio",JOY_BUTTON_B:"menu",JOY_BUTTON_START:"menu"}.get(event.button_index,"")
	elif event is InputEventKey and event.pressed:
		# Held arrows repeat through the keyboard's own echo.
		if event.echo and not event.physical_keycode in [KEY_LEFT, KEY_RIGHT]: return false
		action = {KEY_SPACE:"pause",KEY_ENTER:"pause",KEY_LEFT:"back",KEY_RIGHT:"forward",KEY_UP:"forward_long",KEY_DOWN:"back_long",
			KEY_V:"style",KEY_A:"audio",KEY_S:"subtitles",KEY_BACKSPACE:"menu"}.get(event.physical_keycode,"")
	match action:
		"pause":
			if video.ended: video.seek_to(0.0)
			else: video.set_paused(not video.paused)
			flash_video_bar()
		"back", "forward", "back_long", "forward_long":
			video.seek_by({"back":-10.0,"forward":10.0,"back_long":-60.0,"forward_long":60.0}[action])
			flash_video_bar()
		"style": flash_video_bar("Picture shape: " + video.cycle_style())
		"subtitles": flash_video_bar("Subtitles: " + choose_subtitles(video.subtitle_choice + 1))
		"audio":
			var track: String = video.cycle_audio_track()
			flash_video_bar("Audio: " + track if not track.is_empty() else "This video has one audio track")
		"menu":
			video_scrub = 0
			toggle_settings()
		_: return false
	return true

func load_game(path: String) -> bool:
	startup_message = ""
	var restore_paused := was_paused_before_menu
	if video.loaded: stop_video()
	# Discs boot through seconds of black: the loading card covers them.
	if CoreRegistry.identify(path) in ["psx", "segacd"]: show_loading(path)
	else: end_loading()
	loading_game = true
	var opened: bool = emulator.load_rom(path)
	loading_game = false
	if not opened:
		end_loading()
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
	recent.set_value("video", "folder", video_dir)
	recent.set_value("video", "style", video_style)
	recent.set_value("video", "line_count", video_lines)
	recent.set_value("video", "hardware", video_hardware)
	recent.set_value("video", "interlace", video_interlace)
	recent.set_value("video", "subtitles", video_subtitles)
	recent.set_value("video", "osd", video_osd)
	recent.set_value("video", "tape", video_tape)
	recent.set_value("video", "vcr_sounds", video_vcr_sounds)
	recent.set_value("video", "own_picture", video_own_picture)
	if recent.has_section_key("video", "lines"): recent.erase_section_key("video", "lines")
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
	# The video profile is always kept: removing it would bring back its composite default.
	if config.encode_to_text() == baseline.encode_to_text() and active_game_key != VIDEO_PROFILE:
		# No override means future global changes also apply to this game.
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(path+suffix) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix)) != OK:
				show_notice("Could not clear the game's picture override. Check user-folder permissions.")
				return false
		return true
	var error := SettingsStore.write(path,config)
	if error != OK: show_notice("Game picture settings could not be saved. Check free space.")
	return error == OK

func change_game_preferences(active: bool, key := "") -> void:
	if not active_game_key.is_empty():
		save_game_preferences()
		var restore := capture_settings()
		SettingsStore.copy_sections(picture_baseline,restore,PICTURE_SECTIONS)
		apply_settings(restore)
	if key == VIDEO_PROFILE: active_game_key = VIDEO_PROFILE if active and video_own_picture else ""
	else: active_game_key = emulator.rom_hash if active and remember_game_picture else ""
	if not active_game_key.is_empty():
		var path := "user://games/"+active_game_key+".cfg"
		var defaults := capture_settings()
		# Video looks like a broadcast or tape feed until the user says otherwise.
		if active_game_key == VIDEO_PROFILE and not FileAccess.file_exists(path):
			defaults.set_value("picture", "connection", 3)
		var reader := SettingsStore.new()
		var saved := reader.read(path,defaults)
		var merged := capture_settings()
		SettingsStore.copy_sections(saved,merged,PICTURE_SECTIONS)
		apply_settings(merged)
		if not reader.warning.is_empty(): startup_message = reader.warning
	settings_dirty = true

## Switches videos between their own picture and the global one, at once if one plays.
func set_video_own_picture(enabled: bool) -> void:
	if enabled == video_own_picture: return
	if video.loaded: change_game_preferences(false)
	video_own_picture = enabled
	if video.loaded: change_game_preferences(true, VIDEO_PROFILE)
	save_library()
	settings_dirty = true

## Starts the video picture again: the global picture with Auto composite.
func reset_video_picture() -> void:
	var playing: bool = video.loaded and active_game_key == VIDEO_PROFILE
	if playing: change_game_preferences(false)
	for suffix in ["", ".bak"]:
		var path: String = "user://games/" + VIDEO_PROFILE + ".cfg" + str(suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if playing: change_game_preferences(true, VIDEO_PROFILE)
	show_notice("Video picture reset to Auto composite")

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
		provider.real,provider.valid,provider.status,stereo,get_window().size,gaming_mode,sbs_target_size())
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
	for key in ["menu_large_text","menu_high_contrast","menu_reduced_motion","menu_sounds","menu_haptics","menu_curve"]: set(key,false)
	menu_depth = true
	menu_on_tv = true
	haptic_strength = 0.8
	power_on.enabled=true; power_on.sound_level=.60; power_on.reduced_motion=false; power_on.apply()
	tv_effects.channel_change=true; tv_effects.power_off_effect=true; tv_effects.reduced_motion=false
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
	var override := OS.get_environment("CRT_XR_SCREENSHOT_DIR")
	if not override.is_empty(): return override
	var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures.is_empty(): return ProjectSettings.globalize_path("user://Screenshots")
	return pictures.path_join("CRT XR")

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
	var stem := "CRT XR-%s-%03d" % [stamp, Time.get_ticks_msec() % 1000]
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

## Applies a built-in lighting mood (RoomPresets.MOODS).
func room_preset(preset: String) -> void:
	var values: Dictionary = rooms.MOODS.get(preset, rooms.MOODS.late)
	for key in values: world.set(key, values[key])
	world.apply_room_settings()

func capture_settings() -> ConfigFile:
	if provider.real: xr_fov=vertical_fov
	else: desktop_fov=vertical_fov
	var config := ConfigFile.new()
	config.set_value("tracking", "source", tracking_source)
	config.set_value("menu","picture_preset_id",picture_preset_id)
	config.set_value("menu","picture_preset_signature",picture_preset_signature)
	config.set_value("menu","room_preset_id",room_preset_id)
	config.set_value("menu","room_preset_signature",room_preset_signature)
	config.set_value("view","desktop_fov",desktop_fov)
	config.set_value("view","xr_fov",xr_fov)
	for key in music.DEFAULTS: config.set_value("music",key,music.get(key))
	config.set_value("atmosphere","power_on",power_on.enabled)
	config.set_value("atmosphere","power_sound",power_on.sound_level)
	config.set_value("atmosphere","channel_change",tv_effects.channel_change)
	config.set_value("atmosphere","power_off",tv_effects.power_off_effect)
	for key in emulator.tv_audio.DEFAULTS: config.set_value("audio",key,emulator.tv_audio.get(key))
	config.set_value("preferences", "per_game_picture", remember_game_picture)
	config.set_value("preferences","metrics_visible",metrics_visible)
	for key in ["menu_large_text","menu_high_contrast","menu_reduced_motion","menu_sounds","menu_haptics","menu_depth","menu_on_tv","menu_curve","haptic_strength"]: config.set_value("accessibility",key,get(key))
	config.set_value("emulation", "run_ahead", emulator.run_ahead)
	config.set_value("emulation", "separate_preview", emulator.separate_preview)
	config.set_value("view", "right_stick_distance", right_stick_distance)
	config.set_value("view", "distance_speed", distance_speed)
	for setting in ROOM_FIELDS: config.set_value("room", setting[0], world.get(setting[0]))
	config.set_value("room", "shadows", world.shadows)
	config.set_value("room", "floor_style", world.floor_style)
	config.set_value("room", "lighting_version", SettingsStore.LIGHTING_VERSION)
	config.set_value("room", "ambience", world.ambience)
	config.set_value("room", "ambience_level", world.ambience_level)
	for key in ROOM_SWITCHES:
		config.set_value("room", key, world.get(key))
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
	if is_instance_valid(music) and music.save_resume()!=OK: return false
	var config := capture_settings()
	# A key is only set while a picture profile is active: a game's (when
	# per-game picture is on) or the video profile (always). Its picture is
	# saved to the profile, never into the global settings.
	if not active_game_key.is_empty():
		if not save_game_preferences(): return false
		SettingsStore.copy_sections(picture_baseline, config, PICTURE_SECTIONS)
	else: picture_baseline = config
	var error := SettingsStore.write("user://settings.cfg", config)
	if error != OK:
		show_notice("Settings could not be saved. Check free space and user-folder permissions.")
		return false
	return true
