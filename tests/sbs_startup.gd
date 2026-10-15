extends SceneTree
var failures := 0
func check(ok: bool, message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func _initialize(): call_deferred("run")
func run():
	check(not ProjectSettings.get_setting("application/boot_splash/show_image",true),"Boot image disabled")
	check(ProjectSettings.get_setting("application/boot_splash/bg_color")==Color.BLACK,"Boot uses a plain black background")
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	var window_id: int=app.get_window().get_instance_id()
	var prompt=app.sbs_prompt
	check(prompt!=null and prompt.in_place and app.emulator==null,"Instructions start without loading the scene/emulator")
	var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_A;event.pressed=true
	prompt._input(event)
	check(prompt.darkened and not prompt.content.visible and app.emulator==null,"A submits a black curtain before scene construction")
	prompt.continue_session()
	for i in range(12): await process_frame
	check(app.sbs_prompt==null and app.stereo and app.views.size()==2,"Startup continues into stereo in the same scene tree")
	check(app.get_window().get_instance_id()==window_id,"The original window survives handover")
	check(app.emulator!=null and app.emulator.loaded and not app.emulator.paused,"ROM arguments survive; gameplay resumes after the curtain")
	app.distance_save_delay=-1;app.free();await process_frame
	var gate:="user://sbs-gate.json"
	var gate_file:=FileAccess.open(gate,FileAccess.WRITE);gate_file.store_string("invalid");gate_file.close()
	OS.set_environment("RETROCRT_STARTUP_GATE",gate)
	var desktop=load("res://scripts/ui/sbs_prompt.gd").new();desktop.in_place=true
	var signalled: Array=[]
	desktop.proceed_requested.connect(func(): signalled.append(true))
	root.add_child(desktop)
	desktop._input(event);desktop._process(.01)
	check(desktop.darkened and signalled.is_empty(),"Desktop A darkens without starting before display approval")
	gate_file=FileAccess.open(gate,FileAccess.WRITE);gate_file.store_string('{"start":true}');gate_file.close()
	desktop._process(.01);desktop._process(.01)
	check(signalled.size()==1,"Valid supervisor gate starts once, malformed gate cannot start")
	desktop.free();OS.set_environment("RETROCRT_STARTUP_GATE","")
	print("SBS startup checks complete: ",failures," failures")
	quit(1 if failures else 0)
