extends SceneTree
## Pure-math checks for the pose velocity estimator and extrapolation.
## The provider integration needs the live driver (live_tracking.gd).
const Predictor = preload("res://scripts/tracking/pose_prediction.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func yaw_quaternion(radians: float) -> Quaternion:
	return Basis(Vector3.UP, radians).get_rotation_quaternion()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# A steady 2 rad/s yaw, sampled at the bridge cadence (2 ms) and fed to
	# the estimator once per delivered frame, as the provider does.
	var p = Predictor.new()
	var yaw := 0.0
	var stamp := 0
	var rate := 2.0
	var frame_usec := 16000
	var sample_usec := 2000
	for iteration in range(60):
		for sample in range(8):
			yaw += rate * sample_usec / 1000000.0
			stamp += sample_usec
		p.sample(yaw_quaternion(yaw), stamp)
	check(absf(p.angular_velocity.y - rate) < 0.1,
		"Steady 2 rad/s yaw is estimated within 0.1 rad/s (got %.3f)" % p.angular_velocity.y)
	check(absf(p.angular_velocity.x) < 0.01 and absf(p.angular_velocity.z) < 0.01,
		"Steady yaw reports no cross-axis velocity")

	# Extrapolation must land on the true future orientation at 40 ms.
	var now := yaw_quaternion(yaw)
	var future := yaw_quaternion(yaw + rate * 0.04)
	var predicted := Predictor.extrapolate(now, p.angular_velocity, 0.04)
	check(predicted.angle_to(future) < 0.01, "40 ms extrapolation lands within 0.01 rad of the true pose")

	# A one-sample glitch is clamped to the limit, never chased past it.
	p.sample(yaw_quaternion(yaw + 3.0), stamp + frame_usec)
	check(p.angular_velocity.length() <= 8.001, "A glitch sample cannot exceed the velocity limit")

	# No new poses: the estimate bleeds away instead of drifting the view.
	var before_decay: float = p.angular_velocity.length()
	for iteration in range(12): p.decay(0.016)
	check(p.angular_velocity.length() < before_decay * 0.5, "Velocity decays without new samples")

	# A step across the ±pi wrap is read as the short path, not a 2π spin.
	p.reset()
	p.sample(yaw_quaternion(3.13), 0)
	p.sample(yaw_quaternion(-3.13), 16667)
	check(p.angular_velocity.length() < 1.0, "A wrap-around step is read as the short path")

	# Zero velocity leaves the pose untouched; a reset clears history.
	check(Predictor.extrapolate(now, Vector3.ZERO, 0.04).is_equal_approx(now), "Zero velocity leaves the pose untouched")
	p.reset()
	check(p.angular_velocity == Vector3.ZERO, "Reset clears the estimate")

	print("Pose prediction checks complete: ", failures, " failures")
	quit(0 if failures == 0 else 1)
