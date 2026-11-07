extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else: push_error(message); failures += 1
func run():
	var world = load("res://scripts/rendering/crt_world.gd").new()
	root.add_child(world)
	var image := Image.create(640,360,false,Image.FORMAT_RGB8)
	image.fill(Color(.18,.34,.55))
	var texture := ImageTexture.create_from_image(image)
	world.widescreen=true
	world.build(texture)
	world.picture.source_aspect=16.0/9.0
	world.picture.refresh()
	await process_frame
	if "--preview" in OS.get_cmdline_user_args():
		root.size=Vector2i(1280,900)
		world.television.position=Vector3(0,1.25,0)
		var camera:=Camera3D.new()
		world.add_child(camera); camera.position=Vector3(0,1.6,4.2)
		camera.look_at(Vector3(0,.7,0)); camera.fov=42
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/widescreen-app.png")
		world.free(); quit(); return
	check(is_equal_approx(world.picture.tube_aspect,16.0/9.0),"Widescreen cabinet supplies a 16:9 tube")
	check(absf(world.imported_screen.width-1.76)<.001,"Wide picture retains the standard picture height")
	check(not world.clock_radio.visible and not world.game_boxes.visible,"Clock and boxes hidden while wide")
	var holder=world.television.get_node("ImportedCabinet")
	check(is_zero_approx(holder.rotation.y),"Wide cabinet faces the viewer without legacy rotation")
	var shelf=world.television.get_node("TelevisionSupport/TopShelf")
	var table: AABB=world.television.global_transform.affine_inverse()*shelf.global_transform*shelf.get_aabb()
	check(table.size.x>=world.imported_screen.cabinet_bounds.size.x,"Table supports the full cabinet width")
	world.picture.source_aspect=4.0/3.0
	world.picture.fit_mode=0
	var fit: Rect2=world.picture.picture_rect()
	check(absf(fit.size.x/fit.size.y*world.picture.tube_aspect-4.0/3.0)<.001,"Fit preserves 4:3 with side borders")
	world.picture.fit_mode=1
	var fill: Rect2=world.picture.picture_rect()
	check(fill.size.y>fit.size.y,"Fill crops vertically while preserving proportions")
	world.picture.keep_aspect=false
	var stretch: Rect2=world.picture.picture_rect()
	check(stretch.size.x>fit.size.x and stretch.size.y<fill.size.y,"Stretch uses the full available aperture")
	world.picture.keep_aspect=true; world.picture.fit_mode=0; world.picture.aspect_override=2
	var forced: Rect2=world.picture.picture_rect()
	check(absf(forced.size.x/forced.size.y*world.picture.tube_aspect-16.0/9.0)<.001,"16:9 override handles anamorphic games")
	world.picture.override={"keep_aspect":true}
	var menu_rect: Rect2=world.picture.picture_rect()
	check(absf(menu_rect.size.x/menu_rect.size.y*world.picture.tube_aspect-4.0/3.0)<.001,"Menu override stays undistorted")
	world.picture.override={}
	world.picture.menu_fitting=true
	world.picture.fit_mode=1
	var readable: Rect2=world.picture.picture_rect()
	check(readable.position.x>=0 and readable.position.y>=0 and readable.end.x<=1 and readable.end.y<=1,"Fill never crops menu text")
	world.picture.menu_fitting=false
	var pipeline_id=world.picture.get_instance_id()
	var source_id=world.picture.source_texture.get_instance_id()
	for i in range(3):
		world.set_widescreen(false)
		check(world.clock_radio.visible==world.show_clock_radio and world.game_boxes.visible==world.show_game_boxes,"Standard cabinet restores prop preferences")
		world.set_widescreen(true)
	check(pipeline_id==world.picture.get_instance_id() and source_id==world.picture.source_texture.get_instance_id(),"Repeated switching preserves the live picture pipeline")
	check(world.television.find_children("PhosphorSurface","MeshInstance3D",true,false).size()==1,"Switching leaves one active picture surface")
	world.free()
	quit(1 if failures else 0)
