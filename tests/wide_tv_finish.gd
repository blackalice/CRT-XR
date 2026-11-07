extends SceneTree
const UI = preload("res://tests/menu_test_helpers.gd")
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1
func printed_part(world) -> MeshInstance3D:
	for part in world.television.get_node("ImportedCabinet").find_children("*","MeshInstance3D",true,false):
		if part.mesh.surface_get_material(0).resource_name.begins_with("Printed silver fascia"): return part
	return null
func run():
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame; await process_frame
	app.use_tracking(false)
	app.set_widescreen(true)
	var part := printed_part(app.world)
	check(part != null, "Wide cabinet includes the original vector artwork on an opaque fascia")
	if part == null: app.queue_free(); quit(1); return
	var original = part.get_active_material(0)
	var picture_id = app.world.screen_material.get_instance_id()
	var geometry_id = part.mesh.get_instance_id()
	UI.set_value(app,"room.wide_finish",1)
	check(app.world.wide_finish == 1 and part.get_active_material(0).albedo_texture.resource_path.ends_with("fascia-black.png"), "Finish menu changes to black with matching light printing")
	check(part.get_active_material(0).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Printing keeps the opaque rendering path")
	check(app.world.screen_material.get_instance_id() == picture_id and part.mesh.get_instance_id() == geometry_id, "Finish changes preserve live picture and cabinet geometry")
	check(original == part.mesh.surface_get_material(0), "Black does not mutate the shared silver material")
	app.save_settings()
	var saved := ConfigFile.new()
	check(saved.load("user://settings.cfg") == OK and saved.get_value("room","wide_finish",-1) == 1, "Chosen finish is saved to preferences")
	UI.set_value(app,"room.wide_finish",0)
	check(part.get_active_material(0) == original, "Silver restores the original material exactly")
	app.restore_settings(saved)
	check(app.world.wide_finish == 1, "Saved preferences restore the black finish")
	app.set_widescreen(false); app.set_widescreen(true)
	part = printed_part(app.world)
	check(app.world.wide_finish == 1 and part.get_active_material(0).albedo_texture.resource_path.ends_with("fascia-black.png"), "Black finish survives switching to the standard TV and back")
	UI.reset(app,"room.wide_finish")
	check(app.world.wide_finish == 0, "Reset returns the wide TV finish to silver")
	app.queue_free(); await process_frame
	quit(1 if failures else 0)
