extends SceneTree
const VideoBar = preload("res://scripts/ui/video_bar.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var bar = VideoBar.new()
 root.add_child(bar)
 bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
 bar.size = Vector2(960, 116)
 bar.flash()
 for i in range(3): await process_frame
 var groups = bar.hints.get_children()
 var fits = bar.hints.position.x + bar.hints.size.x <= (bar.size.x + 780.0) / 2.0 - 10.0
 var glyphs = groups.size() == 6 and groups.all(func(group): return group.get_child(0).get_script() == bar.InputGlyph)
 var spaced = bar.hints.position.y + bar.hints.size.y <= bar.size.y - 12 and bar.hints.columns == 6 and bar.hints.get_theme_constant("v_separation") >= 8 and groups.all(func(group): return group.get_theme_constant("separation") >= 10)
 var normal = bar.hints.visible
 bar.flash("Picture shape: Fill")
 var detail = not bar.hints.visible
 bar.flash()
 var restored = bar.hints.visible
 print("PASS: Overlay glyphs, layout and temporary messages" if glyphs and fits and spaced and normal and detail and restored else "FAIL: Overlay glyphs, layout or temporary messages")
 bar.free()
 quit(0 if glyphs and fits and spaced and normal and detail and restored else 1)
