extends RefCounted
## Music pages: the album browser, the radio address and the player controls.
const Platform = preload("res://scripts/platform/platform.gd")
var host: Node
var menu: Control
var music_dir := ""
var music_page := 0
var music_origin: Dictionary = {}

func open_music_browser(path := "") -> void:
	if Platform.is_windows() and not path.is_empty(): path=menu.library.Locations.normalize_windows_path(path)
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
			if host.music.play_album(music_dir): menu.mode="pause"; menu.clear_input(); menu.render()
			else: menu.show_error(host.music.status),"Play this folder in disc/track order, falling back to natural filenames.",false,""),menu.SECTION_HERE,"album","primary","%d tracks in disc and track order" % album.size()))
	result.append_array(menu.up_entry("music.up",music_dir,open_music_browser))
	for name in DirAccess.get_directories_at(music_dir):
		if name.begins_with("."): continue
		var path := music_dir.path_join(name)
		entries.append(menu.entry(menu.catalog.action("music.folder."+path,name,func(): open_music_browser(path),path),menu.SECTION_INSIDE,"folder"))
	for tag in album:
		var path: String=tag.path
		var row: Dictionary=menu.entry(menu.catalog.action("music.track."+path,str(tag.title),func():
			if host.music.play_file(path): menu.mode="pause"; menu.clear_input(); menu.render()
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

func music_actions() -> Array:
	var result: Array=[]
	var music=host.music
	if not music.kind.is_empty() and music.player.playing and not music.player.stream_paused:
		for item in [menu.catalog.action("transport.previous","Previous",func(): music.skip(-1); menu.refresh(),"Previous album track.",not music.can_skip(-1),""),
			menu.catalog.action("transport.play",music.playback_caption(),func(): music.toggle_playback(); menu.refresh(),"Pause/resume local music; reconnect live radio.",false,""),
			menu.catalog.action("transport.next","Next",func(): music.skip(1); menu.refresh(),"Next album track.",not music.can_skip(1),""),
			menu.catalog.action("transport.stop","Stop",func(): music.stop(); menu.refresh(),"Stop music. Play restarts the current track.",false,"")]:
			item.layout="transport"
			item.icon=item.id.get_slice(".",1)
			if item.id=="transport.play": item.icon="pause" if music.player.playing and not music.player.stream_paused else "play"
			result.append(item)
		if music.duration()>0:
			result.push_front({"id":"transport.seek","label":"Track position","kind":"seek","layout":"music_seek","getter":music.position_seconds,"setter":music.seek,"duration":music.duration,"progress":music.progress_text,"help":"Left/right seeks by 10 seconds. Drag or click the timeline to jump through a long mix."})
	if not music.kind.is_empty() and (not music.player.playing or music.player.stream_paused):
		var resume_music: Dictionary=menu.catalog.action("transport.play","Resume music",func(): music.toggle_playback(); menu.refresh(),music.now_playing(),false,"")
		resume_music["row_icon"]="play"
		result.append(resume_music)
	var browse: Dictionary = menu.catalog.action("transport.choose","Music · Browse albums",open_music_browser,"Choose an album or MP3 from local storage or SD card.")
	browse["row_icon"]="music"
	if not result.is_empty() and music.player.playing and not music.player.stream_paused: browse.layout="music_link"
	result.append(browse)
	return result
