extends SceneTree
const UI=preload("res://tests/menu_test_helpers.gd")
const Glyph=preload("res://scripts/ui/glyph_text.gd")
const MenuSkin=preload("res://scripts/ui/menu_theme.gd")
var failures:=0
var copies:=[]
var seen:={}
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func settle():
	for i in range(8):await process_frame
func collect(items: Array,lines: int):
	for item in items:
		var text:String=str(item.get("help",""))
		if text.is_empty():continue
		for controller in [false,true]:
			var key:=str(lines)+str(controller)+text
			if seen.has(key):continue
			seen[key]=true
			var glyph=Glyph.new(text,20);glyph.controller=controller;glyph.theme=MenuSkin.create()
			root.add_child(glyph);glyph.position=Vector2(-2000,-2000);glyph.size=Vector2(824,lines*32)
			copies.append([item.id,lines,glyph,controller])
func run():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.use_tracking(false)
	if is_instance_valid(app.menu.boot):app.menu.boot.finish()
	app.menu_boot_pending=false
	for wide in [false,true]:
		app.set_widescreen(wide);UI.page(app,0,1);await settle()
		var menu=app.menu
		menu.select("view.scene_msaa",false);await settle()
		var info:Rect2=menu.help_frame.get_rect()
		var body:Rect2=menu.body.get_rect()
		menu.select("view.fullscreen",false);await settle()
		check(menu.help_slot.size.y==64 and menu.help_frame.get_rect()==info and menu.body.get_rect()==body,"Settings reserve two lines without selection shifts: wide="+str(wide))
		menu.open_pause();await settle()
		menu.select("pause.display",false);await settle()
		info=menu.help_frame.get_rect();body=menu.body.get_rect()
		menu.select("home.settings",false);await settle()
		check(menu.help_slot.size.y==32 and menu.help_frame.get_rect()==info and menu.body.get_rect()==body,"Home reserves one line without selection shifts: wide="+str(wide))
	for category in range(11):
		for page in app.menu.catalog.pages(category):collect(page.rows,2)
	for system in app.menu.catalog.CORE_SYSTEMS+app.menu.catalog.EXPERIMENTAL_SYSTEMS:
		app.menu.catalog.expanded_core_console=system
		for page in app.menu.catalog.core_option_pages():collect(page.rows,2)
	collect(app.menu.catalog.video_picture_rows(),2);collect(app.menu.catalog.vcr_rows(),2);collect(app.menu.catalog.playback_rows(),2)
	app.display_settings.kind="video";collect(app.menu.catalog.display_rows(),2);app.display_settings.kind="game"
	app.menu.open_pause();collect(app.menu.items,1)
	app.emulator.load_rom(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc"));app.emulator.set_paused(true)
	app.menu.open_pause();collect(app.menu.items,1)
	var sound:=AudioStreamWAV.new();sound.mix_rate=44100;sound.format=AudioStreamWAV.FORMAT_16_BITS
	var data:=PackedByteArray();data.resize(88200);sound.data=data;app.music.kind="local";app.music.player.stream=sound
	collect(app.menu.music.music_actions(),1);collect(app.menu.videos.video_pause_items(),1)
	await settle()
	for copy in copies:
		if copy[2].get_combined_minimum_size().y>copy[1]*32+.1:
			check(false,"Help copy overflows: "+str(copy[0])+" controller="+str(copy[3]))
	check(failures==0,"All "+str(copies.size())+" help copies fit their reserved lines")
	for copy in copies:copy[2].queue_free()
	app.queue_free();await process_frame;quit(1 if failures else 0)
