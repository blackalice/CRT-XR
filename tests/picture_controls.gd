extends SceneTree
const UI=preload("res://tests/menu_test_helpers.gd")
var failures := 0
var app
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if ok: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func settle():
	for i in range(5): await process_frame
	if DisplayServer.get_name()!="headless": RenderingServer.force_draw()
func run():
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.menu_on_tv = false # the bezel checks look past a floating menu at the picture
	# Geometry readback must not race the separately tested tube power-on reveal.
	app.power_on.enabled=false
	app.power_on.apply()
	app.close_settings()
	app.use_tracking(false)
	app.set_stereo(true)
	app.toggle_settings()
	await settle()
	var picture = app.world.picture
	print("MODEL_SAFE_RECT ", picture.safe_rect, " imported=", not app.world.imported_screen.is_empty())
	check(picture.safe_rect.size.x < .95 and picture.safe_rect.size.x > .5, "Model-derived safe aperture reserves rounded corners and bezel clearance")
	picture.set_value("width", .72)
	picture.set_value("gamma", 1.8)
	app.apply_picture_preset("pal")
	await settle()
	check(is_equal_approx(picture.values.width,.72) and picture.mode == 2, "PAL preset preserves picture fitting")
	UI.set_value(app,"picture.gamma",1.8)
	UI.reset(app,"picture.gamma")
	check(is_equal_approx(picture.values.gamma,2.25) and picture.mode==2 and is_equal_approx(picture.values.width,.72),"Per-option reset changes only gamma")
	for section in [1,3]:
		UI.page(app,1,section)
		await settle()
		check(app.menu.get_rect().end.y<=720 and app.menu.get_rect().end.x<=960,"Picture controls fit the shared eye canvas")
	picture.set_value("shift_x", .65)
	picture.keep_aspect = false
	picture.set_value("saturation", .8)
	app.save_settings()
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	check(is_equal_approx(config.get_value("picture","shift_x"),.65) and not config.get_value("picture","keep_aspect") and config.get_value("picture","connection") == 2, "Fitting and connection settings persist together")
	# Read back only coloured test markers; never save or inspect licensed model images.
	app.settings_panel.hide()
	picture.reset_fields(picture.FIT_FIELDS)
	picture.keep_aspect = true
	app.apply_picture_preset("clean")
	app.settings_panel.hide()
	app.world.glass_material.set_shader_parameter("reflection_strength",0)
	var image := Image.create(256,240,false,Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	var colors := [Color.RED,Color.GREEN,Color.BLUE,Color.YELLOW]
	for i in range(4):
		image.fill_rect(Rect2i((256-20) if i%2 else 0,(240-20) if i>=2 else 0,20,20),colors[i])
	picture.set_source(ImageTexture.create_from_image(image))
	app.vertical_fov = 24
	app.distance = 3.4
	app.tv_scale = 1
	app.height_offset = 0
	app.recenter()
	await settle()
	for curvature in [0.0,.55,1.0]:
		app.world.set_curvature(curvature)
		await settle()
		for eye in range(2):
			var rendered: Image = app.views[eye].get_texture().get_image()
			var counts := [0,0,0,0]
			for y in range(rendered.get_height()):
				for x in range(rendered.get_width()):
					var c := rendered.get_pixel(x,y)
					if c.r>.8 and c.g<.1 and c.b<.1: counts[0]+=1
					elif c.g>.8 and c.r<.1 and c.b<.1: counts[1]+=1
					elif c.b>.8 and c.r<.1 and c.g<.1: counts[2]+=1
					elif c.r>.8 and c.g>.8 and c.b<.1: counts[3]+=1
			check(counts.min()>20,"All four source-edge markers remain visible through actual bezel: curvature %.2f eye %d counts %s" % [curvature,eye,str(counts)])
	app.settings_panel.show()
	for scale_value in [.5,1.6]:
		app.tv_scale = scale_value
		app.height_offset = .8
		app.distance = 1.2
		app.fit_tv_to_view()
		await settle()
		var screen: MeshInstance3D = app.world.television.get_node("PhosphorSurface")
		var box := screen.get_aabb()
		for eye in range(2):
			var camera: Camera3D = app.eyes[eye]
			var inside := true
			for i in range(8):
				var pixel := camera.unproject_position(screen.global_transform * box.get_endpoint(i))
				inside = inside and Rect2(Vector2.ZERO,Vector2(app.views[eye].size)).has_point(pixel)
			check(inside,"Fit TV frames the whole tube at extreme scale %.1f in eye %d" % [scale_value,eye])
	app.distance_save_delay = -1
	# Window exit also autosaves now: restore the deliberately saved fixture first.
	app.apply_settings(config)
	app.free()
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.menu_on_tv = false # the bezel checks look past a floating menu at the picture
	app.close_settings()
	await settle()
	check(is_equal_approx(app.world.picture.values.shift_x,.65) and not app.world.picture.keep_aspect and app.world.picture.mode==2 and is_equal_approx(app.world.picture.values.saturation,.8),"New instance restores fitting, connection and colour controls")
	app.distance_save_delay = -1
	app.free()
	quit(1 if failures else 0)
