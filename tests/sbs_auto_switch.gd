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
	prompt.waiting_time = maxf(prompt.waiting_time, 1.0)
	prompt.probe_poll = 1.0
	prompt.process_probe(0.0)

func run() -> void:
	var probe_path := ProjectSettings.globalize_path("user://sbs-auto-test-probe.json")
	var status_path := ProjectSettings.globalize_path("user://sbs-auto-test-status.json")
	probe(probe_path, false)
	OS.set_environment("CRT_XR_DISPLAY_PROBE", probe_path)
	OS.set_environment("CRT_XR_SBS_SIZE", "3840x1080")

	# 1. The driver switches the glasses: the screen says so; nothing to press.
	OS.set_environment("CRT_XR_AUTO_SBS", status_path)
	write(status_path, {"state": "switching"})
	var prompt = Prompt.new()
	prompt.manual_confirmation = true
	prompt.in_place = true
	root.add_child(prompt)
	poll(prompt)
	check("by themselves" in prompt.instructions.text and "Switching" in prompt.status.text, "While the driver switches, the screen says so")
	check(prompt.begin_button == null and prompt.probe_armed and not prompt.darkened, "Nothing to press, and the screen stays lit in 2D")
	# 2. The driver could not: the button instead, with a tip saying why.
	write(status_path, {"state": "failed", "detail": "The driver did not acknowledge the SBS switch."})
	poll(prompt)
	check("SBS button" in prompt.instructions.text and prompt.tip.visible and prompt.auto_path.is_empty(), "If the driver can't switch them, it asks for the glasses' button")
	prompt.free()

	# 3. Button glasses: SBS appearing darkens the screen, and the room follows.
	OS.unset_environment("CRT_XR_AUTO_SBS")
	prompt = Prompt.new()
	prompt.manual_confirmation = true
	prompt.in_place = true
	var started := [false]
	prompt.proceed_requested.connect(func(): started[0] = true)
	root.add_child(prompt)
	poll(prompt)
	check("SBS button" in prompt.instructions.text and "Waiting" in prompt.status.text and not prompt.darkened, "Button glasses: press the SBS button, nothing else")
	probe(probe_path, true)
	poll(prompt)
	check(prompt.darkened, "The screen goes dark as soon as the glasses switch")
	check(not started[0] and not prompt.stereo_note.visible, "…and waits for the display to settle")
	prompt.waiting_time = prompt.dark_since + Prompt.TIP_AFTER
	poll(prompt)
	check(prompt.stereo_note.visible and prompt.stereo_note.get_child_count() == 2, "Dark for a while in SBS: a note in each eye about Steam's resolution")
	prompt.free()
	# Listed from the start (already in SBS, or listed in 2D): no darkening by itself.
	probe(probe_path, true)
	prompt = Prompt.new()
	prompt.in_place = true
	root.add_child(prompt)
	poll(prompt); poll(prompt)
	check(not prompt.darkened, "An SBS mode listed from the start doesn't blank a 2D screen")
	prompt.waiting_time = Prompt.TIP_AFTER
	poll(prompt)
	check(prompt.tip.visible and "USB" in prompt.tip_label.text, "Still waiting after a while: a tip on the screen")
	prompt.free()
	probe(probe_path, false)

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
