extends SceneTree
var failures := 0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 print("PASS: " if ok else "FAIL: ",label)
 if not ok:failures+=1
func run():
 var session_script=load("res://scripts/audio/visualizer_session.gd")
 check(session_script!=null,"Visualiser session loads")
 var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.use_tracking(false)
 if is_instance_valid(app.menu.boot):app.menu.boot.finish()
 app.menu_boot_pending=false
 var sound := AudioStreamWAV.new();sound.mix_rate=44100;sound.format=AudioStreamWAV.FORMAT_16_BITS;sound.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.loop_end=44100
 var bytes := PackedByteArray();bytes.resize(88200)
 for i in range(44100):bytes.encode_s16(i*2,int(sin(i*TAU*220/44100)*16000))
 sound.data=bytes
 app.music.kind="local";app.music.player.stream=sound;app.music.player.play()
 app.menu.music.panel_hidden=false;app.menu.open_pause()
 for i in range(8):await process_frame
 var ids: Array=app.menu.items.map(func(item):return item.id)
 check(ids.find("transport.visualiser")==ids.find("transport.choose")+1,"Visualiser is immediately right of Browse albums")
 app.menu.select("transport.choose");app.menu.navigate(Vector2i.RIGHT)
 check(app.menu.selected_id=="transport.visualiser","Controller moves right from Browse albums to Visualiser")
 var controls: Array=app.menu.rows.filter(func(row):return row.item.get("layout", "")=="transport")
 check(controls.all(func(row):return row.position.x+row.size.x<=row.get_parent().size.x+1),"Transport row fits with Visualiser button")
 if DisplayServer.get_name()!="headless":
  RenderingServer.force_draw(false)
  app.menu_view.get_texture().get_image().save_png("res://build/visualiser-menu.png")
 var bus := AudioServer.get_bus_index(app.music.bus_name)
 var count := AudioServer.get_bus_effect_count(bus)
 var entered: bool=app.visualizer.enter()
 check(entered,"Visualiser enters with installed projectM")
 if not entered:app.free();quit(failures);return
 for i in range(180):await process_frame
 check(app.visualizer.active,"projectM remains active")
 check(app.visualizer.backend.last_error().is_empty(),"Native renderer reports no error")
 check(app.world.picture.source_texture==app.visualizer.texture,"Visualiser owns the TV picture")
 if DisplayServer.get_name()!="headless":
  var image: Image=app.visualizer.texture.get_image()
  image.save_png("res://build/visualiser-frame.png")
  var data=image.get_data();var peak:=0
  for i in range(0,data.size(),4):peak=maxi(peak,data[i]+data[i+1]+data[i+2])
  check(peak>30,"projectM produces visible audio-reactive pixels")
 app.visualizer.preset_index=0
 app.visualizer.next(1)
 check(app.visualizer.preset_index==1,"Preset selection advances")
 var session_backend=app.visualizer.backend
 var back := InputEventJoypadButton.new();back.button_index=JOY_BUTTON_B;back.pressed=true
 app._input(back)
 for i in range(5):await process_frame
 check(app.settings_panel.visible and app.music.player.playing and app.visualizer.active,"B returns to menu without stopping the visualiser or music")
 app.menu.mode="settings";app.menu.category=2;app.menu.subsection=app.menu.catalog.pages(2).size()-1;app.menu.render()
 for i in range(6):await process_frame
 check(app.menu.items.any(func(item):return item.id=="visualiser.brightness" and item.kind=="number") and app.menu.items.any(func(item):return item.id=="visualiser.preset" and item.kind=="choice"),"Visualiser uses shared settings rows")
 if DisplayServer.get_name()!="headless":
  RenderingServer.force_draw(false);app.menu_view.get_texture().get_image().save_png("res://build/visualiser-settings.png")
 app.menu.open_pause()
 for i in range(5):await process_frame
 app.menu.select("transport.visualiser");app.menu.activate()
 check(not app.settings_panel.visible and app.visualizer.active and app.visualizer.backend==session_backend,"One press returns to the same visualiser session")
 for i in range(5):await process_frame
 check(app.world.picture.source_texture==app.visualizer.texture,"Closing menu restores visualiser picture")
 if DisplayServer.get_name()!="headless":
  var viewport := SubViewport.new();viewport.size=Vector2i(960,180);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
  var canvas := Control.new();canvas.size=Vector2(960,180);viewport.add_child(canvas)
  var bar=app.VideoBar.new();bar.use_visualizer();canvas.add_child(bar);bar.set_anchors_preset(Control.PRESET_TOP_LEFT);bar.size=Vector2(960,116);bar.position=Vector2(0,20)
  bar.flash();bar.track("Amber orbit - 100% - Auto",45,180,false,0,true)
  for i in range(4):await process_frame
  RenderingServer.force_draw(false);viewport.get_texture().get_image().save_png("res://build/visualiser-controls.png")
  check(bar.hints.get_child_count()==5,"Shared transport bar shows five visualiser control hints")
  check(bar.hints.get_child(3).get_child(1).text=="Mode","Visualiser mode hint is named Mode")
  check(bar.timeline.get_child(0).get_script()==preload("res://scripts/ui/segment_bar.gd"),"Overlay reuses the menu segmented timeline")
  viewport.queue_free()
 app.visualizer.leave()
 check(AudioServer.get_bus_effect_count(bus)==count,"Leaving removes audio capture")
 check(app.music.player.playing,"Leaving keeps music playing")
 check(app.world.picture.source_texture!=app.visualizer.texture,"Leaving restores previous source")
 app.toggle_settings();check(app.visualizer.enter(),"Visualiser can re-enter")
 app.visualizer.leave()
 check(AudioServer.get_bus_effect_count(bus)==count,"Repeated entry leaves no effects behind")
 var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
 check(app.load_game(rom),"Diagnostic game loads for source-switch checks")
 await create_timer(0.3).timeout
 app.toggle_settings()
 check(app.visualizer.enter(),"Visualiser enters from a running game")
 for i in range(6):await process_frame
 check(app.emulator.paused,"Game stays paused behind visualiser")
 app.emulator.gamepad.right_stick_game=true
 app.right_stick_distance=true;app.distance_speed=1.0;app.distance=3.4
 var motion := InputEventJoypadMotion.new();motion.device=7;motion.axis=JOY_AXIS_RIGHT_Y;motion.axis_value=1.0
 app._input(motion);app._process(0.2)
 check(is_equal_approx(app.distance,3.6),"Right stick adjusts visualiser distance even when the loaded console reserves it")
 motion.axis_value=0.0;app._input(motion)
 app.toggle_settings()
 app.menu.open_pause()
 app.menu.select("resume");app.menu.activate()
 check(not app.settings_panel.visible and not app.visualizer.active,"Resume leaves the visualiser and closes the menu")
 for i in range(6):await process_frame
 check(not app.emulator.paused and app.world.picture.source_texture==app.emulator.texture,"Resume restores game picture and running state")
 app.free()
 for i in range(3):await process_frame
 quit(failures)

