extends SceneTree
const Options = preload("res://scripts/emulation/core_options.gd")
const Registry = preload("res://scripts/emulation/core_registry.gd")
var failures := 0
func check(ok: bool, label: String):
 print("PASS: " if ok else "FAIL: ", label)
 if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var app = load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 var rom := ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc")
 var hash := Registry.content_hash(rom)
 Options.write_value("snes", "", "snes9x_region", "pal")
 Options.write_value("snes", hash, "snes9x_region", "ntsc")
 check(app.emulator.load_rom(rom) and app.emulator.fps > 59, "Per-game option wins at core startup")
 app.emulator.set_paused(true)
 var catalog = app.menu.catalog
 var pages: Array = catalog.pages(10)
 check(pages.map(func(p): return p.title) == ["Consoles", "This game", "VMU", "Performance", "Info"], "Console settings lead the navigation")
 var headers: Array = pages[0].rows.filter(func(r): return r.has("disclosure"))
 # Experimental consoles (behind their opt-ins) follow the standard ones.
 var listed: int = catalog.CORE_SYSTEMS.size() + catalog.EXPERIMENTAL_SYSTEMS.filter(func(system): return app.emulator.Registry.SYSTEMS.has(system)).size()
 check(headers.size() == listed and headers[0].id == "core.console.snes" and headers[0].value == "Playing", "Playing console is marked and first")
 check(headers[0].expanded, "Playing console opens automatically")
 headers[0].action.call()
 check(catalog.pages(10)[0].rows.size() == listed, "Playing console can stay collapsed")
 var row: Dictionary = pages[1].rows[0]
 check(row.getter.call() == 1 and row.detail_getter.call() == "Game override", "Per-game override has a source label")
 row.setter.call(0)
 pages = catalog.pages(10)
 row = pages[1].rows[0]
 check(row.choices[0] == "PAL" and row.detail_getter.call() == "From console", "Inheritance displays the effective console value")
 check(Options.overrides("snes", hash).get("snes9x_region") == "pal", "Returning to console settings removes the override")
 check(pages[1].rows[0].section.contains("crt-xr-probe") and pages[1].rows[0].section.contains("SNES"), "Game page identifies its game and console")
 Options.write_value("snes", "", "snes9x_region", "")
 Options.write_value("snes", hash, "snes9x_region", "")
 var nes := ProjectSettings.globalize_path("res://build/crt-xr-probe.nes")
 check(app.emulator.load_rom(nes), "NES diagnostic game loads")
 app.emulator.set_paused(true)
 pages = catalog.pages(10)
 check(pages[0].rows[0].id == "core.console.nes" and pages[0].rows[0].expanded, "New console moves to the top and opens")
 catalog.toggle_core_console("snes")
 pages = catalog.pages(10)
 check(not pages[0].rows[0].expanded and catalog.expanded_core_console == "snes", "Other consoles remain accessible while playing")
 app.emulator.stop()
 pages = catalog.pages(10)
 check(pages[0].rows[0].id == "core.console.snes" and pages[1].rows[0].has("disabled_reason"), "Without a game, order and explanatory empty state return")
 for i in range(5): await process_frame
 app.free()
 print("Core options integration: ", failures, " failures")
 quit(1 if failures else 0)
