extends RefCounted
## Video pages: the video folder and its picker, search, continue watching,
## the pause menu while watching, and setting up FFmpeg on Windows.
const VideoSession = preload("res://scripts/video/video_session.gd")
const VideoLibrary = preload("res://scripts/video/video_library.gd")
const FfmpegInstaller = preload("res://scripts/video/ffmpeg_installer.gd")
var host: Node
var menu: Control
const VIDEOS_PER_PAGE := 50
var install_progress := ""
var install_rendered := 0
var video_view_dir := ""
var video_page := 0
var video_launch_path := ""
var video_folder_dir := ""

## Library locations rows for the optional video folder; nothing when FFmpeg is missing.
func video_location_items() -> Array:
	if not VideoSession.available(): return []
	var h=host
	return [menu.catalog.action("library.video_folder","Choose video folder" if h.video_dir.is_empty() else "Change video folder",open_video_folder_picker,
			h.video_dir if not h.video_dir.is_empty() else "Optional. Pick a folder of MP4 or MKV files to watch on the TV; they appear after your consoles."),
		menu.catalog.unavailable(menu.catalog.action("library.video_clear","Remove video folder",func(): set_video_folder(""),"Hides Videos from the library. Your files are not changed.",h.video_dir.is_empty()),"No video folder is set.")]

## Windows has no system FFmpeg: offer to fetch just the libraries video needs.
## Elsewhere, say what to install.
func video_setup_items(section: String) -> Array:
	var installer: Node = host.ffmpeg_installer
	if OS.get_name() != "Windows" or installer == null:
		return [menu.entry(menu.catalog.unavailable(menu.catalog.action("library.ffmpeg_missing","Video playback needs FFmpeg",func(): pass,
			"CRT XR plays videos with the system's FFmpeg 7.1 or 8. SteamOS includes it; on other systems install it with the package manager.",true),
			"Install FFmpeg 7.1 or 8 to watch videos."),section,"video")]
	if installer.busy:
		return [menu.entry(menu.catalog.unavailable(menu.catalog.action("library.ffmpeg_setup","Setting up video playback…",func(): pass,"Downloading FFmpeg's video libraries.",true),install_progress),section,"video","","",false)]
	return [menu.entry(menu.catalog.action("library.ffmpeg_setup","Set up video playback",func():
		menu.ask("Download the video libraries?","CRT XR fetches FFmpeg's five video libraries (LGPL, "+FfmpegInstaller.size_note()+") from github.com/BtbN/FFmpeg-Builds and keeps them in its own folder. Only these files come down, each one checked; nothing else on this computer changes.",start_ffmpeg_install),
		"Windows has no built-in FFmpeg. One download ("+FfmpegInstaller.size_note()+") lets you watch MP4 and MKV files on the TV.",false,"›"),
		section,"video","primary","Downloads FFmpeg's video libraries, "+FfmpegInstaller.size_note())]

func start_ffmpeg_install() -> void:
	var installer: Node = host.ffmpeg_installer
	if not installer.progress.is_connected(show_install_progress): installer.progress.connect(show_install_progress)
	if not installer.finished.is_connected(install_finished): installer.finished.connect(install_finished)
	install_progress = "Starting…"
	menu.mode = "library_tools"
	installer.install()
	menu.render()

func show_install_progress(done: int, total: int, label: String) -> void:
	install_progress = ("%.1f of %.1f MB · %s" % [done / 1048576.0, total / 1048576.0, label]) if total > 0 else label
	# A few redraws a second are plenty for a progress line.
	if menu.mode == "library_tools" and menu.visible and Time.get_ticks_msec() - install_rendered > 250:
		install_rendered = Time.get_ticks_msec()
		menu.remember(); menu.render()

func install_finished(ok: bool, message: String) -> void:
	if menu.mode == "library_tools" and menu.visible: menu.remember(); menu.render()
	if ok: menu.notify(message + ". Choose a video folder to start.")
	else: menu.show_error(message)

## One video as a list row: its length, where you stopped and its thumbnail.
func video_row(path: String, label: String, section: String, place := "") -> Dictionary:
	var length: float=host.video_library.duration(path)
	var resume: float=host.video_library.position(path)
	var parts: Array[String]=[]
	if length>0.0: parts.append(VideoLibrary.clock(length))
	if resume>0.0: parts.append("Resume at "+VideoLibrary.clock(resume))
	if not place.is_empty(): parts.append(place)
	var row: Dictionary=menu.entry(menu.catalog.action("video:"+path,label,func(): select_video(path),"Play on the TV. A pauses, the D-pad seeks, Y changes the picture shape.",false,"›"),section,"video")
	row["layout"]="game"; row["detail"]=" · ".join(parts)
	row["thumbnail_path"]=path; row["thumbnail"]=host.video_library.thumbnail(path)
	return row

