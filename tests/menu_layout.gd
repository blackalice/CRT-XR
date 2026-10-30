extends SceneTree
var app
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	print("PASS: " if ok else "FAIL: ",title)
	if not ok: failures+=1
func settle():
	for i in range(8): await process_frame
func inside(row: Control, child: Control) -> bool:
	return row.get_global_rect().grow(.5).encloses(child.get_global_rect())
func capture(title: String):
	if DisplayServer.get_name()=="headless": return
	await settle(); RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://build/layout-review")
	app.menu_view.get_texture().get_image().save_png("res://build/layout-review/"+title+".png")
func page(cat: int, section := 0):
	app.menu.mode="settings"; app.menu.category=cat; app.menu.subsection=section; app.menu.preview=false; app.menu.render()
func run():
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); app.use_tracking(false)
	await settle()
	var m=app.menu
	for large in [false,true]:
		app.menu_large_text=large
		for kind in ["keyboard","controller"]:
			m.set_input_kind(kind)
			page(7); m.select("quick.game_volume",false); await settle()
			var empty_help_rect: Rect2 = m.help_frame.get_rect()
			check(m.help_label.text.is_empty() and m.help_frame.modulate.a==0.0,"Empty help hides its frame: "+kind+str(large))
			m.select("quick.view.distance",false); await settle()
			check(not m.help_label.text.is_empty() and m.help_frame.modulate.a==1.0 and m.help_frame.get_rect()==empty_help_rect,"Help returns without shifting layout: "+kind+str(large))
			var sidebar_width := -1.0
			for cat in range(m.CATEGORIES.size()):
				for section in range(m.catalog.pages(cat).size()):
					page(cat,section); await settle()
					var context := "%d/%d %s large=%s" % [cat,section,kind,large]
					if sidebar_width < 0: sidebar_width = m.sidebar_panel.size.x
					check(is_equal_approx(m.sidebar_panel.size.x, sidebar_width), "Category sidebar width stays fixed: " + context)
					var tabs_ok := true
					for tab in m.section_tabs.get_children():
						tabs_ok=tabs_ok and inside(m.section_bar,tab) and is_equal_approx(tab.position.y,0)
					check(tabs_ok and m.get_rect().end.x<=960 and m.get_rect().end.y<=720,"Section tabs fit a single line: "+context)
					var contents_ok := true
					for row in m.rows:
						contents_ok=contents_ok and inside(row,row.title_label) and inside(row,row.value_label)
						if row.track.visible: contents_ok=contents_ok and inside(row,row.track) and inside(row,row.range_min_label) and inside(row,row.range_max_label)
						if row.unavailable_label.visible: contents_ok=contents_ok and inside(row,row.unavailable_label)
						for arrow in row.adjust_buttons: contents_ok=contents_ok and inside(row,arrow) and arrow.size.y<=36
					check(contents_ok,"Text, sliders and small arrows stay inside their row: "+context)
			page(2); m.select("music.game_volume",false); await settle()
			await capture("audio-"+kind+("-large" if large else ""))
			page(1,1); m.select("crt.scanlines",false); await capture("crt-"+kind+("-large" if large else ""))
			m.games.open_library(); m.rom_index.cancel()
			m.rom_index.games={"snes":[{"path":"/fixture/mario.sfc","label":"Super Mario World (Europe) (Rev 1)"},{"path":"/fixture/long.sfc","label":"A deliberately long game title with an extended subtitle (Europe) (En,Fr,De,Es,It) (Revision 12)"}]}
			m.games.open_system("snes"); m.select("game:/fixture/mario.sfc",false); await settle()
			var game=m.selected_row()
			check(game.title_label.get_line_count()==1 and inside(game,game.title_label) and inside(game,game.detail_label),"Normal game title and system caption fit: "+kind+str(large))
			var longer=m.rows.filter(func(row):return row.item.id=="game:/fixture/long.sfc")[0]
			check(inside(longer,longer.title_label) and inside(longer,longer.detail_label),"Long title grows its row and contains its caption: "+kind+str(large))
			await capture("games-"+kind+("-large" if large else ""))
			m.rom_index.games.snes=[{"path":"/fixture/very-long.sfc","label":"A complete cartridge title with a very long subtitle ".repeat(5)+"(Europe) (Revision 12)"}]
			m.render(); m.select("game:/fixture/very-long.sfc",false); await settle()
			var full=m.selected_row()
			check(m.subtitle.text=="1 game","Single-game list uses singular count and omits pagination")
			check(inside(full,full.detail_label),"Very long titles keep their caption inside the row")
			var full_title: String=full.item.label
			m.games.game_title_action(); await settle()
			check(m.mode=="help" and m.help_copy==full_title,"Full title is available in a scrollable view")
			await capture("full-title-"+kind+("-large" if large else ""))
			m.back(); await settle()
			check(m.selected_id=="game:/fixture/very-long.sfc","Full title returns to the same cartridge")
	app.free(); await settle()
	print("MENU LAYOUT COMPLETE: ",failures," failures"); quit(1 if failures else 0)
