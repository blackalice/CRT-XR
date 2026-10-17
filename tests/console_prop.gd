extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 var tv=app.world.television
 assert(not tv.has_node("ConsoleProp"))
 assert(not tv.has_node("ConsoleVideoCable") and not tv.has_node("ConsolePowerCable"))
 var support=tv.get_node("TelevisionSupport")
 assert(support.get_meta("contact_bake",false))
 print("PASS: Launch scene omits console/cables and has matching contact shading")
 app.free();await create_timer(.15).timeout
 quit()
