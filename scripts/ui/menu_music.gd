extends RefCounted
## Music pages: the album browser, the radio address and the player controls.
var host: Node
var menu: Control
var music_dir := ""
var music_page := 0
var music_origin: Dictionary = {}
var panel_hidden := false

func open_music_browser(path := "") -> void:
	if OS.get_name()=="Windows" and not path.is_empty(): path=menu.library.Locations.normalize_windows_path(path)
	if menu.mode!="music_browser": music_origin=menu.snapshot()
	menu.remember(); menu.clear_input()
	if path.is_empty():
		path=music_dir if not music_dir.is_empty() else host.music.last_file.get_base_dir()
		if path.is_empty(): path=OS.get_system_dir(OS.SYSTEM_DIR_MUSIC)
		if DirAccess.open(path)==null: path=menu.library.home_folder()
	if DirAccess.open(path)==null: menu.show_error("Folder unavailable. Reconnect its drive."); return
	music_dir=path; music_page=0; menu.mode="music_browser"; menu.render()

func edit_radio_url() -> void:
	menu.remember(); menu.clear_input(); menu.mode="radio_url"; menu.render()
	menu.rename_field.text=host.music.station_url; menu.keys.focus_entry()

func save_radio_url() -> void:
	var url: String = menu.rename_field.text.strip_edges()
	if not url.is_empty() and host.music.parse_url(url).is_empty():
		menu.show_error("Use a direct http:// or https:// MP3 stream URL."); return
	host.music.station_url=url
	menu.mode="settings"; menu.clear_input(); menu.render(); menu.notify("Radio URL ready. Choose Play radio to listen.")

func music_browser_items() -> Array:
	var result: Array=[]
	var entries: Array=[]
	var album: Array=host.music.album_tracks(music_dir)
	if not album.is_empty():
		result.append(menu.entry(menu.catalog.action("music.album","Play this album",func():
			if host.music.play_album(music_dir): panel_hidden=false; menu.mode="pause"; menu.clear_input(); menu.render()
			else: menu.show_error(host.music.status),"Play this folder in disc/track order, falling back to natural filenames.",false,""),menu.SECTION_HERE,"album","primary","%d tracks in disc and track order" % album.size()))
	result.append_array(menu.up_entry("music.up",music_dir,open_music_browser))
	for name in DirAccess.get_directories_at(music_dir):
		if name.begins_with("."): continue
		var path := music_dir.path_join(name)
		entries.append(menu.entry(menu.catalog.action("music.folder."+path,name,func(): open_music_browser(path),path),menu.SECTION_INSIDE,"folder"))
	for tag in album:
		var path: String=tag.path
		var row: Dictionary=menu.entry(menu.catalog.action("music.track."+path,str(tag.title),func():
			if host.music.play_file(path): panel_hidden=false; menu.mode="pause"; menu.clear_input(); menu.render()
			else: menu.show_error(host.music.status),"Play from this track, then continue through the folder. "+str(tag.album),false,"›"),menu.SECTION_INSIDE,"music")
		if not str(tag.artist).is_empty(): row["layout"]="game"; row["detail"]=str(tag.artist)
		entries.append(row)
	if entries.is_empty():
		entries.append(menu.entry(menu.catalog.unavailable(menu.catalog.action("music.empty","No music in this folder",func(): pass,"",true,""),"Open a folder of MP3 albums, or choose a place under Go to."),menu.SECTION_INSIDE,"music"))
	music_page=clampi(music_page,0,maxi(0,(entries.size()-1)/50))
	if music_page>0: result.append(menu.entry(menu.catalog.action("music.previous","Previous page",func(): music_page-=1; menu.clear_input(); menu.render(),"",false,""),menu.SECTION_INSIDE,"up"))
	result.append_array(entries.slice(music_page*50,(music_page+1)*50))
	if (music_page+1)*50<entries.size(): result.append(menu.entry(menu.catalog.action("music.next","Next page",func(): music_page+=1; menu.clear_input(); menu.render(),"",false,""),menu.SECTION_INSIDE,"page"))
	return result+menu.place_entries("music",open_music_browser,func(): menu.games.enter_folder_path(true),[[OS.get_system_dir(OS.SYSTEM_DIR_MUSIC),"Music folder","music"]])

