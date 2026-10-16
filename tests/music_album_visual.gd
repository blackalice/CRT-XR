extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.use_tracking(false)
 app.music.play_album(ProjectSettings.globalize_path("res://build/album-fixture"))
 app.menu.open_pause()
 for i in range(8):await process_frame
 RenderingServer.force_draw(false)
 app.menu_view.get_texture().get_image().save_png("res://build/album-pause.png")
 app.menu.open_music_browser(ProjectSettings.globalize_path("res://build/album-fixture"))
 for i in range(8):await process_frame
 RenderingServer.force_draw(false)
 app.menu_view.get_texture().get_image().save_png("res://build/album-browser.png")
 app.free()
 for i in range(3):await process_frame
 quit.call_deferred()
