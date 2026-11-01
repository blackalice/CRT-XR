extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	for i in range(8): await process_frame
	var menu=app.menu
	check(menu.input_kind==("controller" if menu.is_steam_deck() else "keyboard"),"Platform selects the initial glyphs before input")
	if menu.is_steam_deck():
		check(menu.hints.controller and menu.help_label.controller and menu.error_label.controller,"Deck starts with controller footer, help and error glyphs")
	# Exercise Deck pointer policy on desktop test hosts as well.
	menu.deck_controls=true; menu.set_input_kind("controller")
	menu.note_input(InputEventMouseMotion.new())
	var mouse:=InputEventMouseButton.new(); mouse.pressed=true
	menu.note_input(mouse)
	check(menu.input_kind=="controller","Deck trackpad motion and clicks keep controller glyphs")
	var key:=InputEventKey.new(); key.physical_keycode=KEY_DOWN
	menu.note_input(key)
	check(menu.input_kind=="controller","A stray key release does not choose keyboard glyphs")
	key.pressed=true; menu.note_input(key)
	check(menu.input_kind=="keyboard" and not menu.hints.controller,"A keyboard press switches Deck prompts to keys")
	var pad:=InputEventJoypadButton.new(); pad.button_index=JOY_BUTTON_DPAD_UP; pad.pressed=true
	menu.note_input(pad)
	check(menu.input_kind=="controller" and menu.hints.controller,"Controller input switches the prompts back")
	menu.deck_controls=false; menu.note_input(mouse)
	check(menu.input_kind=="keyboard","Desktop mouse use retains keyboard prompts")
	app.free(); print("DECK GLYPHS: ",failures," failures"); quit(1 if failures else 0)
