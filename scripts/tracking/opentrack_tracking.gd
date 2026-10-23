extends TrackingProvider
## Head tracking from any tool that speaks OpenTrack's UDP format: opentrack
## itself, or a glasses app such as PhoenixHeadTracker (XREAL) or VertoXR
## (Rokid, RayNeo). Each packet is six little-endian doubles, x y z yaw pitch
## roll with angles in degrees, sometimes followed by a frame number. Only this
## computer may send: the socket listens on 127.0.0.1.
const Predictor = preload("res://scripts/tracking/pose_prediction.gd")
const PORT := 4242
const PACKET_BYTES := 48
## OpenTrack documents no sign convention. XRLinuxDriver, the glasses driver
## behind XR Gaming, sends its own angles unchanged in the VITURE SDK's frame,
## so they map the same way: Godot yaw = yaw, pitch = -pitch, roll = -roll.
## The invert settings correct a tool that differs.
const SIGNS := Vector3(-1.0, 1.0, -1.0)

var socket := PacketPeerUDP.new()
var raw_orientation := Quaternion.IDENTITY
var predictor := Predictor.new()
var port := PORT

func _init(listen_port := PORT) -> void:
	real = true
	valid = false
	port = listen_port
	var error := socket.bind(port, "127.0.0.1")
	if error != OK:
		status = "OpenTrack: UDP port %d is in use by another program" % port
		return
	status = "Waiting for OpenTrack on UDP 127.0.0.1:%d" % port

## Godot orientation for one packet, or null when it is not a usable pose.
static func decode(packet: PackedByteArray) -> Variant:
	if packet.size() < PACKET_BYTES: return null
	var angles := Vector3(packet.decode_double(32), packet.decode_double(24), packet.decode_double(40))
	if not angles.is_finite() or absf(angles.x) > 360.0 or absf(angles.y) > 360.0 or absf(angles.z) > 360.0: return null
	return Basis.from_euler(angles * SIGNS * (PI / 180.0), EULER_ORDER_YXZ).get_rotation_quaternion()

func update(delta: float) -> void:
	var received := false
	# Tools send at up to 250 Hz; only the newest usable pose in a frame matters.
	for i in range(mini(socket.get_available_packet_count(), 512)):
		var packet := socket.get_packet()
		if socket.get_packet_ip() != "127.0.0.1": continue
		var pose = decode(packet)
		if pose == null: continue
		raw_orientation = pose
		received = true
	if received:
		sample_time_usec = Time.get_ticks_usec()
		valid = true
		status = "OpenTrack UDP / LIVE 3DoF"
	elif valid and Time.get_ticks_usec() - sample_time_usec > 300000:
		valid = false
		status = "OpenTrack: no data / holding last pose"
	var angles := raw_orientation.get_euler()
	angles *= Vector3(-1.0 if invert_pitch else 1.0, -1.0 if invert_yaw else 1.0, -1.0 if invert_roll else 1.0)
	orientation = Basis.from_euler(angles).get_rotation_quaternion()
	if not valid: predictor.reset()
	elif received: predictor.sample(orientation, sample_time_usec)
	else: predictor.decay(delta)
	angular_velocity = predictor.angular_velocity

func close() -> void:
	socket.close()
