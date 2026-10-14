extends SceneTree

var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	await process_frame
	await process_frame
	if FileAccess.file_exists("res://build/crt-model/crt_tv.glb"):
		check(not app.world.imported_screen.is_empty(), "Local GLB loads with a separate live screen")
		var mesh: ArrayMesh = app.world.television.get_node("PhosphorSurface").mesh
		check(absf(mesh.get_aabb().size.x - 1.32) < 0.001, "Imported screen preserves the existing viewing width")
		var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var facing := Vector3.ZERO
		for normal in normals:
			facing += normal
		check(facing.normalized().z > 0.9, "Imported screen faces the viewer")
		app.world.set_curvature(0.0)
		check(app.world.television.get_node("PhosphorSurface").mesh.get_aabb().size.z < 0.0001, "Imported screen supports the flat curvature setting")
		app.world.set_curvature(0.55)
	app.set_stereo(true)
	await process_frame
	await process_frame
	var left: Camera3D = app.eyes[0]
	var right: Camera3D = app.eyes[1]
	check(is_equal_approx(left.position.distance_to(right.position), app.ipd), "Physical eye separation matches IPD")
	check(left.basis.is_equal_approx(right.basis), "Parallel camera axes avoid toe-in")
	var convergence_point := Vector3(0, 1.25, -app.convergence)
	var lp: Vector2 = left.unproject_position(convergence_point) / Vector2(app.views[0].size)
	var rp: Vector2 = right.unproject_position(convergence_point) / Vector2(app.views[1].size)
	check(absf(lp.x - rp.x) < 0.001, "Convergence plane has zero horizontal disparity")
	check(absf(lp.y - rp.y) < 0.001, "Stereo views have no vertical disparity")
	var near_point := Vector3(0, 1.25, -1.0)
	lp = left.unproject_position(near_point) / Vector2(app.views[0].size)
	rp = right.unproject_position(near_point) / Vector2(app.views[1].size)
	check(lp.x > rp.x, "Near objects have crossed disparity with left/right eye order")
	var anchored: Transform3D = app.world.television.global_transform
	app.provider.angles = Vector3(0.15, 0.35, 0.10)
	await process_frame
	await process_frame
	check(not left.basis.is_equal_approx(Basis.IDENTITY), "Simulated pose rotates the cameras")
	check(anchored.is_equal_approx(app.world.television.global_transform), "Television remains anchored during head rotation")
	check(is_equal_approx(left.position.distance_to(right.position), app.ipd), "Eye separation survives head rotation")
	app.recenter()
	await process_frame
	await process_frame
	check(left.basis.is_equal_approx(Basis.IDENTITY), "Recenter restores neutral camera orientation")
	app.set_stereo(false)
	await process_frame
	await process_frame
	check(not app.panels[1].visible and is_zero_approx(left.position.x), "Mono mode uses a centered camera")
	app.distance = 3.5
	app.tv_scale = 1.2
	await process_frame
	await process_frame
	check(is_equal_approx(app.world.television.position.z, -3.5), "TV distance updates independently of head pose")
	check(app.world.television.scale.is_equal_approx(Vector3.ONE * 1.2), "TV scale control updates geometry")
	var before: float = app.pattern.elapsed
	app.pattern.paused = true
	await process_frame
	check(is_equal_approx(app.pattern.elapsed, before), "Test signal pauses")
	print("Smoke checks complete: ", failures, " failures")
	quit(0 if failures == 0 else 1)
