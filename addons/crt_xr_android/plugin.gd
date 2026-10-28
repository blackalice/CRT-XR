@tool
extends EditorPlugin
## Editor-only. Registers the Android export step; the game itself never loads it.

var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = preload("res://addons/crt_xr_android/export_plugin.gd").new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
