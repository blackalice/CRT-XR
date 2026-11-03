extends Node
## One shared projectM picture for both eyes; audio playback remains independent.
var host: Node
var active := false
var backend: RefCounted
var capture: AudioEffectCapture
var texture: ImageTexture
var saved := {}
var elapsed := 0.0
var cycle := 0.0
var preset_index := 0
var last_position := -1.0
var last_playing := false
var brightness := 1.0
var automatic := true

func _ready() -> void:
 var config := ConfigFile.new()
 if config.load("user://visualiser.cfg")==OK:
  preset_index=clampi(int(config.get_value("visualiser","preset",0)),0,PRESETS.size()-1)
  brightness=clampf(float(config.get_value("visualiser","brightness",1.0)),0.3,1.5)
  automatic=bool(config.get_value("visualiser","automatic",true))

func save_preferences() -> void:
 var config := ConfigFile.new()
 config.set_value("visualiser","preset",preset_index)
 config.set_value("visualiser","brightness",brightness)
 config.set_value("visualiser","automatic",automatic)
 if config.save("user://visualiser.cfg")!=OK:host.show_notice("Visualiser preferences could not be saved.")
const PRESETS := ["Amber orbit", "Blue current", "Green trace"]

func preset_data() -> String:
 return FileAccess.get_file_as_string("res://assets/visualizer/%d.milk" % preset_index)

func enter() -> bool:
 if active:
  host.close_settings()
  flash_controls()
  return not host.settings_panel.visible
 if not ClassDB.class_exists("MusicVisualizer"):
  host.menu.show_error("Visualiser needs the updated native extension."); return false
 var name := "projectM-4.dll" if OS.get_name()=="Windows" else "libprojectM-4.so"
 var library := OS.get_executable_path().get_base_dir().path_join(name)
 if OS.has_feature("editor"): library=ProjectSettings.globalize_path("res://extensions/bin/"+name)
 if not FileAccess.file_exists(library):
  host.menu.show_error("projectM is unavailable. Build or install the visualiser libraries."); return false
 saved={"texture":host.world.picture.source_texture,"rate":host.world.picture.source_rate,"aspect":host.world.picture.source_aspect,"raster":host.world.picture.raster_size,"driven":host.world.picture.frame_driven,"paused":host.was_paused_before_menu,"video_paused":host.video_was_paused_before_menu,"light":host.world.screen_light.source}
 if host.tv_menu.active:
  for key in ["texture","rate","aspect","raster","driven"]: saved[key]=host.tv_menu.saved[key]
 capture=AudioEffectCapture.new(); capture.buffer_length=0.1
 AudioServer.add_bus_effect(AudioServer.get_bus_index(host.music.bus_name),capture)
 backend=ClassDB.instantiate("MusicVisualizer"); backend.start(library,preset_data())
 var image := Image.create(640,480,false,Image.FORMAT_RGBA8);image.fill(Color.BLACK)
 texture=ImageTexture.create_from_image(image)
 active=true; elapsed=0.0; cycle=0.0
 host.close_settings()
 if host.settings_panel.visible:
  leave();return false
 if host.emulator.loaded: host.emulator.set_paused(true)
 if host.video.loaded: host.video.set_paused(true,true)
 host.pattern.set_process(false)
 host.world.picture.source_rate=30.0;host.world.picture.source_aspect=4.0/3.0
 host.world.picture.set_source(texture,true)
 flash_controls()
 return true

