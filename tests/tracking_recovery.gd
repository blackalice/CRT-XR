extends SceneTree
## Real bridge decoder and app camera logic, with loopback packets; no glasses.
var failures := 0
var app
var provider
var writer := PacketPeerUDP.new()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func deliver(message: Dictionary) -> void:
	writer.put_packet(JSON.stringify(message).to_utf8_buffer())
	await create_timer(.03).timeout
	app._process(.016)

func pose(sequence: int, yaw: float) -> Dictionary:
	var q := Quaternion(Vector3.UP, yaw)
	return {"v":1,"valid":true,"sequence":sequence,"driver_ms":sequence*16,"q":[q.x,q.y,q.z,q.w]}

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	app.vcr_sounds.enabled = false
	app.vcr_sounds.stop_all()
	app.provider.close()
	provider = load("res://scripts/tracking/xr_linux_tracking.gd").new()
	# Linux may have started a helper; this fixture owns its socket instead.
	provider.close()
	provider.helper_pid = -1
	check(provider.socket.bind(0,"127.0.0.1") == OK,"Fixture binds tracking socket")
	writer.set_dest_address("127.0.0.1",provider.socket.get_local_port())
	app.provider = provider
	app.needs_center = true
	app.tracking_was_valid = false
	app.motion_predict = 0.0
	app.smoothing = 0.0
	await deliver(pose(1,.2))
	var anchor: Quaternion = app.center
	check(app.displayed.angle_to(Quaternion.IDENTITY)<.001,"Initial tracking centres normally")
	# Simulate no delivery during a synchronous state restore, then head motion.
	provider.sample_time_usec = Time.get_ticks_usec()-400000
	app._process(.4)
	check(not provider.valid,"Sample gap holds tracking")
	await deliver(pose(2,.5))
	check(app.center.angle_to(anchor)<.001 and app.displayed.angle_to(Quaternion(Vector3.UP,.3))<.001,"Recovery after a restore-sized gap preserves the anchor and head movement")
	await deliver({"v":1,"valid":false,"status":"tracking_stale"})
	await deliver(pose(3,.6))
	check(app.center.angle_to(anchor)<.001,"Driver stale report also preserves the anchor")
	await deliver({"v":1,"valid":false,"status":"driver_disabled_or_disconnected"})
	await deliver({"v":1,"valid":false,"status":"tracking_stale"})
	var held: Quaternion = app.displayed
	await deliver(pose(4,1.1))
	check(app.displayed.angle_to(held)<.001 and app.center.angle_to(anchor)>.1,"Actual driver reconnect retains continuous-view rebasing")
	app.recenter()
	check(app.displayed.angle_to(Quaternion.IDENTITY)<.001,"R3 recenter still works")
	writer.close()
	app.free()
	# Allow the audio server to release any startup/menu playback references.
	await process_frame
	await process_frame
	quit(1 if failures else 0)
