extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Prevent a hardware dependency; inject packets into the real provider decoder.
	var previous := OS.get_environment("CRT_XR_VITURE_SDK")
	OS.set_environment("CRT_XR_VITURE_SDK", "missing-sdk-for-protocol-test.dll")
	var provider = load("res://scripts/tracking/xr_windows_tracking.gd").new()
	OS.set_environment("CRT_XR_VITURE_SDK", previous)
	assert(not provider.valid)
	assert(provider.socket.bind(0, "127.0.0.1") == OK)
	var writer := PacketPeerUDP.new()
	writer.set_dest_address("127.0.0.1", provider.socket.get_local_port())
	writer.put_packet(JSON.stringify({"v":1,"valid":true,"sequence":1,"driver_ms":1,"q":[0,0,0,1]}).to_utf8_buffer())
	await create_timer(0.03).timeout
	provider.update(0.016)
	assert(provider.valid and provider.sequence == 1)
	assert(provider.status == "VITURE Windows / LIVE 3DoF")
	writer.put_packet(JSON.stringify({"v":1,"valid":true,"sequence":2,"q":[0,0,0,5]}).to_utf8_buffer())
	await create_timer(0.03).timeout
	provider.update(0.016)
	assert(not provider.valid and provider.sequence == 1)
	writer.put_packet(JSON.stringify({"v":1,"valid":true,"sequence":3,"q":[0,0,0,1]}).to_utf8_buffer())
	await create_timer(0.03).timeout
	provider.update(0.016)
	assert(provider.valid)
	provider.sample_time_usec = Time.get_ticks_usec() - 400000
	provider.update(0.016)
	assert(not provider.valid and provider.orientation.is_equal_approx(Quaternion.IDENTITY))
	provider.close()
	writer.close()
	print("PASS: Windows provider SDK fallback, live packet, invalid pose, recovery and stale hold")
	quit()
