extends HBoxContainer
## Battery and time for the menu header: in the glasses you cannot see the
## Deck's own status bar. The battery comes from Linux's power-supply class
## (the Deck's BAT1); without one (a desktop, or Windows) only the time shows.
const RowIcon = preload("res://scripts/ui/row_icon.gd")
const MenuSkin = preload("res://scripts/ui/menu_theme.gd")
const POWER := "/sys/class/power_supply"
var host: Node
var icon := RowIcon.new("battery", MenuSkin.MUTED)
var label := Label.new()
var battery_folder := ""

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(30, 22)
	add_child(icon)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", MenuSkin.MUTED)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	if DirAccess.dir_exists_absolute(POWER):
		for supply in DirAccess.get_directories_at(POWER):
			if read(POWER.path_join(supply).path_join("type")) == "Battery":
				battery_folder = POWER.path_join(supply); break
	var timer := Timer.new(); timer.wait_time = 15.0; timer.autostart = true
	timer.timeout.connect(refresh); add_child(timer)
	refresh()

## The first line of a sysfs file. Their reported length (4 KiB) is not their
## content, so reading the whole length fails; reading one line does not.
static func read(file: String) -> String:
	var handle := FileAccess.open(file, FileAccess.READ)
	return handle.get_line().strip_edges() if handle != null else ""

## "21:40", or "9:40 pm" when the room clocks use 12 hours.
func clock() -> String:
	var now := Time.get_time_dict_from_system()
	if host != null and is_instance_valid(host.world) and not host.world.clock_24_hour:
		var hour: int = int(now.hour) % 12
		return "%d:%02d %s" % [12 if hour == 0 else hour, now.minute, "pm" if int(now.hour) >= 12 else "am"]
	return "%02d:%02d" % [now.hour, now.minute]

func refresh() -> void:
	var text := clock()
	icon.visible = not battery_folder.is_empty()
	if icon.visible:
		var level := int(read(battery_folder.path_join("capacity")))
		var charging := read(battery_folder.path_join("status")) in ["Charging", "Full"]
		icon.level = level / 100.0
		icon.charging = charging
		icon.colour = Color("e0907f") if level <= 15 and not charging else MenuSkin.MUTED
		icon.queue_redraw()
		text = "%d%% · %s" % [level, text]
	label.text = text
