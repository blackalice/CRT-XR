extends TrackingProvider
## Native helper keeps driver synchronization outside Godot's rendering process.
const Predictor = preload("res://scripts/tracking/pose_prediction.gd")

var socket := PacketPeerUDP.new()
var helper_pid := -1
var sequence := -1
var raw_orientation := Quaternion.IDENTITY
var helper_check_elapsed := 0.0
var helper_alive := true

var predictor := Predictor.new()

var live_status := "XRLinuxDriver / LIVE 3DoF"

func _init() -> void:
	valid = false
	if OS.get_name() != "Linux":
		status = "Real tracking requires Linux; select simulation"
		return
	var driver := OS.get_environment("HOME").path_join(".local/bin/xrDriver")
	if not FileAccess.file_exists(driver):
		status = "XR Gaming driver missing; install or enable XR Gaming"
		return
	var base := ProjectSettings.globalize_path("res://dist/linux") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	var helper := base.path_join("crt-xr-tracking-bridge")
	if not FileAccess.file_exists(helper):
		status = "Tracking helper missing; select simulation"
		return
	var error := socket.bind(0, "127.0.0.1")
	if error != OK:
		status = "Tracking socket: " + error_string(error)
		return
	helper_pid = OS.create_process(helper, [str(socket.get_local_port()), str(OS.get_process_id())])
	status = "Waiting for driver / calibration" if helper_pid > 0 else "Unable to start tracking helper"

func update(delta: float) -> void:
	var newest_stamp_usec := -1
	# The ~2 ms bridge cadence delivers a burst per frame; only the newest
	# conclusive packet decides the outcome, so drain the queue and parse
	# newest-first instead of JSON-decoding every packet.
	var packets: Array[PackedByteArray] = []
	for i in range(mini(socket.get_available_packet_count(), 512)):
		var packet := socket.get_packet()
		if socket.get_packet_ip() == "127.0.0.1" and packet.size() <= 512: packets.append(packet)
	for i in range(packets.size() - 1, -1, -1):
		var message = JSON.parse_string(packets[i].get_string_from_utf8())
		if not message is Dictionary or message.get("v", 0) != 1:
			continue
		if not message.get("valid", false):
			if message.get("status", "") == "driver_lock_busy":
				continue # brief contention is not a disconnect; watchdog still applies
			valid = false
			status = "XR: " + str(message.get("status", "unavailable"))
			break
		var next_sequence := int(message.get("sequence", -1))
		if next_sequence <= sequence:
			continue
		var q = message.get("q", [])
		if not q is Array or q.size() != 4:
			continue
		var pose := Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3]))
		if not pose.is_finite() or absf(pose.length_squared() - 1.0) > 0.02:
			valid = false
			status = "XR: invalid orientation"
			break
		sequence = next_sequence
		raw_orientation = pose.normalized()
		sample_time_usec = Time.get_ticks_usec()
		# The bridge forwards the driver's own timestamp; use it so velocity
		# follows real pose timing rather than delivery jitter.
		var driver_ms = message.get("driver_ms", -1.0)
		newest_stamp_usec = int(round(float(driver_ms) * 1000.0)) if float(driver_ms) >= 0.0 else sample_time_usec
		valid = true
		status = live_status
		break
	if valid and Time.get_ticks_usec() - sample_time_usec > 300000:
		valid = false
		status = "XR: stale tracking / holding last pose"
	helper_check_elapsed += delta
	if helper_check_elapsed >= 1.0 and helper_pid > 0:
		helper_check_elapsed = 0.0
		helper_alive = OS.is_process_running(helper_pid)
	if helper_pid > 0 and not helper_alive:
		valid = false
		status = "XR: helper stopped; select simulation or retry tracking"
	var angles := raw_orientation.get_euler()
	angles *= Vector3(-1.0 if invert_pitch else 1.0, -1.0 if invert_yaw else 1.0, -1.0 if invert_roll else 1.0)
	orientation = Basis.from_euler(angles).get_rotation_quaternion()
	# One velocity update per frame, from the newest accepted pose; the
	# 2 ms bridge cadence arrives in one burst.
	if not valid:
		predictor.reset()
	elif newest_stamp_usec >= 0:
		predictor.sample(orientation, newest_stamp_usec)
	else:
		predictor.decay(delta)
	angular_velocity = predictor.angular_velocity

func close() -> void:
	if helper_pid > 0 and OS.is_process_running(helper_pid):
		OS.kill(helper_pid)
	helper_pid = -1
	socket.close()
