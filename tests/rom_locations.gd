extends SceneTree
const Locations=preload("res://scripts/content/rom_locations.gd")
var failures:=0
var app
func check(ok:bool,message:String):
 if ok: print("PASS: ",message)
 else: push_error(message);failures+=1
func _initialize():call_deferred("run")
func settle():
 for i in range(4):await process_frame
func edge(code:int,down:bool):
 var e:=InputEventJoypadButton.new();e.device=7;e.button_index=code;e.pressed=down
 Input.parse_input_event(e);Input.flush_buffered_events()
func press(code:int):
 edge(code,true);await settle();edge(code,false);await settle()
func run():
 var mounts:="11 1 179:1 / /run/media/deck/My\\040SD rw - ext4 /dev/mmcblk0p1 rw\n12 1 259:1 / /home rw - ext4 /dev/nvme0n1p1 rw\n13 1 8:1 / /run/media/deck/USB rw - vfat /dev/sda1 rw\n14 1 179:1 / /run/media/deck/My\\040SD rw - ext4 /dev/mmcblk0p1 rw"
 check(Locations.parse_sd_mounts(mounts)==PackedStringArray(["/run/media/deck/My SD"]),"SD mount parser decodes spaces and filters internal/USB/duplicates")
 check(Locations.parse_sd_mounts("bad line\n").is_empty(),"Malformed mount data handled safely")
 var fixture:=ProjectSettings.globalize_path("user://rom-browser-fixtures")
 var folder_a:=fixture.path_join("My SD/SNES Games")
 var folder_b:=fixture.path_join("Other Games")
 DirAccess.make_dir_recursive_absolute(folder_a.path_join("Subfolder"))
 DirAccess.make_dir_recursive_absolute(folder_b)
 for i in range(15):
  var f:=FileAccess.open(folder_a.path_join("%02d-example.sfc"%i),FileAccess.WRITE)
  f.store_string("fixture only, never executed");f.close()
 var f:=FileAccess.open(folder_a.path_join("ignore.txt"),FileAccess.WRITE);f.store_string("not a ROM");f.close()
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 app.use_tracking(false);app.set_stereo(true);app.choose_rom()
 var menu=app.menu
 if OS.get_name()=="Windows":
  menu.select("library.drives");await press(JOY_BUTTON_A)
  check(menu.mode=="drives" and not menu.rows.is_empty(),"Windows drive chooser exposes all local drives")
  await press(JOY_BUTTON_B)
  check(menu.mode=="library" and menu.selected_id=="library.drives","Drive chooser restores its library selection")
 menu.open_folder(folder_a);await settle()
 check(menu.library.entries.size()==16,"Folder browser filters unsupported files")
 await press(JOY_BUTTON_RIGHT_SHOULDER)
 var config:=ConfigFile.new();config.load("user://recent.cfg")
 check(app.default_rom_dir==folder_a and config.get_value("library","default_rom_dir","")==folder_a,"R1 immediately persists current default")
 check(app.stereo and menu.visible and menu.get_rect().end.y<=720,"Browser stays within shared SBS canvas")
 var cards:=Locations.sd_cards()
 await press(JOY_BUTTON_X)
 check(menu.error_label.visible if cards.is_empty() else menu.mode in ["browser","volumes"],"X opens SD cards or explains missing card")
 menu.open_folder(folder_b);await press(JOY_BUTTON_Y)
 check(menu.library.current_dir==folder_a,"Y opens saved default")
 var child:=folder_a.path_join("Subfolder")
 menu.select("file:"+child);await press(JOY_BUTTON_A)
 check(menu.library.current_dir==child,"A opens selected folder")
 await press(JOY_BUTTON_LEFT_SHOULDER)
 check(menu.library.current_dir==folder_a and menu.selected_id=="file:"+child,"L1 returns to parent and restores folder selection")
 menu.select("file:"+folder_a.path_join("14-example.sfc"));await settle()
 var selected:String=menu.selected_id;var offset:int=menu.scroll.scroll_vertical
 menu.open_folder(child);menu.open_folder(folder_a);await settle()
 check(menu.selected_id==selected and menu.scroll.scroll_vertical==offset and offset>0,"Folder return restores selection and scroll position")
 var before:String=menu.library.current_dir
 menu.open_folder(fixture.path_join("missing"));await settle()
 check(menu.library.current_dir==before and menu.subtitle.text==before and menu.error_label.visible,"Missing folder preserves path and shows actionable error")
 menu.select_file(fixture.path_join("missing.sfc"))
 check(menu.error_label.text.contains("Reconnect"),"Missing ROM offers reconnect recovery")
 menu.set_default("");config.load("user://recent.cfg")
 check(app.default_rom_dir.is_empty() and config.get_value("library","default_rom_dir","wrong")=="","Clearing default preserves files")
 menu.set_default(folder_a);menu.open_folder(folder_b)
 for code in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_START]:edge(code,true);await settle()
 check(app.default_rom_dir==folder_a and not menu.visible,"Menu chord closes browser without saving a different default")
 for code in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_START]:edge(code,false)
 app.distance_save_delay=-1;app.free()
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 check(app.default_rom_dir==folder_a,"Default folder survives restart")
 app.distance_save_delay=-1;app.free();quit(1 if failures else 0)
