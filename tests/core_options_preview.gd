extends SceneTree
const Options = preload("res://scripts/emulation/core_options.gd")
var app
var failures := 0
func _initialize(): call_deferred("run")
func capture(label: String, section: int, selected := ""):
 app.menu.category = 10
 app.menu.subsection = section
 app.menu.memory.clear()
 app.menu.render()
 if not selected.is_empty(): app.menu.select(selected, false)
 for i in range(15): await process_frame
 RenderingServer.force_draw(false)
 var result: int = app.menu_view.get_texture().get_image().save_png("res://build/core-layout-review/" + label + ".png")
 if result != OK: failures += 1
 print("PREVIEW ",label," result=",result)
func run():
 DirAccess.make_dir_recursive_absolute("res://build/core-layout-review")
 app = load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 for i in range(10): await process_frame
 app.menu.open_settings()
 await capture("no-game",1)
 app.emulator.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe.nes"))
 app.emulator.set_paused(true)
 await capture("playing-nes",0)
 # Move through the real row tree to check keyboard/controller focus in the group.
 var child = app.menu.rows[1]
 app.menu.select(child.item.id, false)
 for i in range(4): await process_frame
 if not child.selected_now: failures += 1
 var width: float = child.size.x
 if width >= app.menu.rows[0].size.x: failures += 1
 app.emulator.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc"))
 app.emulator.set_paused(true)
 var hash: String = app.emulator.rom_hash
 await capture("playing-snes",0)
 Options.write_value("snes",hash,"snes9x_region","pal")
 await capture("game-overrides",1)
 Options.write_value("snes",hash,"snes9x_region","")
 app.menu_large_text = true
 await capture("large-text",1)
 app.menu_large_text = false
 app.menu.category=1; app.menu.subsection=0; app.menu.memory.clear(); app.menu.render()
 for i in range(15): await process_frame
 RenderingServer.force_draw(false)
 app.menu_view.get_texture().get_image().save_png("res://build/core-layout-review/picture-comparison.png")
 app.free()
 print("Preview/layout checks: ",failures," failures")
 quit(1 if failures else 0)

