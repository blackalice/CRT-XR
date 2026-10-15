extends SceneTree
## Hardware integration check. Requires the verified driver, enabled and connected.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.close_settings()
	# The prediction path is unit-tested in pose_prediction.gd; this check
	# verifies the raw driver -> camera chain, so disable extrapolation.
	app.motion_predict = 0.0
	# process_frame fires before Node._process; let initial scene placement settle.
	await process_frame
	await process_frame
	await process_frame
	var deadline := Time.get_ticks_msec() + 5000
	var valid_frames := 0
	var first_sequence := -1
	var last_sequence := -1
	var anchored: Transform3D
	var have_anchor := false
	var error := ""
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not have_anchor:
			anchored = app.world.television.transform
			have_anchor = true
		if not anchored.is_equal_approx(app.world.television.transform):
			error = "Television moved during real tracking"
		if app.provider.valid:
			valid_frames += 1
			last_sequence = app.provider.sequence
			if first_sequence == -1: first_sequence = last_sequence
			var expected: Quaternion = app.center.inverse() * app.provider.orientation
			if app.eyes[0].quaternion.angle_to(expected) > 0.001:
				error = "Camera orientation does not match tracking provider"
	print("Live tracking: valid frames=", valid_frames, " source sequence progress=", last_sequence - first_sequence)
	if valid_frames < 30 or last_sequence - first_sequence < 25:
		error = "Insufficient live tracking data: " + app.provider.status
	if not error.is_empty():
		push_error(error)
		quit(1)
	else:
		print("PASS: Live driver -> native helper -> Godot camera; TV remains anchored")
		quit(0)
