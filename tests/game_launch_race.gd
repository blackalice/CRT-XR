extends SceneTree
## Two choices inside the channel animation must never boot the older choice.
const Games = preload("res://scripts/ui/menu_games.gd")
class FakeEmulator extends RefCounted:
	var status := "Expected test rejection"
	func needs_unpacking(_path: String) -> bool: return false
class FakeMenu extends Control:
	func show_error(_message: String) -> void: pass
class FakeHost extends Node:
	var emulator := FakeEmulator.new()
	var was_paused_before_menu := false
	var video_was_paused_before_menu := false
	var loading_path := ""
	var startup_message := "Expected test rejection"
	var stopped: Array[String] = []
	var opened: Array[String] = []
	func shows_loading_card(path: String) -> bool: return path.ends_with(".iso")
	func show_loading(path: String, _progress := 0.0) -> void: loading_path = path
	func end_loading() -> void: loading_path = ""
	func close_settings() -> bool: return true
	func toggle_settings() -> void: pass
	func stop_for_disc(path: String) -> bool: stopped.append(path); return true
	func load_game(path: String) -> bool: opened.append(path); return false
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1
func run() -> void:
	var host := FakeHost.new()
	root.add_child(host)
	var menu := FakeMenu.new()
	host.add_child(menu)
	var games := Games.new()
	games.host = host
	games.menu = menu
	games.launch_game("Old.iso", false)
	await process_frame
	games.launch_game("New.iso", false)
	await create_timer(0.8).timeout
	check(host.opened == ["New.iso"] and host.stopped == ["New.iso"], "Only the latest disc choice stops and loads a game")
	check(host.loading_path == "New.iso", "The loading title stays with the selected game")
	host.opened.clear(); host.stopped.clear()
	games.launch_game("Old.iso", false)
	await process_frame
	games.launch_game("Cartridge.sfc", false)
	await create_timer(0.8).timeout
	check(host.opened == ["Cartridge.sfc"] and host.stopped.is_empty(), "A cartridge choice cancels an older delayed disc launch")
	host.opened.clear(); host.stopped.clear()
	games.launch_game("Cancelled.iso", false)
	await process_frame
	host.end_loading()
	await create_timer(0.8).timeout
	check(host.opened.is_empty() and host.stopped.is_empty(), "Leaving the loading card cancels its delayed game launch")
	print("GAME LAUNCH RACE CHECKS COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
