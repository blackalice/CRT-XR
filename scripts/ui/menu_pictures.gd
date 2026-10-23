extends RefCounted
## Picture presets: the built-in looks, your saved pictures and the hand-tuned
## Custom picture that is kept whenever a preset replaces it.
var host: Node
var menu: Control
const PRESET_IDS := ["showcase","clean","rgb","auto","pal","ntsc"]
const PRESET_NAMES := ["Deck Showcase (PAL)","Clean source","RGB CRT","Auto composite","PAL composite","NTSC composite"]
const MY_PRESET_COUNT := 3
var picture_undo: ConfigFile
var my_preset := 0

func picture_signature() -> String:
	var config := ConfigFile.new()
	host.SettingsStore.copy_sections(host.capture_settings(),config,host.PICTURE_SECTIONS)
	return config.encode_to_text()

func applied_preset() -> String:
	return host.picture_preset_id if not host.picture_preset_signature.is_empty() and host.picture_preset_signature==picture_signature() else ""

func preset_caption() -> String:
	var id := applied_preset()
	if id.is_empty(): return "Custom"
	if id.begins_with("mine."): return "✓ "+my_preset_name(int(id.get_slice(".",1)))
	return "✓ "+PRESET_NAMES[PRESET_IDS.find(id)]

func apply_preset(id: String) -> void:
	remember_custom_picture()
	picture_undo=host.capture_settings()
	host.apply_picture_preset(id)
	host.picture_preset_id=id; host.picture_preset_signature=picture_signature()
	menu.refresh(); menu.notify("Picture preset applied · Undo available on Picture → Presets")

func undo_picture_preset() -> void:
	if picture_undo==null: return
	var merged: ConfigFile=host.capture_settings()
	host.SettingsStore.copy_sections(picture_undo,merged,host.PICTURE_SECTIONS)
	merged.set_value("menu","picture_preset_id",picture_undo.get_value("menu","picture_preset_id",""))
	merged.set_value("menu","picture_preset_signature",picture_undo.get_value("menu","picture_preset_signature",""))
	host.apply_settings(merged); picture_undo=null
	menu.refresh(); menu.notify("Previous picture restored")

## Choosing any preset first keeps a hand-tuned ("Custom") picture on disk, so
## Custom in Quick settings or Picture → Presets can always bring it back.
func custom_picture_path() -> String:
	return "user://presets/picture-custom.cfg"

func my_preset_path(index: int) -> String:
	return "user://presets/picture-%d.cfg" % index

func my_preset_saved(index: int) -> bool:
	return FileAccess.file_exists(my_preset_path(index)) or FileAccess.file_exists(my_preset_path(index)+".bak")

func my_preset_name(index: int) -> String:
	var fallback := "My preset %d" % (index+1)
	if not my_preset_saved(index): return fallback
	return str(host.SettingsStore.new().read(my_preset_path(index)).get_value("meta","name",fallback))

func has_custom_picture() -> bool:
	return FileAccess.file_exists(custom_picture_path()) or FileAccess.file_exists(custom_picture_path()+".bak")

func picture_only() -> ConfigFile:
	var config := ConfigFile.new()
	host.SettingsStore.copy_sections(host.capture_settings(),config,host.PICTURE_SECTIONS)
	return config

func remember_custom_picture() -> void:
	if not applied_preset().is_empty(): return
	if host.SettingsStore.write(custom_picture_path(),picture_only())!=OK:
		menu.show_error("Your custom picture could not be kept. Check free space and user-folder permissions.")

func apply_saved_picture(saved: ConfigFile, id: String) -> void:
	picture_undo=host.capture_settings()
	var merged: ConfigFile=host.capture_settings()
	host.SettingsStore.copy_sections(saved,merged,host.PICTURE_SECTIONS)
	# Like the built-in presets, saved pictures keep this game's screen fitting.
	for field in host.world.picture.FIT_FIELDS: merged.set_value("picture",field[0],host.world.picture.values[field[0]])
	merged.set_value("picture","keep_aspect",host.world.picture.keep_aspect)
	# Validate user-editable files against live types before applying them.
	var validator := ConfigFile.new(); validator.parse(merged.encode_to_text())
	host.apply_settings(host.validated_settings(validator,host.capture_settings()))
	host.picture_preset_id=id
	host.picture_preset_signature=picture_signature() if not id.is_empty() else ""
	host.rebuild_settings()

