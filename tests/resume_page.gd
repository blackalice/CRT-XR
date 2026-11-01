extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
 print("PASS: " if ok else "FAIL: ",label)
 if not ok: failures += 1
func settle():
 for i in range(8): await process_frame
func run():
 var app = load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
 check(app.emulator.load_rom(rom), "Diagnostic game loads")
 app.emulator.set_paused(true)
 app.emulator.core.run_frame(0)
 app.emulator.update_texture(true)
 app.emulator.auto_saved = false
 check(app.emulator.save_auto(), "Diagnostic resume point is saved")
 app.emulator.stop()
 var m = app.menu
 m.open_pause()
 m.games.select_file(rom)
 await settle()
 check(m.mode == "launch" and m.heading.text == "Welcome back" and m.selected_id == "launch.continue", "Startup offers Continue first")
 check(m.items.map(func(i): return i.label) == ["Continue", "Start from a fresh boot", "Go to Home"], "Actions explain boot and Home destinations")
 check(not m.help_frame.visible and not m.subtitle_row.visible, "Redundant help card and filename subtitle are removed")
 m.input_kind = "controller"; m.refresh_labels()
 check(m.hints.text.contains("B Go to Home"), "Controller back hint names Home")
 m.select("launch.cancel",false); m.activate(); await settle()
 check(m.mode == "pause" and not app.emulator.loaded, "Go to Home does not launch a game")
 m.games.open_library(); m.games.select_file(rom); await settle()
 check(m.items[2].label == "Back to library", "Library return has contextual wording")
 m.back(); await settle()
 check(m.mode == "library", "Back restores library")
 var path: String = app.emulator.auto_path_for(rom)
 var original := FileAccess.get_file_as_bytes(path)
 var state: Dictionary = bytes_to_var(original)
 state.erase("thumbnail")
 app.emulator.write_bytes_atomic(path,var_to_bytes(state))
 m.games.select_file(rom); await settle()
 var panels: Array = m.column.find_children("*","PanelContainer",true,false).filter(func(p): return p.get("thumbnail") != null)
 check(panels.size() == 1 and panels[0].placeholder.visible and not panels[0].thumbnail.visible, "Older saves keep a deliberate preview placeholder")
 check(not m.rows[0].disabled, "A missing screenshot does not block Continue")
 app.emulator.write_bytes_atomic(path,original)
 await settle()
 app.free()
 print("Resume page checks: ",failures," failures")
 quit(1 if failures else 0)