## Where a video sits under the video folder, for search and continue rows.
func video_place(path: String) -> String:
	var folder := path.get_base_dir()
	return "" if folder==host.video_dir else folder.trim_prefix(host.video_dir+"/")

func video_items() -> Array:
	if not host.video_library.thumbnail_ready.is_connected(menu.thumbnail_arrived): host.video_library.thumbnail_ready.connect(menu.thumbnail_arrived)
	var result: Array=[]
	if not menu.search_query.is_empty():
		result.append(menu.entry(menu.catalog.action("videos.clear_search","Clear search",func(): menu.search_query=""; menu.search_field.text=""; menu.clear_input(); menu.render(),"Back to your videos.",false,""),"SEARCH","clear","","",true))
		var found: Array=host.video_library.search(host.video_dir,menu.search_query)
		var section := "RESULTS FOR “%s”" % menu.search_query
		for item in found: result.append(video_row(item.path,item.label,section,video_place(item.path)))
		if found.is_empty(): result.append(menu.entry(menu.catalog.unavailable(menu.catalog.action("videos.none","No videos match",func(): pass,"",true),"Try fewer letters, or clear the search."),section))
		return result
	if video_view_dir==host.video_dir:
		for resume in host.video_library.continue_watching(5):
			var path: String=resume.path
			var seconds: float=resume.position
			var row: Dictionary=video_row(path,path.get_file().get_basename(),"CONTINUE WATCHING",video_place(path))
			row["id"]="video.continue:"+path
			row["action"]=func(): play_video(path,seconds)
			row["help"]="Carry on from "+VideoLibrary.clock(seconds)+"."
			result.append(row)
		if menu.input_kind!="keyboard": result.append(menu.entry(menu.catalog.action("videos.search","Search videos…",open_video_search,"Find a video anywhere in your video folder. With a keyboard, Ctrl+F searches as you type.",false,""),"FIND","search","","",true))
	if video_view_dir!=host.video_dir: result.append_array(menu.up_entry("videos.up",video_view_dir,open_videos))
	var entries: Array=host.video_library.list(video_view_dir)
	video_page=clampi(video_page,0,maxi(0,(entries.size()-1)/VIDEOS_PER_PAGE))
	if video_page>0: result.append(menu.entry(menu.catalog.action("videos.previous","Previous page",func(): video_page-=1; menu.clear_input(); menu.render(),"",false,""),menu.SECTION_INSIDE,"up"))
	for item in entries.slice(video_page*VIDEOS_PER_PAGE,(video_page+1)*VIDEOS_PER_PAGE):
		var path: String=item.path
		if item.folder: result.append(menu.entry(menu.catalog.action("videos.folder:"+path,item.label,func(): open_videos(path),"Open this folder."),menu.SECTION_INSIDE,"folder"))
		else: result.append(video_row(path,item.label,menu.SECTION_INSIDE))
	if (video_page+1)*VIDEOS_PER_PAGE<entries.size(): result.append(menu.entry(menu.catalog.action("videos.next","Next page",func(): video_page+=1; menu.clear_input(); menu.render(),"",false,""),menu.SECTION_INSIDE,"page"))
	if entries.is_empty(): result.append(menu.entry(menu.catalog.unavailable(menu.catalog.action("videos.empty","No MP4 or MKV videos here",func(): pass,"Add videos to this folder, or choose another folder in Library locations.",true),"Add MP4 or MKV files to this folder."),menu.SECTION_INSIDE))
	return result

## Search with the on-screen keys (controller) or a keyboard.
func open_video_search() -> void:
	menu.remember(); menu.clear_input(); menu.mode="video_search"; menu.render()
	menu.rename_field.text=menu.search_query; menu.keys.focus_entry()

func run_video_search() -> void:
	menu.search_query=menu.rename_field.text.strip_edges(); menu.search_field.text=menu.search_query
	video_page=0; menu.mode="videos"; menu.clear_input(); menu.render()

## Videos are opt-in: shown only once a folder is chosen and FFmpeg is present.
func videos_shown() -> bool:
	return not host.video_dir.is_empty() and VideoSession.available()

