extends SceneTree
## A presented game frame must reach the shared decode/beam passes in the same
## room frame. The pipeline processes before the emulator, so scheduling the
## passes from its own _process would show the previous frame for one more frame.
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var pipeline = preload("res://scripts/rendering/picture_pipeline.gd").new()
	root.add_child(pipeline)
	var screen := ShaderMaterial.new()
	screen.shader = preload("res://shaders/crt.gdshader")
	screen.set_shader_parameter("scanlines", 0.22)
	var image := Image.create(256, 224, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	pipeline.configure(screen, texture, Rect2(0.03, 0.03, 0.94, 0.94), 4.0 / 3.0)
	pipeline.mode = 1 # composite: the decode pass is active too
	pipeline.set_source(texture, true)
	await process_frame
	await process_frame
	check(pipeline.decode_active and pipeline.beam_active, "composite decode and the shared beam are active")
	pipeline.decode.render_target_update_mode = SubViewport.UPDATE_DISABLED
	pipeline.beam.render_target_update_mode = SubViewport.UPDATE_DISABLED
	pipeline.frame_presented(image)
	check(pipeline.decode.render_target_update_mode == SubViewport.UPDATE_ONCE, "a presented frame schedules the decode pass at once")
	check(pipeline.beam.render_target_update_mode == SubViewport.UPDATE_ONCE, "a presented frame schedules the beam pass at once")
	check(not pipeline.frame_pending, "nothing is left for the next room frame")
	pipeline.paused = true
	pipeline.decode.render_target_update_mode = SubViewport.UPDATE_DISABLED
	pipeline.frame_presented(image)
	check(pipeline.decode.render_target_update_mode == SubViewport.UPDATE_DISABLED and pipeline.frame_pending, "a paused picture waits for its refresh as before")
	pipeline.queue_free()
	await process_frame
	print("PICTURE LATENCY COMPLETE failures=", failures)
	quit(1 if failures else 0)
