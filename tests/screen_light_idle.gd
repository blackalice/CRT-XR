extends SceneTree
## CPU-side sampling checks; no model or graphics readback.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func run() -> void:
	var light = load("res://scripts/rendering/screen_light.gd").new()
	root.add_child(light)
	light.set_process(false)
	light.grading = {"hue":0.0,"saturation":1.0,"gamma":2.25,"brightness":1.0,"contrast":1.0,"temperature":0.0}
	var image := Image.create(256,224,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	light.set_image(image)
	light._process(.05)
	var count: int = light.sample_count
	for i in range(60): light._process(1.0/60.0)
	check(light.sample_count == count,"Unchanged paused picture is sampled only once")
	image.fill(Color.BLUE)
	light.set_image(image)
	light._process(.05)
	check(light.sample_count == count+1 and light.target.z>.1 and light.target.x<.001,"Reused mutable emulator Image is sampled when presented")
	light.grading.brightness = .5
	light._process(.05)
	check(light.sample_count == count+2,"Paused grading changes are sampled")
	light.picture_area = .4
	light._process(.05)
	check(light.sample_count == count+3 and absf(light.target.z-.2)<.001,"Picture fitting changes update radiance")
	light.scale = Vector3.ONE*1.5
	light._process(0)
	check(is_equal_approx(light.lights[0].omni_range,light.GLOW_RANGE*1.5),"Reach still follows TV scale")
	check(light.lights.all(func(l):return not l.shadow_enabled),"Screen glow avoids live shadow passes")
	light.free()
	quit(1 if failures else 0)