func videos_card(group: String) -> Dictionary:
	var count: int = host.video_library.count(host.video_dir)
	var label := ("%d+ videos" % count) if count>=VideoLibrary.COUNT_LIMIT else "%d video%s" % [count,"" if count==1 else "s"]
	return menu.card(menu.catalog.action("library.videos","Videos",func(): open_videos(),"Your MP4 and MKV files from "+host.video_dir+", shown on the TV.",false,label),"YOUR VIDEOS","videos",Color("d6a35c"),group)

func continue_card(count: int, group: String) -> Dictionary:
	return menu.card(menu.catalog.action("library.continue","Continue watching",func(): open_videos(),"Pick up a video where you left off.",false,menu.count_caption(count,"video")),"PICK UP & WATCH","videos",Color("d6a35c"),group)

func open_videos(path := "") -> void:
	if path.is_empty(): path=host.video_dir
	menu.search_query=""; menu.search_field.text=""
	if DirAccess.open(path)==null:
		menu.show_error("Video folder unavailable. Reconnect its drive or SD card, or choose another folder in Library locations."); return
	menu.remember(); menu.clear_input(); menu.error_label.hide()
	if path!=video_view_dir: video_page=0
	video_view_dir=path; menu.mode="videos"; menu.render()

func select_video(path: String) -> void:
	if not FileAccess.file_exists(path): menu.show_error("Video unavailable. Reconnect its drive or SD card and try again."); return
	if host.video_library.position(path)>0.0:
		menu.remember(); video_launch_path=path; menu.clear_input(); menu.mode="video_launch"; menu.render()
	else: play_video(path,0.0)

func play_video(path: String, from_seconds: float) -> void:
	if not host.play_video(path,from_seconds): menu.show_error(host.startup_message); return
	host.was_paused_before_menu=false
	host.close_settings()

## The deck's LCD: paused or playing, and the elapsed time.
func deck_state() -> Dictionary:
	return {"state":"pause" if host.video.paused else "play","track":-1,"seconds":int(host.video.clock)}

## The deck's two lines: the video, then its format and length.
func deck_text() -> PackedStringArray:
	var video=host.video
	return PackedStringArray([video.path.get_file().get_basename(),
		"%s · %s" % [str(video.info.get("codec","")).to_upper(),VideoLibrary.clock(float(video.info.get("duration",0.0)))]])

func video_pause_items() -> Array:
	var h=host
	var video=h.video
	var length := float(video.info.get("duration",0.0))
	var tracks: PackedStringArray=video.track_names()
	var style_row := {"id":"video.style","label":"Picture shape","kind":"choice","choices":VideoSession.STYLES,"default":h.video_style,
		"getter":func(): return video.style,"setter":func(value):
			video.style=int(value); video.decoder.set_style(video.style); h.remember_video_position(),
		"help":"How a widescreen video fills the 4:3 tube. Y changes it while watching; each video remembers its own."}
	var resume: Dictionary=menu.catalog.action("resume","Resume",h.close_settings,"A pauses and plays while watching. %s · decoding: %s" % [str(video.info.get("codec","")).to_upper(),video.decoding()],false,"▶")
	resume.merge({"layout":"transport","icon":"play","caption":"Resume","lead":true})
	var timeline := {"id":"video.seek","label":"Position","kind":"seek","layout":"video_seek","getter":func(): return video.clock,"setter":func(value): video.seek_to(float(value)),
		"duration":func(): return length,"progress":func(): return VideoLibrary.clock(video.clock)+" / "+VideoLibrary.clock(length),
		"help":"Left/right moves 10 seconds and repeats while held; drag or click the timeline to jump. The TV follows as you scrub."}
	var tape_row := {"id":"video.tape","label":"Tape look","kind":"choice","choices":VideoSession.TAPES,"default":0,
		"getter":func(): return h.video_tape,"setter":func(value): h.video_tape=int(value); video.set_tape(h.video_tape); h.save_library(),
		"help":"Plays videos as if from a VHS tape, with noise bars when you fast-forward or rewind. Applies to every video; also in Videos → VCR."}
	# The deck: the timeline, then Resume, Start over and Stop as its keys.
	var restart: Dictionary = menu.catalog.action("video.restart","Start over",func(): video.seek_to(0.0); h.was_paused_before_menu=false; h.close_settings(),"")
	restart.merge({"layout":"transport","icon":"refresh","caption":"Start over"})
	var stop: Dictionary = menu.catalog.action("video.stop","Stop video",func(): h.stop_video(); menu.open_pause(),"Saves your place and returns the TV to its test signal.")
	stop.merge({"layout":"transport","icon":"stop","caption":"Stop"})
	for control in [timeline, resume, restart, stop]: control["skin"]="music"
	var items: Array=[timeline,resume,restart,stop,
		style_row,tape_row,menu.room_choice("pause.room")]
	var subtitles: PackedStringArray=video.subtitle_names()
	if not subtitles.is_empty():
		items.append({"id":"video.subtitles","label":"Subtitles","kind":"choice","choices":["Off"]+Array(subtitles),"default":0,
			"getter":func(): return video.subtitle_choice+1,"setter":func(value): h.choose_subtitles(int(value)-1),
			"help":"Shown on the TV like broadcast subtitles. S changes them while watching; each video remembers its choice."})
	if tracks.size()>1:
		items.append({"id":"video.audio","label":"Audio track","kind":"choice","choices":Array(tracks),"default":0,
			"getter":func(): return int(video.info.get("audio_track",0)),"setter":func(value): video.select_audio_track(int(value)),
			"help":"Language or commentary track. X changes it while watching."})
	items.append_array([menu.tile(menu.catalog.action("video.choose","Choose video",func(): open_videos(video.path.get_base_dir() if video.path.get_base_dir().begins_with(h.video_dir) else ""),"Pick another video from your video folder."),"video"),
		menu.tile(menu.catalog.action("games","Game library",menu.games.open_library,"Recent, Favourites, consoles and videos."),"gamepad"),
		menu.tile(menu.catalog.action("quick","Quick settings",func(): menu.category=7; menu.subsection=0; menu.open_settings(),"Everyday picture, placement and volume controls."),"sliders","","actions",3),
		menu.tile(menu.catalog.action("settings","Settings",menu.open_settings,"Adjust the view, picture, room, controls and saved setups."),"gear","","actions",3),
		menu.tile(menu.catalog.action("exit","Exit CRT XR",func(): menu.ask("Exit CRT XR?","Your place in this video and your settings will be saved.",h.request_exit),"Close the application."),"exit","danger","actions",3)])
	return items

