extends SceneTree
var app
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func settle() -> void:
	for i in range(8): await process_frame
func sample(seconds: float, title: String) -> void:
	app.menu.boot.seek(seconds)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build/boot-review")
		app.menu_view.get_texture().get_image().save_png("res://build/boot-review/" + title + ".png")
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	if "--wide" in OS.get_cmdline_user_args(): app.set_widescreen(true)
	await settle()
	app.use_tracking(false)
	app.menu_reduced_motion = false
	app.menu_high_contrast = false
	var menu = app.menu
	menu.begin_boot()
	menu.boot.set_process(false)
	await sample(0.7, "01-logo")
	check(menu.heading.get_parent().modulate.a == 0.0, "Menu chrome is hidden behind the boot logo")
	check(menu.boot.material_space.get_shader_parameter("boot_settle") == 0.0, "Planet begins in the centre")
	await sample(2.6, "02-travel")
	var progress: float = menu.boot.material_space.get_shader_parameter("boot_settle")
	check(progress > 0.0 and progress < 1.0, "Native planet travels continuously into the corner")
	await sample(3.20, "03-build")
	check(menu.rows[0].modulate.a == 1.0 and menu.hints.get_parent().modulate.a == 0.0, "Rows appear before the footer")
	var tile_targets: Array = menu.boot.targets.filter(func(t): return t[0] in menu.rows and t[0].item.get("layout", "") == "tile")
	var same_row_pairs := 0
	var grouped := true
	for first in tile_targets:
		for second in tile_targets:
			if first[0] != second[0] and absf(first[0].global_position.y - second[0].global_position.y) < 4.0:
				same_row_pairs += 1
				grouped = grouped and first[2] == second[2]
	check(grouped and same_row_pairs > 0, "Tiles on one visual row appear together")
	menu.boot.seek(0.166667)
	check(menu.boot.diamonds[0].modulate.a < 0.01 and menu.boot.diamonds[1].modulate.a > 0.99, "AE pulse extinguishes red before green")
	menu.boot.seek(0.5)
	check(menu.boot.diamonds[1].modulate.a < 0.01 and menu.boot.diamonds[2].modulate.a > 0.99, "AE pulse then extinguishes green before blue")
	await sample(1.7, "01b-logo-flip")
	var tilt: float = menu.boot.material_logo.get_shader_parameter("angle")
	check(is_equal_approx(tilt, -52.8579), "Comp 7 tilts the logo around its X axis using AE orientation")
	menu.boot.seek(1.966667)
	check(menu.boot.mark.modulate.a < 0.01, "Comp 7 removes the edge-on logo before the planet departs")
	var chosen: String = menu.selected_id
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A; event.pressed = true
	app._input(event)
	await settle()
	check(not is_instance_valid(menu.boot) and menu.selected_id == chosen and menu.mode == "pause", "Skip press is consumed without opening the selected action")
	check(menu.backdrop.material.get_shader_parameter("boot_settle") == 1.0 and menu.rows[0].modulate.a == 1.0, "Skipping restores the exact live menu")
	# Completion, close interruption, and accessibility must all restore visibility.
	menu.begin_boot(); menu.boot.set_process(false)
	await sample(5.0, "04-ready")
	check(not is_instance_valid(menu.boot), "Completion releases the animation node")
	menu.begin_boot(); menu.boot.set_process(false)
	app.close_settings(); await settle()
	check(not is_instance_valid(menu.boot), "Closing during boot releases the animation")
	app.toggle_settings(); await settle()
	check(menu.heading.get_parent().modulate.a == 1.0, "Reopening the menu never replays boot or hides chrome")
	for setting in ["menu_reduced_motion", "menu_high_contrast"]:
		app.set(setting, true); menu.begin_boot()
		check(not is_instance_valid(menu.boot), setting + " bypasses boot")
		app.set(setting, false)
	# The saved-game page has a hero card and actions nested beside it.
	var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
	check(app.emulator.load_rom(rom), "Resume boot uses the original diagnostic cartridge")
	app.emulator.set_paused(true)
	app.emulator.core.run_frame(0)
	app.emulator.update_texture(true)
	app.emulator.auto_saved = false
	check(app.emulator.save_auto(), "Diagnostic resume point is saved")
	app.emulator.stop()
	menu.games.select_file(rom)
	await settle()
	var preview = menu.column.find_children("*", "PanelContainer", true, false).filter(func(p): return p.get("thumbnail") != null)[0]
	menu.begin_boot(); menu.boot.set_process(false)
	await sample(0.7, "05-resume-logo")
	check(menu.mode == "launch" and menu.selected_id == "launch.continue" and preview.modulate.a == 0.0, "Resume card stays hidden behind the boot logo; Continue stays selected")
	await sample(3.40, "06-resume-build")
	check(preview.modulate.a == 1.0 and menu.rows[0].modulate.a == 1.0, "Resume preview and its first action join the row reveal")
	await sample(3.80, "07-resume-ready")
	check(menu.mode == "launch" and menu.selected_id == "launch.continue" and not app.emulator.loaded, "Boot completion preserves the resume choice without launching it")
	menu.select("launch.cancel", false); menu.activate(); await settle()
	check(menu.mode == "pause" and not is_instance_valid(menu.boot), "Go to Home after resume boot restores a fully visible menu")
	app.free()
	print("MENU BOOT: ", failures, " failures")
	quit(1 if failures else 0)
