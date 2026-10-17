extends SceneTree
const Brand=preload("res://scripts/ui/startup_brand.gd")
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 for stereo in [false,true]:
  var brand=Brand.new();brand.stereo=stereo;root.add_child(brand)
  for i in range(4):await process_frame
  var eyes=brand.get_child(1)
  assert(eyes.get_child_count()==(2 if stereo else 1))
  for center in eyes.get_children():
   assert(center.get_child(0).get_global_rect().end.x<=1280)
   assert(center.get_child(0).get_global_rect().end.y<=720)
  brand.free()
 OS.set_environment("CRT_XR_DISPLAY_PROBE","res://build/visual-only-probe.json")
 OS.set_environment("CRT_XR_SBS_SIZE","3840x1080")
 var prompt=load("res://scripts/ui/sbs_prompt.gd").new();prompt.manual_confirmation=true;root.add_child(prompt)
 for i in range(4):await process_frame
 var center=prompt.prompt_canvas.get_child(0)
 var panel=center.get_child(0)
 assert(panel.get_global_rect().position.y>=0 and panel.get_global_rect().end.y<=720)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/branded-sbs-prompt-only.png")
 prompt.free()
 OS.unset_environment("CRT_XR_DISPLAY_PROBE");OS.unset_environment("CRT_XR_SBS_SIZE")
 print("STARTUP BRAND CHECK: PASS")
 quit()
