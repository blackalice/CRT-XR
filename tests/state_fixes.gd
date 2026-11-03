extends SceneTree
## Lifecycle fixes: a rename never inherits an earlier rename's target, and a
## game that fails to load after the previous one stopped leaves nothing loaded.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(6): await process_frame
	await rename_checks(app)
	await failed_load_checks(app)
	print("STATE FIX CHECKS COMPLETE: %d failures" % failures)
	quit(1 if failures > 0 else 0)

func rename_checks(app) -> void:
	var rooms = app.rooms
	var menu = app.menu
	if not app.settings_panel.visible: app.toggle_settings()
	check(rooms.save(0) == OK, "A room is saved to rename")
	var room_name: String = rooms.name(0)
	menu.pictures.save_my_preset(0)
	check(menu.pictures.my_preset_saved(0), "A picture preset is saved to rename")
	# Start renaming the room, then back out without saving.
	menu.open_my_room(0)
	menu.select("room_mine.rename", false); menu.activate()
	await process_frame
	check(menu.mode == "rename" and menu.heading.text == "Name your room", "Rename opens for the room")
	menu.back()
	check(menu.mode == "my_room", "Back from the room rename returns to the room")
	# Now rename the picture preset: it must not turn into a room rename.
	menu.pictures.open_my_preset(0)
	menu.select("mine.rename", false); menu.activate()
	await process_frame
	check(menu.mode == "rename" and menu.heading.text == "Name your preset", "Rename after a cancelled room rename is for the preset (%s)" % menu.heading.text)
	menu.rename_field.text = "Preset after cancel"
	menu.select("rename.save", false); menu.activate()
	await process_frame
	check(menu.pictures.my_preset_name(0) == "Preset after cancel", "The preset gets the new name")
	check(rooms.name(0) == room_name, "The room keeps its name")
	rooms.delete(0)
	menu.pictures.delete_my_preset(0)

func failed_load_checks(app) -> void:
	var session = app.emulator
	var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
	check(session.load_rom(rom) and session.loaded, "The diagnostic ROM loads")
	# A ZIP whose cartridge is empty is identified while the old game runs, but
	# cannot be unpacked once it has stopped.
	var broken := ProjectSettings.globalize_path("user://state-fixes-broken.zip")
	var packer := ZIPPacker.new()
	packer.open(broken)
	packer.start_file("broken.sfc")
	packer.close_file()
	packer.close()
	check(session.Registry.identify(broken) == "snes", "The broken ZIP passes the checks made before the old game stops")
	var opened: bool = session.load_rom(broken)
	check(not opened, "A broken cartridge is refused")
	check(not session.loaded and session.core == null, "A failed load leaves no core holding a half-loaded game")
	check(session.rom_path.is_empty() and session.rom_hash.is_empty() and session.content_path.is_empty(), "A failed load forgets the previous game")
	check(session.load_rom(rom) and session.loaded, "A game loads normally after a failed load")
	# A failed core is not a user pause: it stays stopped and is not saved as a resume point.
	session.auto_saved = false
	session.fail_core()
	session.set_paused(false)
	check(session.paused, "A failed core cannot be unpaused")
	check(session.save_auto() and not session.auto_saved, "A failed core is not auto-saved")
	session.stop()
	DirAccess.remove_absolute(broken)
