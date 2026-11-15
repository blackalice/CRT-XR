extends "res://scripts/tracking/xr_linux_tracking.gd"
const VitureSdk = preload("res://scripts/tracking/viture_sdk.gd")
## Local SDK path stays outside the exported resources and version control.
func _init() -> void:
	real = true
	valid = false
	live_status = "VITURE Windows / LIVE 3DoF"
	var base := ProjectSettings.globalize_path("res://build/windows-tracking") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	# Packages keep the helper in tracking/ so it is not mistaken for the app.
	var helper := base.path_join("tracking/crt-xr-windows-tracking.exe")
	if not FileAccess.file_exists(helper): helper = base.path_join("crt-xr-windows-tracking.exe")
	# The SDK is set up in user data (Set up VITURE SDK), or the older sdk folder.
	var sdk: String = VitureSdk.find_dll("" if OS.has_feature("editor") else base)
	if not FileAccess.file_exists(helper):
		status = "Windows tracking helper missing: re-extract the complete CRT XR folder"
		return
	if sdk.is_empty():
		status = "VITURE SDK not set up yet: choose Set up VITURE SDK"
		return
	if VitureSdk.spacewalker_running():
		status = "Close SpaceWalker: it holds the glasses' tracking"
		return
	var error := socket.bind(0, "127.0.0.1")
	if error != OK:
		status = "Tracking socket: " + error_string(error)
		return
	helper_pid = OS.create_process(helper, [str(socket.get_local_port()), str(OS.get_process_id()), sdk])
	status = "Waiting for VITURE glasses" if helper_pid > 0 else "Unable to start Windows tracking"