func leave(restore := true) -> void:
 if not active:return
 active=false
 for bar in host.visualizer_bars:bar.hide()
 save_preferences()
 if backend!=null:backend.close();backend=null
 var bus := AudioServer.get_bus_index(host.music.bus_name)
 if bus>=0:
  for i in range(AudioServer.get_bus_effect_count(bus)-1,-1,-1):
   if AudioServer.get_bus_effect(bus,i)==capture: AudioServer.remove_bus_effect(bus,i)
 capture=null
 if restore:
  var picture=host.world.picture
  picture.source_rate=saved.rate;picture.source_aspect=saved.aspect
  picture.set_source(saved.texture,saved.driven,saved.raster)
  host.world.screen_light.set_image(saved.light)
  host.was_paused_before_menu=saved.paused;host.video_was_paused_before_menu=saved.video_paused
  if not host.settings_panel.visible:
   if host.emulator.loaded:host.emulator.set_paused(saved.paused)
   if host.video.loaded:host.video.set_paused(saved.video_paused,true)
  host.pattern.set_process(not host.emulator.loaded and not host.video.loaded)

func next(direction: int) -> void:
 preset_index=posmod(preset_index+direction,PRESETS.size());cycle=0.0
 if backend!=null:backend.select(preset_data())
 flash_controls()

func flash_controls() -> void:
 for bar in host.visualizer_bars:bar.flash()

func select_preset(value: int) -> void:
 preset_index=posmod(value,PRESETS.size());cycle=0.0
 if backend!=null:backend.select(preset_data())
 save_preferences()
 flash_controls()

func _process(delta: float) -> void:
 if not active:
  for bar in host.visualizer_bars:bar.hide()
  return
 var playing_now: bool=host.music.player.playing and not host.music.player.stream_paused
 var caption := "%s - %d%% - %s" % [PRESETS[preset_index],roundi(brightness*100),"Auto" if automatic else "Manual"]
 for bar in host.visualizer_bars:
  bar.track(caption,host.music.position_seconds(),host.music.duration(),not playing_now,delta,not host.settings_panel.visible)
 var failure: String=backend.last_error()
 if not failure.is_empty():
  leave();host.show_notice(failure);return
 var playing: bool=host.music.player.playing and not host.music.player.stream_paused
 elapsed+=delta
 if elapsed<1.0/30.0:return
 elapsed=fmod(elapsed,1.0/30.0)
 var position: float=host.music.position_seconds()
 if playing!=last_playing or absf(position-last_position)>0.5:
  capture.clear_buffer()
 last_position=position;last_playing=playing
 var samples := capture.get_buffer(capture.get_frames_available())
 if playing and not host.settings_panel.visible:backend.submit(samples)
 var image: Image=backend.frame()
 if image!=null:
  if not is_equal_approx(brightness,1.0):image.adjust_bcs(brightness,1.0,1.0)
  texture.update(image)
  if not host.tv_menu.active:
   host.world.picture.frame_presented(image);host.world.screen_light.set_image(image)
 if playing and automatic and not host.menu_reduced_motion:
  cycle+=1.0/30.0
  if cycle>=30.0:next(1)

func handle(event: InputEvent) -> bool:
 var key := -1
 if event is InputEventKey and event.pressed and not event.echo:
  key={KEY_SPACE:0,KEY_LEFT:1,KEY_RIGHT:2,KEY_ESCAPE:3,KEY_UP:4,KEY_DOWN:5,KEY_Y:6}.get(event.physical_keycode,-1)
 if event is InputEventJoypadButton and event.pressed:
  key={JOY_BUTTON_A:0,JOY_BUTTON_DPAD_LEFT:1,JOY_BUTTON_DPAD_RIGHT:2,JOY_BUTTON_B:3,JOY_BUTTON_DPAD_UP:4,JOY_BUTTON_DPAD_DOWN:5,JOY_BUTTON_Y:6}.get(event.button_index,-1)
 match key:
  0:host.music.toggle_playback()
  1:next(-1)
  2:next(1)
  3:host.toggle_settings()
  4:brightness=minf(1.5,brightness+0.1);flash_controls()
  5:brightness=maxf(0.3,brightness-0.1);flash_controls()
  6:automatic=not automatic;flash_controls()
  _:return false
 return true

func _exit_tree() -> void:
 if backend!=null:backend.close()

