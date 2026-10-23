extends "res://scripts/tracking/xr_linux_tracking.gd"
## Local SDK path stays outside the exported resources and version control.
func _init() -> void:
	real = true
	valid = false
	live_status = "VITURE Windows / LIVE 3DoF"
	var base := ProjectSettings.globalize_path("res://build/windows-tracking") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	# Packages keep the helper in tracking/ so it is not mistaken for the app.
	var helper := base.path_join("tracking/crt-xr-windows-tracking.exe")
	if not FileAccess.file_exists(helper): helper = base.path_join("crt-xr-windows-tracking.exe")
	var sdk := OS.get_environment("CRT_XR_VITURE_SDK")
	if sdk.is_empty():
		sdk = ProjectSettings.globalize_path("res://sdk/x86_64/glasses.dll") if OS.has_feature("editor") else base.path_join("sdk/glasses.dll")
	if not FileAccess.file_exists(helper) or not FileAccess.file_exists(sdk):
		status = "Windows tracking helper or VITURE SDK missing; use fixed view"
		return
	var error := socket.bind(0, "127.0.0.1")
	if error != OK:
		status = "Tracking socket: " + error_string(error)
		return
	helper_pid = OS.create_process(helper, [str(socket.get_local_port()), str(OS.get_process_id()), sdk])
	status = "Waiting for VITURE glasses" if helper_pid > 0 else "Unable to start Windows tracking"
