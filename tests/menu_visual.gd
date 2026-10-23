extends SceneTree
var app
var directory:="res://build/menu-review"
func _initialize():call_deferred("run")
func capture(label:String):
 for i in range(5):await process_frame
 RenderingServer.force_draw(false)
 # Only this 2D viewport is inspected; no licensed model or 3D scene.
 app.menu_view.get_texture().get_image().save_png(directory.path_join(label+".png"))
 print("LAYOUT ",label," ",app.menu.get_rect()," scroll=",app.menu.scroll.size)
func run():
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 await capture("pause")
 for category in range(app.menu.CATEGORIES.size()):
  app.menu.open_settings();app.menu.category=category
  for section in range(app.menu.catalog.pages(category).size()):
   app.menu.subsection=section;app.menu.render()
   await capture("category-%d-page-%d"%[category,section])
 app.menu.category=0;app.menu.subsection=0;app.menu.render();app.menu.select("view.distance")
 await capture("selected");app.menu.toggle_preview()
 await capture("compact")
 app.menu.back();app.menu.open_slot(0);await capture("setup")
 app.menu.ask("Overwrite this setup?","Replace your named setup with the current view, room and picture settings?",func():pass)
 await capture("confirmation")
 app.menu.back();app.menu.games.open_library();app.menu.show_error("No SD card is mounted. Insert the card, then try again.")
 await capture("missing-card")
 app.menu.games.open_folder(ProjectSettings.globalize_path("res://build"))
 await capture("browser")
 app.menu.show_error("Settings could not be saved. Check free space and user-folder permissions. Your changes are still here.")
 await capture("save-error")
 app.free();quit()