## The deck's LCD: play state, album track and elapsed time; radio has no time.
func deck_state() -> Dictionary:
	var music=host.music
	var playing: bool=music.player.playing and not music.player.stream_paused
	return {"state":"play" if playing else "pause","track":music.track_index+1 if music.tracks.size()>0 else -1,
		"seconds":int(music.position_seconds()) if music.kind=="local" else -1}

## The deck's two lines: the song and artist, then the album and track.
func deck_text() -> PackedStringArray:
	return host.music.now_playing().split("
")

func show_panel() -> void:
	panel_hidden=false
	menu.refresh()
	# The hidden row disappears on rebuild; restore focus to the first usable
	# control in the deck, rather than falling back to the top of the menu.
	menu.memory[menu.state_key()]["id"]="transport.seek" if host.music.duration()>0 else "transport.play"

func music_actions() -> Array:
	var result: Array=[]
	var music=host.music
	var active: bool = not music.kind.is_empty() and (music.player.stream != null or music.http != null)
	if active and panel_hidden:
		var show: Dictionary = menu.catalog.action("transport.show", "Show music panel", show_panel, "Show the music controls without changing playback.")
		show["row_icon"]="music"
		return [show]
	if active:
		for item in [menu.catalog.action("transport.previous","Previous",func(): music.skip(-1); menu.refresh(),"",not music.can_skip(-1),""),
			menu.catalog.action("transport.play",music.playback_caption(),func(): music.toggle_playback(); menu.refresh(),"Pause/resume local music; reconnect live radio.",false,""),
			menu.catalog.action("transport.next","Next",func(): music.skip(1); menu.refresh(),"",not music.can_skip(1),""),
			menu.catalog.action("transport.stop","Stop",func(): music.stop(); menu.refresh(),"Stop music. Play restarts the current track.",false,"")]:
			item.layout="transport"
			item["skin"]="music"
			item.icon=item.id.get_slice(".",1)
			if item.id=="transport.play":
				item.icon="pause" if music.player.playing and not music.player.stream_paused else "play"
				item.lead=true
			result.append(item)
		var hide: Dictionary = menu.catalog.action("transport.hide", "Hide panel", func(): panel_hidden=true; menu.refresh(), "Hide the music panel while playback continues.", false, "")
		hide.merge({"layout":"transport", "skin":"music", "icon":"hide"})
		result.append(hide)
		if music.duration()>0:
			result.push_front({"id":"transport.seek","label":"Track position","kind":"seek","layout":"music_seek","skin":"music","getter":music.position_seconds,"setter":music.seek,"duration":music.duration,"progress":music.progress_text,"help":"Left/right seeks by 10 seconds. Drag or click the timeline to jump through a long mix."})
	if not music.kind.is_empty() and result.is_empty():
		var resume_music: Dictionary=menu.catalog.action("transport.play","Resume music",func(): music.toggle_playback(); menu.refresh(),music.now_playing(),false,"")
		resume_music["row_icon"]="play"
		result.append(resume_music)
	var browse: Dictionary = menu.catalog.action("transport.choose","Music · Browse albums",open_music_browser,"Choose an album or MP3 from local storage or SD card.")
	browse["row_icon"]="music"
	# Playing, Browse albums is the deck's last key, beside the transport.
	if not result.is_empty() and result[0].get("layout", "") in ["transport", "music_seek"]:
		browse.layout="transport"; browse.icon="music"; browse.caption="Browse albums"; browse["skin"]="music"
	# With music stopped, Resume music and Browse share one row as two tiles.
	elif result.size()==1 and result[0].id=="transport.play":
		var resume: Dictionary=result[0]
		browse.label="Browse albums"
		var pair: Array = [menu.tile(resume,"play","","music",2), menu.tile(browse,"music","","music",2)]
		# Full height, like Choose game and Settings.
		for item in pair: item.compact=false
		return pair
	result.append(browse)
	return result
