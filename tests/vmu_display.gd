extends SceneTree
const Display = preload("res://scripts/rendering/vmu_display.gd")
class FakeCore extends RefCounted:
 var calls := 0
 var pixels := PackedByteArray()
 func vmu_lcd(_index): calls += 1; return pixels
class FakeSession extends Node:
 var loaded := true
 var system_id := "dreamcast"
 var core := FakeCore.new()
var failures := 0
func check(ok: bool, label: String):
 print("PASS: " if ok else "FAIL: ",label)
 if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
 var parent := Node3D.new(); root.add_child(parent)
 var panel := Display.new(); parent.add_child(panel)
 check(not panel.visible,"VMU stays hidden before receiving an LCD")
 var session := FakeSession.new()
 session.core.pixels.resize(48*32); session.core.pixels.fill(255)
 session.core.pixels[31*48] = 0
 panel.tick(0.02,session)
 check(session.core.calls == 0,"LCD polling is capped at 30 Hz")
 panel.tick(0.02,session)
 check(panel.visible and panel.texture.get_size() == Vector2(48,32),"Dreamcast LCD appears as a separate 48 by 32 texture")
 var image := panel.texture.get_image()
 check(image.get_pixel(0,0).r < 0.2 and image.get_pixel(1,0).r > 0.5,"LCD orientation and monochrome colours are correct")
 var updates: int = panel.texture_updates
 panel.tick(0.04,session)
 check(panel.texture_updates == updates,"Unchanged LCD pixels do not upload another texture")
 panel.enabled = false; panel.apply_layout()
 var calls: int = session.core.calls
 panel.tick(0.04,session)
 check(not panel.visible and session.core.calls == calls,"Hidden VMU stops polling the core")
 panel.enabled = true; panel.horizontal = 0.4; panel.width = 0.5; panel.apply_layout()
 check(is_equal_approx(panel.position.x,0.4) and is_equal_approx(panel.scale.x,0.5) and panel.get_parent() == parent,"Placement and size apply to the world-anchored panel")
 session.system_id = "snes"; panel.tick(0.04,session)
 check(not panel.visible and panel.last_pixels.is_empty(),"Leaving Dreamcast clears the previous LCD")
 session.free(); parent.free()
 var app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
 await process_frame
 app.vmu_display.enabled = false; app.vmu_display.width = 0.44
 var config: ConfigFile = app.capture_settings()
 app.vmu_display.enabled = true; app.vmu_display.width = 0.3
 app.apply_settings(config)
 check(not app.vmu_display.enabled and is_equal_approx(app.vmu_display.width,0.44),"VMU preferences survive settings capture and restore")
 var pages: Array = app.menu.catalog.pages(10)
 check(pages[2].title == "VMU" and pages[2].rows.size() == 5,"VMU controls use the existing settings page and row types")
 for i in range(4): await process_frame
 app.free()
 print("VMU display checks: ",failures," failures")
 quit(0 if failures == 0 else 1)