## Folder picker for the video folder: folders only, with the videos inside shown as a count.
func open_video_folder_picker(path := "") -> void:
	if path.is_empty():
		for candidate in [host.video_dir,OS.get_system_dir(OS.SYSTEM_DIR_MOVIES),menu.library.home_folder()]:
			if not str(candidate).is_empty() and DirAccess.open(candidate)!=null: path=candidate; break
	if DirAccess.open(path)==null: menu.show_error("Folder unavailable. Reconnect its drive."); return
	menu.remember(); menu.clear_input(); menu.error_label.hide()
	video_folder_dir=path; menu.mode="video_folder"; menu.render()

func video_folder_items() -> Array:
	var here: Array=host.video_library.list(video_folder_dir)
	var videos := here.filter(func(item): return not item.folder).size()
	var result: Array=[menu.entry(menu.catalog.action("video_folder.use","Use this folder for videos",func(): set_video_folder(video_folder_dir),
		"Videos in this folder and its subfolders appear after your consoles.",false,""),menu.SECTION_HERE,"check","primary",
		menu.count_caption(videos,"video")+" here · subfolders included")]
	result.append_array(menu.up_entry("video_folder.up",video_folder_dir,open_video_folder_picker))
	for item in here:
		if not item.folder: continue
		var path: String=item.path
		result.append(menu.entry(menu.catalog.action("video_folder.open:"+path,item.label,func(): open_video_folder_picker(path),path),menu.SECTION_INSIDE,"folder"))
	return result+menu.place_entries("video_folder",open_video_folder_picker,func(): pass,[[OS.get_system_dir(OS.SYSTEM_DIR_MOVIES),"Videos folder","video"]],false)

func set_video_folder(path: String) -> void:
	var previous: String=host.video_dir
	host.video_dir=path
	if host.save_library()!=OK:
		host.video_dir=previous
		menu.show_error("The video folder could not be saved. Check that user storage is writable."); return
	host.video_library.refresh()
	if path.is_empty(): menu.mode="library_tools"; menu.render(); menu.notify("Video folder removed. Your videos are unchanged."); return
	menu.mode="library"; menu.render(); menu.notify("Videos now appear after your consoles.")

## Continue a part-watched video, or start it again.
func launch_items() -> Array:
	var path := video_launch_path
	var seconds: float = host.video_library.position(path)
	return [menu.catalog.action("video_launch.continue","Continue",func(): play_video(path,host.video_library.position(path)),path.get_file().get_basename()+" • from "+VideoLibrary.clock(seconds)),
		menu.catalog.action("video_launch.fresh","Start from the beginning",func(): play_video(path,0.0),"Your saved place is replaced as you watch."),
		menu.catalog.action("video_launch.cancel","Back",menu.back,"Return to your videos.")]
