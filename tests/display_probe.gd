extends SceneTree
const Prompt=preload("res://scripts/ui/sbs_prompt.gd")
func _initialize(): call_deferred("run")
func run():
 var size:=Vector2i(5120,1440)
 var data:={"timestamp":100.0,"expected":[5120,1440],"advertised":true}
 assert(Prompt.probe_matches(data,size,size,size,100.0))
 assert(Prompt.probe_matches(JSON.parse_string(JSON.stringify(data)),size,size,size,100.0))
 assert(not Prompt.probe_matches(data,size,Vector2i(1920,1080),size,100.0))
 assert(not Prompt.probe_matches(data,size,size,Vector2i(1920,1080),100.0))
 assert(not Prompt.probe_matches(data,size,size,size,104.0))
 data.advertised=false
 assert(not Prompt.probe_matches(data,size,size,size,100.0))
 data.advertised=true
 assert(not Prompt.probe_matches(data,Vector2i(3840,1080),size,size,100.0))
 for invalid in [[5120.5,1440],[],[5120],"5120x1440",["5120",1440]]:
  var broken=data.duplicate();broken.expected=invalid
  assert(not Prompt.probe_matches(broken,size,size,size,100.0))
 OS.set_environment("CRT_XR_DISPLAY_PROBE","res://build/not-a-real-probe.json")
 OS.set_environment("CRT_XR_SBS_SIZE","5120x1440")
 var prompt=Prompt.new()
 prompt.manual_confirmation=true
 root.add_child(prompt)
 assert(prompt.probe_expected==size)
 assert(prompt.prompt_canvas.size==Vector2(1280,720))
 assert(prompt.prompt_canvas.scale==prompt.get_viewport_rect().size/Vector2(1280,720))
 var event=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_A;event.pressed=true
 prompt._input(event)
 assert(not prompt.probe_armed and not prompt.darkened)
 prompt.on_window_size_changed()
 assert(not prompt.darkened)
 prompt.probe_ready=true
 prompt._input(event)
 assert(prompt.probe_armed and prompt.darkened)
 prompt._input(event)
 prompt.continue_session()
 assert(not prompt.proceeding)
 prompt.free()
 OS.unset_environment("CRT_XR_DISPLAY_PROBE")
 OS.unset_environment("CRT_XR_SBS_SIZE")
 print("SBS DISPLAY PROBE CHECK: PASS")
 quit()