func restore_custom_picture() -> void:
	if not has_custom_picture(): menu.notify("No custom picture yet. Adjust the picture and it is kept here."); return
	if applied_preset().is_empty(): menu.notify("Your custom picture is already in use"); return
	apply_saved_picture(host.SettingsStore.new().read(custom_picture_path()),"")
	menu.refresh(); menu.notify("Your custom picture is back")

func apply_my_preset(index: int) -> void:
	if not my_preset_saved(index): return
	remember_custom_picture()
	apply_saved_picture(host.SettingsStore.new().read(my_preset_path(index)),"mine.%d" % index)
	menu.refresh(); menu.notify(my_preset_name(index)+" applied · Undo available on Picture → Presets")

func save_my_preset(index: int) -> void:
	var title := my_preset_name(index)
	var callback := func():
		var config := picture_only()
		config.set_value("meta","name",title)
		if host.SettingsStore.write(my_preset_path(index),config)!=OK:
			menu.show_error("Preset could not be saved. Check free space and user-folder permissions."); return
		host.picture_preset_id="mine.%d" % index; host.picture_preset_signature=picture_signature()
		menu.refresh(); menu.notify("Saved · "+title)
	if my_preset_saved(index): menu.ask("Overwrite this preset?","Replace “%s” with the current picture?" % title,callback)
	else: callback.call()

func rename_my_preset(index: int, value: String) -> void:
	var title := value.strip_edges().left(32)
	if title.is_empty(): title="My preset %d" % (index+1)
	var config: ConfigFile=host.SettingsStore.new().read(my_preset_path(index))
	config.set_value("meta","name",title)
	if host.SettingsStore.write(my_preset_path(index),config)!=OK:
		menu.show_error("Preset could not be renamed. Check user-folder permissions."); return
	menu.rename_preset=-1; menu.mode="my_preset"; menu.clear_input(); menu.render(); menu.notify("Renamed · "+title)

func delete_my_preset(index: int) -> void:
	var title := my_preset_name(index)
	menu.ask("Delete this preset?","Remove “%s”? Your current picture does not change." % title,func():
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(my_preset_path(index)+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(my_preset_path(index)+suffix))
		if host.picture_preset_id=="mine.%d" % index: host.picture_preset_id=""; host.picture_preset_signature=""
		menu.refresh(); menu.notify("Deleted · "+title))

func open_my_preset(index: int) -> void:
	menu.remember(); menu.clear_input(); my_preset=index; menu.mode="my_preset"; menu.render()

## One of your saved pictures: apply, save over, rename or delete it.
func items() -> Array:
	var index := my_preset
	var saved := my_preset_saved(index)
	return [menu.catalog.unavailable(menu.catalog.action("mine.apply","Apply this preset",func(): apply_my_preset(index),"Changes CRT, colour and signal settings. This game's screen fit stays as it is.",not saved),"Nothing is saved here yet."),
		menu.catalog.action("mine.save","Save current picture here",func(): save_my_preset(index),"Stores the current CRT, colour and signal settings in this preset."),
		menu.catalog.unavailable(menu.catalog.action("mine.rename","Rename",func(): menu.rename_preset=index; menu.mode="rename"; menu.entry_initialized=false; menu.clear_input(); menu.render(); menu.keys.focus_entry(),"Use the on-screen keys or a physical keyboard.",not saved),"Save a picture here first."),
		menu.catalog.unavailable(menu.catalog.action("mine.delete","Delete",func(): delete_my_preset(index),"Removes this preset. Your current picture does not change.",not saved),"Nothing is saved here yet.")]
