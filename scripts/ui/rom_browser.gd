extends PanelContainer
## Shared eye menu; no native file dialogs or desktop-mode dependency.
signal file_selected(path: String)
signal canceled
signal default_folder_changed(path: String)
const Locations = preload("res://scripts/content/rom_locations.gd")
var current_dir := ""
var default_dir := ""
var entries: ItemList
var location: LineEdit
var message: Label
var use_default: Button
var default_armed := false
var up_held := false

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
	add_button(navigation, "Up", "Up a folder", func(): show_folder(current_dir.get_base_dir() if not current_dir.is_empty() else home_folder()))
	add_button(navigation, "Home", "Home", func(): show_folder(home_folder()))
	add_button(navigation, "SDCard", "SD card  [X]", open_sd_card)
	add_button(navigation, "DefaultFolder", "Default folder  [Y]", open_default_folder)
	location = LineEdit.new()
	location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location.text_submitted.connect(show_folder)
	column.add_child(location)
	entries = ItemList.new()
	entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries.item_activated.connect(open_entry)
	column.add_child(entries)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	add_button(actions, "Open", "Open selected", open_selected)
	use_default = add_button(actions, "UseAsDefault", "Use this folder as default  [R1]", set_current_as_default)
	add_button(actions, "ClearDefault", "Clear default", func():
		default_dir = ""
		message.text = "Default cleared. Your ROMs are unchanged."
		default_folder_changed.emit(""))
	add_button(actions, "Cancel", "Cancel", func(): hide(); canceled.emit())
	var hint := Label.new()
	hint.text = "L1: up a folder   ·   X: SD card   ·   Y: default folder   ·   R1: set default"
	column.add_child(hint)
	hide()

func add_button(parent: Control, title: String, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = title
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventJoypadButton: return
	# Save on release so L1+R1+Start cannot accidentally change the library folder.
	if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
		if event.pressed: default_armed = not up_held
		else:
			if default_armed: set_current_as_default()
			default_armed = false
		get_viewport().set_input_as_handled()
		return
	if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
		up_held = event.pressed
		default_armed = false
	if not event.pressed: return
	match event.button_index:
		JOY_BUTTON_X: open_sd_card()
		JOY_BUTTON_Y: open_default_folder()
		JOY_BUTTON_LEFT_SHOULDER: show_folder(current_dir.get_base_dir() if not current_dir.is_empty() else home_folder())
		JOY_BUTTON_A:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button: focused.pressed.emit()
			elif focused == entries: open_selected()
			else: return
		_: return
	get_viewport().set_input_as_handled()

func home_folder() -> String:
	var home := OS.get_environment("HOME") if OS.get_name() == "Linux" else OS.get_environment("USERPROFILE")
	return home if not home.is_empty() else ProjectSettings.globalize_path("res://")

func popup_centered(_unused: Vector2i) -> void:
	default_armed = false
	up_held = false
	show()
	if not default_dir.is_empty() and show_folder(default_dir): return
	var missing_default := not default_dir.is_empty()
	if current_dir.is_empty() or not show_folder(current_dir):
		show_folder(home_folder())
	if missing_default: message.text = "Default folder unavailable. Reconnect the SD card, or choose another folder. Saved default: " + default_dir

func show_folder(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		location.text = current_dir
		message.text = "Folder unavailable: " + path
		return false
	current_dir = directory.get_current_dir()
	location.text = current_dir
	use_default.disabled = false
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
	message.text = "Default folder: " + default_dir if not default_dir.is_empty() else "Choose a ROM folder, then use R1 to remember it."
	focus_entries()
	return true

func focus_entries() -> void:
	if entries.item_count > 0: entries.select(0)
	entries.grab_focus.call_deferred()

func open_sd_card() -> void:
	var paths := Locations.sd_cards()
	if paths.is_empty():
		message.text = "SD card not mounted. Insert the card, then try SD card again."
		return
	if paths.size() == 1:
		show_folder(paths[0])
		return
	# Support multiple mounted card partitions without guessing which one to use.
	current_dir = ""
	location.text = "SD card volumes"
	entries.clear()
	use_default.disabled = true
	for path in paths:
		var index := entries.add_item(path)
		entries.set_item_metadata(index, {"path": path, "folder": true})
	message.text = "Select an SD card volume."
	focus_entries()

func open_default_folder() -> void:
	if default_dir.is_empty(): message.text = "No default yet. Open your ROM folder, then press R1."
	else: show_folder(default_dir)

func set_current_as_default() -> void:
	if current_dir.is_empty() or DirAccess.open(current_dir) == null:
		message.text = "Open an available folder before setting a default."
		return
	default_dir = current_dir
	message.text = "Default ROM folder saved: " + default_dir
	default_folder_changed.emit(default_dir)

func open_selected() -> void:
	var selected := entries.get_selected_items()
	if not selected.is_empty(): open_entry(selected[0])

func open_entry(index: int) -> void:
	var entry: Dictionary = entries.get_item_metadata(index)
	if entry.folder: show_folder(entry.path)
	elif not FileAccess.file_exists(entry.path):
		message.text = "Game unavailable. Reconnect the SD card and try again."
	else:
		hide()
		file_selected.emit(entry.path)
