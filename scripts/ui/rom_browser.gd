extends PanelContainer
## One Control tree is rendered into both eyes; no native or popup windows.
signal file_selected(path: String)
signal canceled

var current_dir := ""
var entries: ItemList
var location: LineEdit

func _ready() -> void:
	position = Vector2(55, 45)
	size = Vector2(850, 630)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("151c29")
	background.set_content_margin_all(16)
	add_theme_stylebox_override("panel", background)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "OPEN SNES GAME   /   D-pad: select   A: open   B: cancel"
	column.add_child(title)
	var navigation := HBoxContainer.new()
	column.add_child(navigation)
	var up := Button.new()
	up.text = "Up a folder"
	up.pressed.connect(func(): show_folder(current_dir.get_base_dir()))
	navigation.add_child(up)
	var home := Button.new()
	home.text = "Home"
	home.pressed.connect(func(): show_folder(home_folder()))
	navigation.add_child(home)
	location = LineEdit.new()
	location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location.text_submitted.connect(show_folder)
	navigation.add_child(location)
	entries = ItemList.new()
	entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries.item_activated.connect(open_entry)
	entries.gui_input.connect(func(event):
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
			var selected := entries.get_selected_items()
			if not selected.is_empty():
				entries.accept_event()
				open_entry(selected[0]))
	column.add_child(entries)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var open := Button.new()
	open.text = "Open selected game / folder"
	open.pressed.connect(func():
		var selected := entries.get_selected_items()
		if not selected.is_empty(): open_entry(selected[0]))
	actions.add_child(open)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): hide(); canceled.emit())
	actions.add_child(cancel)
	hide()

func home_folder() -> String:
	var home := OS.get_environment("HOME") if OS.get_name() == "Linux" else OS.get_environment("USERPROFILE")
	return home if not home.is_empty() else ProjectSettings.globalize_path("res://")

func popup_centered(_unused: Vector2i) -> void:
	show()
	show_folder(current_dir if not current_dir.is_empty() else home_folder())

func show_folder(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		location.text = "Folder unavailable: " + path
		return
	current_dir = directory.get_current_dir()
	location.text = current_dir
	entries.clear()
	var folders := directory.get_directories()
	var files := directory.get_files()
	folders.sort()
	files.sort()
	for folder in folders:
		if not folder.begins_with("."):
			var index := entries.add_item(folder + " /")
			entries.set_item_metadata(index, {"path": current_dir.path_join(folder), "folder": true})
	for file in files:
		if file.get_extension().to_lower() in ["sfc", "smc", "swc", "fig"]:
			var index := entries.add_item(file)
			entries.set_item_metadata(index, {"path": current_dir.path_join(file), "folder": false})
	if entries.item_count > 0: entries.select(0)
	entries.grab_focus.call_deferred()

func open_entry(index: int) -> void:
	var entry: Dictionary = entries.get_item_metadata(index)
	if entry.folder: show_folder(entry.path)
	else:
		hide()
		file_selected.emit(entry.path)
