extends SceneTree
var failures := 0
const Locations = preload("res://scripts/content/rom_locations.gd")
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1
func _initialize(): call_deferred("run")
func settle():
	for i in range(4): await process_frame
func press(code: int):
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 7
		event.button_index = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await settle()
func run():
	var mounts := "11 1 179:1 / /run/media/deck/My\\040SD rw - ext4 /dev/mmcblk0p1 rw\n12 1 259:1 / /home rw - ext4 /dev/nvme0n1p1 rw\n13 1 8:1 / /run/media/deck/USB rw - vfat /dev/sda1 rw\n14 1 179:1 / /run/media/deck/My\\040SD rw - ext4 /dev/mmcblk0p1 rw"
	check(Locations.parse_sd_mounts(mounts) == PackedStringArray(["/run/media/deck/My SD"]), "SD discovery decodes spaces, ignores internal/USB drives and removes duplicates")
	check(Locations.parse_sd_mounts("bad line\n").is_empty(), "Missing or malformed mount data is handled safely")
	var existed := FileAccess.file_exists("user://recent.cfg")
	var backup := FileAccess.get_file_as_bytes("user://recent.cfg") if existed else PackedByteArray()
	var fixture := ProjectSettings.globalize_path("user://rom-browser-fixtures")
	var folder_a := fixture.path_join("My SD/SNES Games")
	var folder_b := fixture.path_join("Other Games")
	DirAccess.make_dir_recursive_absolute(folder_a.path_join("Subfolder"))
	DirAccess.make_dir_recursive_absolute(folder_b)
	var file := FileAccess.open(folder_a.path_join("example.sfc"),FileAccess.WRITE)
	file.store_string("fixture only, never executed")
	file.close()
	file = FileAccess.open(folder_a.path_join("ignore.txt"),FileAccess.WRITE)
	file.store_string("not a ROM")
	file.close()
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	app.default_rom_dir = ""
	app.last_game_path = folder_b.path_join("recent.sfc")
	app.set_stereo(true)
	app.choose_rom()
	await settle()
	var browser = app.rom_dialog
	check(browser.show_folder(folder_a) and browser.entries.item_count == 2, "ROM browser lists folders and SNES files, filtering unrelated files")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	var config := ConfigFile.new()
	config.load("user://recent.cfg")
	check(app.default_rom_dir == folder_a and config.get_value("library","default_rom_dir","") == folder_a, "R1 sets and immediately persists the current default folder")
	check(app.stereo and browser.visible, "Setting a default keeps SBS and browser open")
	check(browser.get_rect().end.x <= 960 and browser.get_rect().end.y <= 720, "Expanded ROM browser fits in the shared eye menu")
	var cards := Locations.sd_cards()
	if "--require-sd" in OS.get_cmdline_user_args():
		check(not cards.is_empty(), "Live mounted SD card is detected by the application")
	await press(JOY_BUTTON_X)
	check(browser.message.text.begins_with("SD card not mounted") if cards.is_empty() else browser.current_dir in cards,
		"X opens the mounted SD card or reports that it is unavailable")
	browser.show_folder(folder_b)
	await press(JOY_BUTTON_Y)
	check(browser.current_dir == folder_a, "Y jumps directly to the saved default folder")
	browser.show_folder(folder_b)
	browser.find_child("DefaultFolder",true,false).grab_focus()
	await press(JOY_BUTTON_A)
	check(browser.current_dir == folder_a, "Controller A activates browser navigation buttons")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(browser.current_dir == folder_a.get_base_dir(), "L1 navigates up one folder")
	app.last_game_path = folder_b.path_join("new-recent.sfc")
	app.save_library()
	config.load("user://recent.cfg")
	check(config.get_value("library","default_rom_dir","") == folder_a, "Recording another recent game preserves the default folder")
	await press(JOY_BUTTON_B)
	app.choose_rom()
	await settle()
	check(browser.current_dir == folder_a, "Reopening the browser prefers the default over the last game folder")
	browser.default_dir = fixture.path_join("removed-card/SNES")
	browser.popup_centered(Vector2i.ZERO)
	await settle()
	check(browser.default_dir.ends_with("removed-card/SNES") and browser.message.text.begins_with("Default folder unavailable"), "Missing card reports the problem without erasing the saved default")
	browser.show_folder(folder_b)
	var before: String = browser.current_dir
	check(not browser.show_folder(fixture.path_join("missing")) and browser.current_dir == before and browser.location.text == before, "Unavailable navigation leaves the actual folder and breadcrumb consistent")
	browser.default_dir = app.default_rom_dir
	browser.find_child("ClearDefault",true,false).pressed.emit()
	config.load("user://recent.cfg")
	check(app.default_rom_dir.is_empty() and config.get_value("library","default_rom_dir","wrong") == "", "Clear default persists without touching files")
	browser.show_folder(folder_a)
	browser.set_current_as_default()
	browser.show_folder(folder_b)
	for code in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_START]:
		var event := InputEventJoypadButton.new()
		event.device = 7
		event.button_index = code
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await settle()
	check(app.default_rom_dir == folder_a and not browser.visible, "Menu chord closes browser without accidentally changing the default")
	for code in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_START]:
		var event := InputEventJoypadButton.new()
		event.device = 7
		event.button_index = code
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	app.distance_save_delay = -1
	app.free()
	var restored = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	check(restored.default_rom_dir == folder_a, "Default ROM folder survives an application restart")
	restored.distance_save_delay = -1
	restored.free()
	if existed:
		file = FileAccess.open("user://recent.cfg",FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://recent.cfg"))
	quit(1 if failures else 0)
