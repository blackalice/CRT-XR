extends SceneTree
var failures:=0
func check(ok:bool,label:String):
 print("PASS: " if ok else "FAIL: ",label)
 if not ok:failures+=1
func _initialize():
 var migration=load("res://scripts/content/user_data_migration.gd")
 var base:=ProjectSettings.globalize_path("user://migration-test")
 var old:=base.path_join("old");var current:=base.path_join("new")
 DirAccess.make_dir_recursive_absolute(old.path_join("states"));DirAccess.make_dir_recursive_absolute(old.path_join("logs"));DirAccess.make_dir_recursive_absolute(current)
 for entry in [[old.path_join("settings.cfg"),"original"],[old.path_join("states/game.srm"),"save data"],[old.path_join("music-resume.cfg"),"bookmark"],[old.path_join("logs/old.log"),"ignored"],[current.path_join("settings.cfg"),"new settings"]]:
  var file:=FileAccess.open(entry[0],FileAccess.WRITE);file.store_string(entry[1]);file.close()
 var before:=FileAccess.get_sha256(old.path_join("states/game.srm"))
 var result:Dictionary=migration.migrate(current,old)
 check(result.error==OK and result.copied==2,"Migration copies saves and music bookmarks")
 check(FileAccess.get_file_as_string(current.path_join("settings.cfg"))=="new settings","Existing new preferences are never overwritten")
 check(FileAccess.get_sha256(current.path_join("states/game.srm"))==before and FileAccess.get_sha256(old.path_join("states/game.srm"))==before,"Save bytes and original data remain unchanged")
 check(not FileAccess.file_exists(current.path_join("logs/old.log")),"Old logs are excluded")
 check(migration.migrate(current,old).copied==0,"Migration runs only once")
 print("MIGRATION CHECKS COMPLETE: ",failures," failures");quit(1 if failures else 0)
