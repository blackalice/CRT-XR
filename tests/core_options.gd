extends SceneTree
const Options = preload("res://scripts/emulation/core_options.gd")
func _initialize() -> void:
 var failures := 0
 var system := "snes"
 var key := "snes9x_region"
 var game := "test-core-options-game"
 if Options.write_value(system, "", key, "pal") != OK: failures += 1
 if Options.overrides(system, game).get(key) != "pal": failures += 1
 if Options.write_value(system, game, key, "ntsc") != OK: failures += 1
 if Options.overrides(system, game).get(key) != "ntsc": failures += 1
 if Options.write_value(system, game, key, "invalid") != OK: failures += 1
 if Options.overrides(system, game).get(key) != "pal": failures += 1
 Options.write_value(system, game, key, "")
 Options.write_value(system, "", key, "")
 if Options.overrides(system, game).has(key): failures += 1
 print("Core option inheritance: ", failures, " failures")
 quit(failures)
