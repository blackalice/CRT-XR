extends SceneTree
const UI=preload("res://tests/menu_test_helpers.gd")
var failures:=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func settle():
	for i in range(12):await process_frame
func run():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.use_tracking(false)
	if is_instance_valid(app.menu.boot):app.menu.boot.finish()
	app.menu_boot_pending=false;app.menu_reduced_motion=true
	app.set_widescreen(false);UI.page(app,1,1);await settle()
	var menu=app.menu
	var frame: Vector2=menu.reading_frame.size
	var body: Vector2=menu.body.size
	var first: Rect2=menu.rows[0].get_global_rect()
	var font_size: int=menu.rows[0].title_label.get_theme_font_size("font_size")
	app.set_widescreen(true);await settle()
	check(app.menu_view.size==Vector2i(1280,720),"Wide TV receives a native 16:9 menu canvas")
	check(menu.reading_frame.size==frame and menu.body.size==body,"Reading area and main sections keep their standard-TV dimensions")
	var wide: Rect2=menu.rows[0].get_global_rect()
	check(wide.size==first.size and is_equal_approx(wide.position.x-first.position.x,160),"Rows stay the same size and centre in the wider canvas")
	check(menu.rows[0].title_label.get_theme_font_size("font_size")==font_size,"Widescreen leaves text at its original size")
	check(menu.backdrop.size.x==menu.size.x and menu.backdrop.size.x>frame.x,"Background extends into the side space")
	check(menu.position==Vector2.ZERO and menu.size==Vector2(app.menu_view.size),"Wide background reaches every canvas edge without an outer inset")
	check(is_equal_approx(app.world.picture.source_aspect,16.0/9.0) and app.world.picture.picture_rect().size.x>.95,"TV fitting uses the complete wide backdrop without pillarboxing")
	var old_values:Dictionary=app.world.picture.values.duplicate()
	app.world.picture.values.width=.7;app.world.picture.values.height=.8;app.world.picture.values.shift_x=.5;app.world.picture.refresh()
	check(app.world.picture.picture_rect()==Rect2(0,0,1,1),"Game picture size and offset cannot shrink or shift the menu background")
	app.world.picture.values=old_values;app.world.picture.refresh()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image=app.menu_view.get_texture().get_image()
		check(image.get_pixel(100,200).a>.99 and image.get_pixel(1180,200).a>.99,"Background renders on both sides of the fixed-width content")
		image.save_png("res://build/player-display-update/wide-menu.png")
		app.views[0].get_texture().get_image().save_png("res://build/player-display-update/wide-menu-on-tv.png")
	UI.select(app,"view.distance");await settle()
	menu.toggle_preview();await settle()
	check(app.menu_view.size==Vector2i(960,720) and not app.tv_menu.active and menu.size.y==170,"Placement preview retains its compact floating layout: "+str(menu.size))
	menu.toggle_preview();await settle()
	check(app.menu_view.size==Vector2i(1280,720) and app.tv_menu.active,"Leaving preview restores the wide background")
	app.menu_clean_feed=true;await settle()
	check(is_equal_approx(app.world.picture.source_aspect,16.0/9.0),"Clean feed also uses the complete wide menu")
	app.set_widescreen(false);await settle()
	check(app.menu_view.size==Vector2i(960,720) and menu.reading_frame.size==frame,"Standard TV restores its original canvas and unchanged content layout")
	app.queue_free();await process_frame
	quit(1 if failures else 0)
