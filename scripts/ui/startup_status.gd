extends RefCounted
## Derive user-facing states without guessing USB hardware from a render mode.
static func describe(game_loaded: bool, default_folder: String, last_game: String,
		xr_requested: bool, tracking_valid: bool, tracking_status: String,
		sbs: bool, window_size: Vector2i, gaming_mode: bool) -> Dictionary:
	var title := "Ready to play" if game_loaded else "Choose a game"
	var detail := "L1 + R1 + Start opens settings. R3 recentres your view." if game_loaded else "Open a SNES, NES or Sega cartridge, play your last game, or explore the test signal."
	if not game_loaded and not last_game.is_empty() and not FileAccess.file_exists(last_game):
		title = "Last game unavailable"
		detail = "Reconnect its SD card, or choose another game. Your saved location is retained."
	elif not default_folder.is_empty() and not DirAccess.dir_exists_absolute(default_folder):
		detail += "\nYour default ROM folder is unavailable. Reconnect the card or choose another folder."
	if xr_requested and not tracking_valid:
		title = "Tracking unavailable"
		detail = "The view is held steady. Check the glasses' USB connection, then use Retry glasses tracking. You can also use Fixed view.\n" + tracking_status
	elif xr_requested and not sbs:
		title = "Glasses view needs SBS"
		detail = "Use the glasses' SBS button, then switch this app to SBS in View. The glasses launcher guides this step before starting."
	elif sbs and window_size != Vector2i(3840,1080):
		title = "SBS preview" if not xr_requested else "Check SBS resolution"
		detail = "For the glasses, use 3840 × 1080 Full-SBS. " + ("Set the game's resolution to Native in Steam, then relaunch." if gaming_mode else "Use the glasses launcher to prepare the external display.")
	return {"title":title,"detail":detail}
