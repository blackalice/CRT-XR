extends SceneTree
## Into and out of SBS: the setup screen while the XR driver switches the
## glasses itself (and its fallback to the button), and the exit note that
## waits for button-switched glasses to leave SBS before CRT XR closes.
const Prompt = preload("res://scripts/ui/sbs_prompt.gd")
const SbsExit = preload("res://scripts/ui/sbs_exit.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func probe(path: String, advertised: bool, at := -1.0) -> void:
	write(path, {"timestamp": Time.get_unix_time_from_system() if at < 0 else at, "expected": [3840, 1080], "advertised": advertised})

## A poll of the prompt, as if half a second passed with A released.
func poll(prompt) -> void:
	prompt.waiting_time = 1.0
	prompt.probe_poll = 1.0
	prompt.process_probe(0.0)

func run() -> void:
	var probe_path := ProjectSettings.globalize_path("user://sbs-auto-test-probe.json")
	var status_path := ProjectSettings.globalize_path("user://sbs-auto-test-status.json")
	probe(probe_path, false)
	OS.set_environment("CRT_XR_DISPLAY_PROBE", probe_path)
	OS.set_environment("CRT_XR_SBS_SIZE", "3840x1080")

	# 1. The driver switches the glasses: the screen says so and darkens by itself.
	OS.set_environment("CRT_XR_AUTO_SBS", status_path)
	write(status_path, {"state": "switching"})
	var prompt = Prompt.new()
	prompt.manual_confirmation = true
	prompt.in_place = true
	root.add_child(prompt)
	check("by themselves" in prompt.instructions.text and not prompt.begin_button.visible, "While the driver switches, the screen says so instead of asking for the button")
	prompt.process_probe(0.0)
	check(not prompt.probe_armed, "It waits for the launch A press to be released")
	poll(prompt)
	check(prompt.probe_armed and prompt.darkened, "Then it darkens by itself, ready for SBS")
	# 2. The driver could not: back to the button, with the screen lit again.
	write(status_path, {"state": "failed", "detail": "The driver did not acknowledge the SBS switch."})
	poll(prompt)
	check(not prompt.probe_armed and not prompt.darkened and prompt.content.visible, "If the driver can't switch them, the instructions come back")
	check("SBS button" in prompt.instructions.text and prompt.begin_button.visible and prompt.auto_path.is_empty(), "…asking for the glasses' button, with Begin")
	prompt.free()
	# 3. Glasses switched by button: the usual instructions, untouched.
	OS.unset_environment("CRT_XR_AUTO_SBS")
	prompt = Prompt.new()
	prompt.manual_confirmation = true
	prompt.in_place = true
	root.add_child(prompt)
	poll(prompt)
	check("Switch your glasses to SBS" in prompt.instructions.text and not prompt.probe_armed, "Button glasses keep the A-then-button steps")
	prompt.free()

	# 4. Leaving: only button-switched glasses still in SBS need the note.
	var now := Time.get_unix_time_from_system()
	probe(probe_path, true)
	check(SbsExit.needed(probe_path, "", now), "Glasses still in SBS after a button session get the note")
	write(status_path, {"state": "on"})
	check(not SbsExit.needed(probe_path, status_path, now), "Glasses the driver switched are switched back by the launcher, no note")
	write(status_path, {"state": "failed"})
	check(SbsExit.needed(probe_path, status_path, now), "If the driver couldn't switch them, the note is needed after all")
	check(not SbsExit.needed("", "", now), "No note outside the glasses launcher (Desktop, Windows, mono)")
	probe(probe_path, false)
	check(not SbsExit.needed(probe_path, "", now), "No note when the glasses are already back in 2D")
	probe(probe_path, true, now - 30.0)
	check(not SbsExit.needed(probe_path, "", now), "No note on a stale probe")

	# 5. The note: one per eye, closing when the glasses leave SBS.
	probe(probe_path, true)
	var note = SbsExit.new()
	note.probe_path = probe_path
	var closed := [false]
	note.done.connect(func(): closed[0] = true)
	root.add_child(note)
	var notes: Array = note.find_children("*", "PanelContainer", true, false)
	check(notes.size() == 2, "The note shows once in each eye")
	note._process(0.6)
	check(not closed[0], "It stays while the glasses are in SBS")
	probe(probe_path, false)
	note._process(0.6)
	check(not closed[0], "One reading without SBS could be a reconnect: it waits for a second")
	note._process(0.6)
	check(closed[0], "It closes once the glasses have left SBS")
	note.free()
	probe(probe_path, true)
	note = SbsExit.new()
	note.probe_path = probe_path
	closed[0] = false
	note.done.connect(func(): closed[0] = true)
	root.add_child(note)
	var press := InputEventJoypadButton.new(); press.button_index = JOY_BUTTON_B; press.pressed = true
	note._input(press)
	check(closed[0], "B leaves at once, still in SBS")
	note.free()
	note = SbsExit.new()
	note.probe_path = probe_path
	closed[0] = false
	note.done.connect(func(): closed[0] = true)
	root.add_child(note)
	note._process(SbsExit.GIVE_UP)
	check(closed[0], "After a minute it closes anyway")
	note.free()

	OS.unset_environment("CRT_XR_DISPLAY_PROBE")
	OS.unset_environment("CRT_XR_SBS_SIZE")
	for path in [probe_path, status_path]: DirAccess.remove_absolute(path)
	print("SBS AUTO SWITCH CHECKS COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
