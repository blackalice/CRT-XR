extends SceneTree
const UI=preload("res://tests/menu_test_helpers.gd")
var failures:=0
var app
func check(ok:bool,message:String):
 if ok: print("PASS: ",message)
 else: push_error(message);failures+=1
func _initialize():call_deferred("run")
func settle():
 for i in range(4):await process_frame
func press(code:int):
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.device=42;e.button_index=code;e.pressed=down
  Input.parse_input_event(e);Input.flush_buffered_events();await settle()
func run():
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 app.use_tracking(false);app.set_stereo(true)
 if not app.menu.visible:app.toggle_settings()
 await settle()
 check(app.menu.visible and app.menu_overlays[0].visible and app.menu_overlays[1].visible,"Menu opens in both SBS eyes")
 check(app.menu_overlays[0].texture==app.menu_overlays[1].texture,"Both eyes share the same menu texture")
 app.menu.select("home.settings");await press(JOY_BUTTON_A)
 check(app.menu.category==7,"Settings opens on everyday Quick settings")
 UI.page(app,0,0);await settle()
 await press(JOY_BUTTON_LEFT_SHOULDER)
 check(app.menu.category==7 and app.menu.selected_row().is_visible_in_tree(),"L1 wraps categories and focuses a visible row")
 await press(JOY_BUTTON_RIGHT_SHOULDER)
 check(app.menu.category==0,"R1 wraps to View")
 for category in range(app.menu.CATEGORIES.size()):
  for section in range(app.menu.catalog.pages(category).size()):
   UI.page(app,category,section);await settle()
   check(app.menu.get_rect().end.y<=720 and app.menu.get_rect().end.x<=960,"Category %d page %d fits shared canvas"%[category,section])
 app.menu.back()
 check(app.menu.mode=="pause" and app.menu.selected_id=="home.settings","Back restores originating pause selection")
 app.menu.select("home.library");await press(JOY_BUTTON_A)
 check(app.menu.mode=="library" and app.stereo,"Library preserves SBS")
 await press(JOY_BUTTON_B)
 check(app.menu.mode=="pause" and app.menu.selected_id=="home.library","Library Back restores Choose game")
 app.menu.open_library();app.menu.open_folder(ProjectSettings.globalize_path("res://build"))
 app.menu.select("file:"+ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc"))
 await press(JOY_BUTTON_A)
 check(app.emulator.loaded and not app.menu.visible and not app.emulator.paused,"Controller A loads ROM and starts gameplay")
 app.toggle_settings();await settle()
 check(app.emulator.paused and app.stereo,"Opening pause menu pauses game in SBS")
 await press(JOY_BUTTON_A)
 check(not app.emulator.paused and not app.menu_overlays[0].is_visible_in_tree() and not app.menu_overlays[1].is_visible_in_tree(),"Resume clears both eye overlays and restores gameplay")
 app.emulator.set_paused(true);app.toggle_settings();app.close_settings()
 check(app.emulator.paused,"Closing preserves an already paused game")
 app.set_stereo(false);app.toggle_settings();await settle()
 check(app.menu_overlays[0].is_visible_in_tree() and not app.menu_overlays[1].is_visible_in_tree(),"Mono shares menu layout and hides second eye")
 app.distance_save_delay=-1;app.free();await settle();quit(1 if failures else 0)
