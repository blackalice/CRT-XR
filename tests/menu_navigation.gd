extends SceneTree
const UI=preload("res://tests/menu_test_helpers.gd")
var app
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:print("PASS: ",label)
 else:push_error(label);failures+=1
func settle():
 for i in range(3):await process_frame
func edge(code:int,down:bool):
 var event:=InputEventJoypadButton.new()
 event.device=7;event.button_index=code;event.pressed=down
 Input.parse_input_event(event);Input.flush_buffered_events()
func press(code:int):
 edge(code,true);await settle();edge(code,false);await settle()
func axis(code:int,value:float):
 var event:=InputEventJoypadMotion.new()
 event.device=7;event.axis=code;event.axis_value=value
 Input.parse_input_event(event);Input.flush_buffered_events()
func run():
 for action in ["ui_up","ui_down","ui_left","ui_right","ui_accept"]:
  for event in InputMap.action_get_events(action):
   if event is InputEventJoypadButton or event is InputEventJoypadMotion:InputMap.action_erase_event(action,event)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 await settle()
 var menu=app.menu
 check(menu.mode=="pause" and menu.selected_id=="games","Startup selects Choose game and skips unavailable Resume")
 await press(JOY_BUTTON_DPAD_UP)
 check(menu.selected_id=="games","List stops at its first enabled row")
 await press(JOY_BUTTON_DPAD_DOWN)
 check(menu.selected_id=="screenshot","Navigation skips disabled actions without UI joypad bindings")
 menu.select("settings");await press(JOY_BUTTON_A)
 check(menu.mode=="settings" and menu.selected_row().selected_now,"A opens settings with a full highlighted row")
 var ids:={};var binding_count:=0;var bad:=0
 var saved:ConfigFile=app.capture_settings()
 var old_stereo:bool=app.stereo
 for category in range(5):
  for page in menu.catalog.pages(category):
   for item in page.rows:
    if ids.has(item.id):bad+=1
    ids[item.id]=true
    if item.kind=="number":
     item.setter.call(item.min)
     if not is_equal_approx(float(item.getter.call()),float(item.min)):bad+=1
     binding_count+=1
    elif item.kind=="toggle":
     var next:bool=not item.getter.call()
     item.setter.call(next)
     if item.getter.call()!=next:bad+=1
     binding_count+=1
 app.apply_settings(saved);app.set_stereo(old_stereo)
 check(bad==0 and binding_count>50,"All option bindings work and stable IDs are unique")
 UI.set_value(app,"view.distance",3.0)
 await press(JOY_BUTTON_DPAD_RIGHT)
 check(menu.category==1 and is_equal_approx(app.distance,3.0),"Right changes category without adjusting the highlighted setting")
 await press(JOY_BUTTON_DPAD_LEFT)
 check(menu.category==0 and menu.selected_id=="view.distance","Left restores the previous category and row")
 await press(JOY_BUTTON_A)
 check(menu.editing and is_equal_approx(app.distance,3.0) and menu.selected_row().editing_now,"A enters clearly marked editing without changing the value")
 await press(JOY_BUTTON_DPAD_RIGHT)
 check(is_equal_approx(app.distance,3.1) and menu.category==0,"Right adjusts only while editing")
 edge(JOY_BUTTON_DPAD_RIGHT,true);menu._process(.4);menu._process(.11);edge(JOY_BUTTON_DPAD_RIGHT,false)
 check(app.distance>3.2 and menu.direction==Vector2i.ZERO,"Held adjustment repeats and stops on release")
 await press(JOY_BUTTON_Y)
 check(is_equal_approx(app.distance,3.284008),"Y resets only the selected option")
 var editing_id:String=menu.selected_id
 await press(JOY_BUTTON_DPAD_DOWN)
 await press(JOY_BUTTON_RIGHT_SHOULDER)
 axis(JOY_AXIS_TRIGGER_RIGHT,.9);await settle();axis(JOY_AXIS_TRIGGER_RIGHT,0)
 check(menu.editing and menu.selected_id==editing_id and menu.category==0 and menu.subsection==0,"Editing locks row/category/section navigation")
 await press(JOY_BUTTON_A)
 check(not menu.editing and menu.mode=="settings","A finishes editing and retains the page")
 menu.select("view.height_offset");await press(JOY_BUTTON_RIGHT_SHOULDER)
 check(menu.category==1,"R1 changes category")
 await press(JOY_BUTTON_LEFT_SHOULDER)
 check(menu.category==0 and menu.selected_id=="view.height_offset","Returning to a category restores its selected row")
 axis(JOY_AXIS_TRIGGER_RIGHT,.9);await settle()
 var section:int=menu.subsection
 axis(JOY_AXIS_TRIGGER_RIGHT,.95);await settle()
 check(section==1 and menu.subsection==section,"Held trigger changes subsection only once")
 axis(JOY_AXIS_TRIGGER_RIGHT,0);axis(JOY_AXIS_TRIGGER_RIGHT,.9);await settle();axis(JOY_AXIS_TRIGGER_RIGHT,0)
 check(menu.subsection==0,"Trigger release re-arms subsection navigation")
 UI.page(app,1,2);await settle()
 check(menu.section_tabs.get_child_count()==5 and menu.section_title.text.contains("3 of 5"),"All Picture subsections and the page count are visible")
 menu.section_tabs.get_child(4).pressed.emit();await settle()
 check(menu.subsection==4,"Named subsection buttons open the selected page")
 UI.page(app,0,0)
 menu.select("view.height_offset");await press(JOY_BUTTON_X)
 print("PREVIEW_RECT ",menu.get_rect()," min=",menu.get_combined_minimum_size())
 check(menu.preview and not menu.body.visible and menu.get_rect().end.y<=720,"X opens a compact strip within the eye canvas")
 await press(JOY_BUTTON_DPAD_RIGHT)
 check(is_equal_approx(app.height_offset,.05),"Compact preview adjusts the same setting")
 await press(JOY_BUTTON_RIGHT_SHOULDER)
 check(menu.category==0,"Preview ignores category input")
 await press(JOY_BUTTON_DPAD_DOWN)
 var preview_id:String=menu.selected_id
 await press(JOY_BUTTON_B)
 check(not menu.preview and menu.selected_id==preview_id,"Back restores the current preview option in settings")
 UI.select(app,"controls.preview")
 var depth:int=app.emulator.run_ahead
 await press(JOY_BUTTON_A)
 check(menu.editing and app.emulator.run_ahead==depth,"A selects a choice for editing without cycling it")
 await press(JOY_BUTTON_DPAD_RIGHT)
 check(app.emulator.run_ahead==posmod(depth+1,3),"Right cycles the selected choice while editing")
 await press(JOY_BUTTON_B)
 check(not menu.editing and menu.mode=="settings","B finishes editing before navigating back")
 await press(JOY_BUTTON_Y)
 check(app.emulator.run_ahead==1,"Y resets the selected choice to its default")
 await press(JOY_BUTTON_A)
 app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not menu.editing and menu.selected_id=="controls.preview","Focus loss exits editing without losing the option")
 UI.select(app,"controls.distance");await press(JOY_BUTTON_A)
 await press(JOY_BUTTON_DPAD_LEFT);await press(JOY_BUTTON_A)
 check(not app.right_stick_distance and not menu.editing,"Switches use the same select-adjust-done interaction")
 await press(JOY_BUTTON_Y)
 axis(JOY_AXIS_LEFT_Y,1);await settle()
 check(menu.direction!=Vector2i.ZERO,"Left stick navigates")
 app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(menu.direction==Vector2i.ZERO,"Focus loss cancels held movement")
 axis(JOY_AXIS_LEFT_Y,0)
 UI.select(app,"system.reset");await press(JOY_BUTTON_A)
 check(menu.mode=="confirm" and menu.selected_id=="cancel","Reset confirmation defaults to Cancel")
 var distance:float=app.distance
 await press(JOY_BUTTON_B)
 check(menu.mode=="settings" and menu.selected_id=="system.reset" and app.distance==distance,"Cancel restores focus without changing preferences")
 UI.page(app,4,0);menu.select("slot.2");await press(JOY_BUTTON_A)
 check(menu.mode=="slot" and app.selected_profile==2,"Setup slots open a controller-friendly action page")
 menu.select("slot.save");await press(JOY_BUTTON_A)
 check(FileAccess.file_exists(app.profile_path()),"An empty setup saves without confirmation")
 await press(JOY_BUTTON_A)
 check(menu.mode=="confirm" and menu.selected_id=="cancel","Existing setups require overwrite confirmation")
 await press(JOY_BUTTON_B)
 menu.select("slot.rename");await press(JOY_BUTTON_A)
 menu.rename_field.text="Bedroom evening";menu.save_draft_name()
 check(menu.draft_names[2]=="Bedroom evening" and menu.mode=="slot","Keyboard naming returns to setup actions")
 menu.select("slot.save");await press(JOY_BUTTON_A)
 menu.select("confirm");await press(JOY_BUTTON_A)
 var named:=ConfigFile.new();named.load(app.profile_path())
 check(named.get_value("meta","name","")=="Bedroom evening","Confirmed overwrite stores the new name")
 menu.select("slot.rename");await press(JOY_BUTTON_A)
 menu.rename_field.text="Cancelled name";await press(JOY_BUTTON_B)
 check(menu.draft_names[2]=="Bedroom evening","Cancelling rename retains the existing draft")
 UI.select(app,"view.distance");await settle()
 var before_hover:String=menu.selected_id
 var hover:=InputEventMouseMotion.new()
 hover.position=menu.rows[1].global_position+Vector2(20,20)
 app.menu_view.push_input(hover,true);await settle()
 check(menu.selected_id==before_hover,"Pointer hover never steals controller selection")
 var enter:=InputEventKey.new();enter.physical_keycode=KEY_ENTER;enter.pressed=true
 menu.handle(enter);enter.pressed=false;menu.handle(enter)
 var key:=InputEventKey.new();key.physical_keycode=KEY_RIGHT;key.pressed=true
 menu.handle(key);key.pressed=false;menu.handle(key)
 check(is_equal_approx(app.distance,3.5),"Keyboard uses the same adjustment path")
 menu.handle(enter) # key release does not finish editing
 check(menu.editing,"Releasing Enter does not exit editing")
 edge(JOY_BUTTON_DPAD_DOWN,true);Input.joy_connection_changed.emit(7,false)
 check(menu.direction==Vector2i.ZERO and not menu.editing,"Controller disconnect stops held navigation and exits editing")
 edge(JOY_BUTTON_DPAD_DOWN,false)
 menu.back()
 check(menu.mode=="pause","Back returns through settings to pause menu")
 menu.select("exit");await press(JOY_BUTTON_A);await press(JOY_BUTTON_B)
 check(menu.mode=="pause" and menu.selected_id=="exit","Exit cancellation preserves focus")
 app.load_game(ProjectSettings.globalize_path("res://build/retrocrt-probe.sfc"));await settle()
 app.close_settings();app.toggle_settings();await settle()
 check(app.emulator.paused and menu.selected_id=="resume","Menu pauses a running game and selects Resume")
 var load_row=menu.rows.filter(func(row):return row.item.id=="load_state")[0]
 check(load_row.disabled,"Load state is unavailable until a state exists")
 menu.select("save_state");await press(JOY_BUTTON_A)
 load_row=menu.rows.filter(func(row):return row.item.id=="load_state")[0]
 check(not load_row.disabled,"Successful state save immediately enables Load state")
 menu.select("load_state");await press(JOY_BUTTON_A)
 check(menu.mode=="confirm","Loading state requests confirmation")
 menu.select("confirm");await press(JOY_BUTTON_A)
 check(app.emulator.paused and menu.visible,"Loading state from the menu keeps the game paused")
 menu.select("resume");await press(JOY_BUTTON_A)
 check(not menu.visible and not app.emulator.paused,"Resume restores gameplay")
 await settle()
 check(app.menu_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Closed menu stops rendering")
 app.emulator.set_paused(true);app.toggle_settings();app.close_settings()
 check(app.emulator.paused,"A previously paused game stays paused")
 app.toggle_settings()
 app.distance+=.1
 DirAccess.make_dir_absolute(ProjectSettings.globalize_path("user://settings.cfg.tmp"))
 app.close_settings()
 check(menu.visible and menu.error_label.visible and app.emulator.paused,"Save failure retains the open menu, error and paused game")
 DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg.tmp"))
 app.close_settings()
 check(not menu.visible,"Retrying after storage recovery saves and closes normally")
 app.distance_save_delay=-1;app.free();await settle()
 quit(1 if failures else 0)
