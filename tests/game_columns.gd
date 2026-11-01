extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, name: String):
 print("PASS: " if ok else "FAIL: ", name)
 if not ok: failures += 1
func settle():
 for i in range(8): await process_frame
func run():
 var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); app.use_tracking(false)
 var m=app.menu
 var games: Array=[]
 var folder=ProjectSettings.globalize_path("user://columns")
 DirAccess.make_dir_recursive_absolute(folder)
 for i in range(7):
  var path: String=folder.path_join("Game %02d.sfc" % i)
  var file=FileAccess.open(path, FileAccess.WRITE); file.store_8(0); file.close()
  games.append({"path":path,"label":"A Longer Game Name %02d" % i})
 m.rom_index.games={"snes":games}; m.games.library_system="snes"; m.games.game_page=0
 for columns in [1,2,3]:
  app.game_list_columns=columns; m.mode="games"; m.memory.clear(); m.render(); await settle()
  var entries=m.rows.filter(func(r):return r.item.has("rom_path"))
  check(entries.size()==7 and entries.all(func(r):return r.item.get("game_grid",false)==(columns>1)),"%d columns arrange every game" % columns)
  if columns>1:
   var grid: GridContainer=entries[0].get_parent()
   check(grid.columns==columns and entries.all(func(r):return r.size.y>= (108 if columns==2 else 124) and r.get_rect().end.x<=grid.size.x+1),"%d-column tiles fit and are taller" % columns)
   m.select(entries[0].item.id,false); m.navigate(Vector2i.RIGHT)
   check(m.selected_id==entries[1].item.id,"Right selects the next game in %d columns" % columns)
   m.navigate(Vector2i.DOWN)
   check(m.selected_id==entries[1+columns].item.id,"Down preserves the column in %d columns" % columns)
   m.select(entries[5].item.id,false); m.navigate(Vector2i.DOWN)
   check(m.selected_id==entries[6].item.id,"Incomplete final row selects its nearest game in %d columns" % columns)
   m.navigate(Vector2i.UP)
   check(m.selected_id==entries[6-columns].item.id,"Up returns to the same column in %d columns" % columns)
 m.mode="settings"; m.category=9; m.subsection=1; m.memory.clear(); m.render(); await settle()
 m.select("access.game_columns",false); m.adjust(1)
 check(app.game_list_columns==1,"Column choice wraps from three to one in Settings")
 m.adjust(1)
 check(app.game_list_columns==2,"Column choice can be changed from Settings")
 app.game_list_columns=3
 var saved: ConfigFile=app.capture_settings()
 app.game_list_columns=1; app.apply_settings(saved)
 check(app.game_list_columns==3,"Column choice survives settings restore")
 app.play_history.favourites.clear()
 for game in games: app.play_history.favourites.append(game.path)
 m.mode="favourites";m.memory.clear();m.render();await settle()
 check(m.rows.filter(func(r): return r.item.get("game_grid",false)).size()==7,"Favourites use the chosen grid")
 app.play_history.recent.assign(app.play_history.favourites)
 m.mode="recent";m.memory.clear();m.render();await settle()
 check(m.rows.filter(func(r): return r.item.get("game_grid",false)).size()==7,"Recent games use the chosen grid")
 app.menu_large_text=true; m.mode="games";m.memory.clear();m.render();await settle()
 var larger=m.rows.filter(func(r):return r.item.get("game_grid",false))
 check(larger.all(func(r):return r.get_global_rect().grow(.5).encloses(r.title_label.get_global_rect())),"Larger text stays inside grid tiles")
 app.free(); await process_frame
 print("GAME COLUMN CHECKS COMPLETE: ",failures," failures"); quit(1 if failures else 0)
