extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
 print("PASS: " if ok else "FAIL: ", message)
 if not ok: failures += 1
func run():
 var app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
 var catalog = app.menu.catalog
 var folder = ProjectSettings.globalize_path("user://bios-test")
 DirAccess.make_dir_recursive_absolute(folder)
 var file = FileAccess.open(folder.path_join("BIOS_CD_E.BIN"), FileAccess.WRITE)
 file.store_8(0); file.close()
 OS.set_environment("CRT_XR_BIOS", folder)
 var bios: String = catalog.emulation_bios_info()
 check(bios.contains("Required · found: bios_CD_E.bin") and bios.contains("matching the disc region"), "Reports detected regional BIOS and explains region matching")
 check(bios.contains("PlayStation") and bios.contains("Optional") and bios.contains("Searched folders") and bios.contains(folder), "Explains optional BIOS and search paths")
 check(catalog.emulation_game_info().contains("No game loaded"), "No game message")
 app.emulator.loaded = true; app.emulator.system_id = "snes"; app.emulator.rom_path = "test.sfc"; app.emulator.core_identity = "Test core 1"; app.emulator.fps = 50.0
 var game: String = catalog.emulation_game_info()
 check(game.contains("test.sfc") and game.contains("SNES") and game.contains("Test core 1") and game.contains("50.00 fps"), "Reports loaded game details")
 for system in ["psx", "n64"]:
  app.emulator.system_id = system
  var row: Dictionary = catalog.pages(10)[0].rows[0]
  check(row.disabled and row.disabled_reason.contains("unavailable"), "Input preview explains unsupported " + system)
 app.emulator.loaded = false
 app.menu.open_settings(); app.menu.category = 10; app.menu.subsection = 1; app.menu.render()
 check(app.menu.items.any(func(item): return item.id == "emulation.bios_info") and app.menu.items.any(func(item): return item.id == "emulation.game_info"), "Information actions are reachable under Emulation")
 app.queue_free(); quit(1 if failures else 0)
