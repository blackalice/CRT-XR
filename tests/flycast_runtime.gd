extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
 print("PASS: " if ok else "FAIL: ", label)
 if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var core = ClassDB.instantiate("RetroCore")
 core.set_hardware_rendering(true)
 var base := ProjectSettings.globalize_path("res://")
 var extension := "dll" if OS.get_name() == "Windows" else "so"
 check(core.load_core(base + "cores/flycast_libretro." + extension), "Real Flycast core loads")
 core.set_option("reicast_threaded_rendering", "disabled")
 core.set_option("reicast_vblank_pacing", "enabled")
 core.set_option("reicast_internal_resolution", "640x480")
 core.set_option("reicast_hle_bios", "enabled")
 var saves := ProjectSettings.globalize_path("user://flycast-runtime")
 DirAccess.make_dir_recursive_absolute(saves + "/dc")
 for launch in range(2):
  var loaded: bool = core.load_game(base + "build/flycast-probe.elf", saves)
  check(loaded, "Original SH-4 probe boots with HLE, launch %d: %s" % [launch, core.last_error()])
  if not loaded: break
  var ok := true
  for frame in range(12):
   core.set_trigger_pressure(8192, 16384)
   if not core.run_frame(0): ok = false; break
  check(ok, "Real Flycast executes bounded vblank steps: " + str(core.last_error()))
  var state: PackedByteArray = core.save_state()
  check(not state.is_empty() and core.load_state(state), "Real Flycast state round trip")
  core.run_frame(0)
  check(core.save_state() != state, "Emulated machine advances after restoring state")
  check(core.reset(), "Real Flycast reset")
  core.close_game()
 core.close()
 print("Flycast runtime smoke: ", failures, " failures")
 quit(1 if failures else 0)
