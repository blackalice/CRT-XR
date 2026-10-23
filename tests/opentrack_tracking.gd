extends SceneTree
## OpenTrack UDP tracking without hardware: real packets over loopback.
const OpenTrack = preload("res://scripts/tracking/opentrack_tracking.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func packet(yaw: float, pitch: float, roll: float, frame := -1) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(52 if frame >= 0 else 48)
	var values := [1.0, 2.0, 3.0, yaw, pitch, roll]
	for i in range(6): bytes.encode_double(i * 8, values[i])
	if frame >= 0: bytes.encode_u32(48, frame)
	return bytes

func send(writer: PacketPeerUDP, provider, bytes: PackedByteArray) -> void:
	writer.put_packet(bytes)
	await create_timer(0.03).timeout
	provider.update(0.016)

func run() -> void:
	var port := 42420 + randi() % 500
	var provider = OpenTrack.new(port)
	check(provider.real and not provider.valid and provider.status.contains("Waiting for OpenTrack"), "Starts waiting on loopback: " + provider.status)
	var busy = OpenTrack.new(port)
	check(not busy.valid and busy.status.contains("in use"), "A port already in use is reported: " + busy.status)
	busy.close()
	var writer := PacketPeerUDP.new()
	writer.set_dest_address("127.0.0.1", port)

	await send(writer, provider, packet(30.0, 0.0, 0.0))
	var angles: Vector3 = provider.orientation.get_euler()
	check(provider.valid and provider.status == "OpenTrack UDP / LIVE 3DoF", "A 48-byte opentrack packet goes live")
	check(is_equal_approx(angles.y, deg_to_rad(30.0)) and absf(angles.x) < 0.001 and absf(angles.z) < 0.001, "Yaw carries over as Godot yaw (%s)" % angles)
	await send(writer, provider, packet(0.0, 10.0, 0.0, 7))
	angles = provider.orientation.get_euler()
	check(is_equal_approx(angles.x, deg_to_rad(-10.0)), "A 52-byte packet with a frame number is accepted; pitch maps like the VITURE SDK (%s)" % angles)
	await send(writer, provider, packet(0.0, 0.0, 20.0))
	angles = provider.orientation.get_euler()
	check(is_equal_approx(angles.z, deg_to_rad(-20.0)), "Roll maps like the VITURE SDK (%s)" % angles)
	provider.invert_yaw = true
	await send(writer, provider, packet(30.0, 0.0, 0.0))
	check(is_equal_approx(provider.orientation.get_euler().y, deg_to_rad(-30.0)), "Invert yaw reverses it")
	provider.invert_yaw = false
	provider.update(0.016)

	var before: Quaternion = provider.orientation
	await send(writer, provider, packet(NAN, 0.0, 0.0))
	await send(writer, provider, PackedByteArray([1, 2, 3]))
	check(provider.orientation.is_equal_approx(before), "Non-finite and short packets are ignored")
	provider.sample_time_usec = Time.get_ticks_usec() - 400000
	provider.update(0.016)
	check(not provider.valid and provider.status.contains("holding last pose") and provider.orientation.is_equal_approx(before), "A silent tool holds the last pose")
	await send(writer, provider, packet(5.0, 0.0, 0.0))
	check(provider.valid, "Tracking resumes when packets return")
	provider.close()
	writer.close()

	# The app switches source from settings, and the menu offers it.
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(4): await process_frame
	app.use_tracking(true)
	app.set_tracking_source("opentrack")
	check(app.provider is OpenTrack and app.provider.real, "Choosing OpenTrack switches the live tracking source")
	check(app.capture_settings().get_value("tracking", "source") == "opentrack", "The choice is saved with the settings")
	var rows: Array = []
	for page in app.menu.catalog.pages(4): rows.append_array(page.rows.map(func(row): return row.id))
	check("tracking.source" in rows, "Controls & XR offers the tracking source")
	app.set_tracking_source("glasses")
	check(not app.provider is OpenTrack, "Back to the glasses' own tracking")
	print("OPENTRACK CHECKS COMPLETE: %d failures" % failures)
	quit(1 if failures else 0)
