extends Node
## Music is independent of emulation, including its pause, core and audio queue.
signal status_changed
signal transport_changed
signal playback_error(message: String)
const ResumeStore = preload("res://scripts/ui/settings_store.gd")
var resume_elapsed := 0.0
var resume_warning := false
var restoring := false
const Tags = preload("res://scripts/audio/id3_tags.gd")
const MAX_FILE_BYTES := 256*1024*1024
var tracks: Array[Dictionary] = []
var track_index := -1
var metadata: Dictionary = {}
var kind := ""
var paused_seek := -1.0
var album_folder := ""
const DEFAULTS := {"duck_game":false,"duck_amount":0.5,"volume":0.45,"game_volume":1.0,"reverb":0.12,"directional":0.8,"side":-1.1,"loop":true,"last_file":"","station_url":""}
var duck_game := false
var duck_amount := 0.5
var duck_gain := 1.0
var volume := 0.45
var game_volume := 1.0
var reverb := 0.12
var directional := 0.8
var side := -1.1
var loop := true
var last_file := ""
var station_url := ""
var player := AudioStreamPlayer.new()
var room := AudioEffectReverb.new()
var panner := AudioEffectPanner.new()
var bus_name := ""
var status := "Choose an MP3 or a direct MP3 radio stream"
var source := ""
var game_player: AudioStreamPlayer
var http: HTTPClient
var decoder: RefCounted
var playback: AudioStreamGeneratorPlayback
var connecting := false
var requested := false
var redirects := 0
var request_path := "/"
var idle := 0.0
var audio_idle := 0.0
var icy_interval := 0
var icy_remaining := 0
var metadata_remaining := 0
var streaming := false

func _ready() -> void:
	add_child(player)
	bus_name="CRT XR Music "+str(get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus_name)
	AudioServer.set_bus_send(index,"Master")
	room.dry=1.0; room.room_size=.3; room.damping=.75
	room.predelay_msec=16; room.spread=.65
	AudioServer.add_bus_effect(index,panner)
	AudioServer.add_bus_effect(index,room)
	player.bus=bus_name
	player.finished.connect(track_finished)
	apply()

func apply() -> void:
	volume=clampf(volume,0,1); game_volume=clampf(game_volume,0,1)
	reverb=clampf(reverb,0,.3); directional=clampf(directional,0,1); side=clampf(side,-2,2)
	player.volume_db=linear_to_db(volume) if volume>0 else -80.0
	duck_amount=clampf(duck_amount,0,1)
	apply_game_level()
	room.wet=reverb
	var index := AudioServer.get_bus_index(bus_name)
	if index>0:
		AudioServer.set_bus_effect_enabled(index,0,directional>0)
		AudioServer.set_bus_effect_enabled(index,1,reverb>0)
	if player.stream is AudioStreamMP3: player.stream.loop=false

func apply_game_level() -> void:
	if is_instance_valid(game_player):
		var level := game_volume*duck_gain
		game_player.volume_db=-6.0+(linear_to_db(level) if level>0 else -80.0)

func seek(seconds: float) -> void:
	if kind!="local" or player.stream==null: return
	var target := clampf(seconds,0,maxf(0,player.stream.get_length()-.05))
	if player.stream_paused or not player.playing: paused_seek=target
	else: player.seek(target)
	save_resume(target)

func duration() -> float:
	return player.stream.get_length() if kind=="local" and player.stream!=null else 0.0

func position_seconds() -> float:
	if paused_seek>=0: return paused_seek
	return player.get_playback_position() if player.stream!=null else 0.0

func update_pose(orientation: Quaternion, listener: Vector3, television: Vector3, delta: float) -> void:
	var local := orientation.inverse()*(television+Vector3(side,-.25,.1)-listener)
	var target := local.normalized().x*.65*directional if local.length_squared()>.00001 else 0.0
	panner.pan=lerpf(panner.pan,target,1.0-exp(-maxf(delta,0)/.04))

func set_status(message: String) -> void:
	status=message; status_changed.emit()

func report_error(message: String) -> void:
	set_status(message); playback_error.emit(message)

func stop() -> void:
	if not restoring: save_resume()
	paused_seek=-1.0
	player.stop(); player.stream_paused=false; player.stream=null; playback=null; streaming=false
	if http!=null: http.close()
	http=null; decoder=null; connecting=false; requested=false
	set_status("Stopped")

func album_tracks(folder: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for name in DirAccess.get_files_at(folder):
		if name.get_extension().to_lower()!="mp3": continue
		var path := folder.path_join(name)
		var tag := Tags.read(path)
		tag.path=path; result.append(tag)
	result.sort_custom(func(a,b):
		var ad := maxi(1,int(a.disc)); var bd := maxi(1,int(b.disc))
		if ad!=bd: return ad<bd
		var at := int(a.track) if a.track>0 else 1000000000
		var bt := int(b.track) if b.track>0 else 1000000000
		if at!=bt: return at<bt
		return str(a.path.get_file()).naturalnocasecmp_to(str(b.path.get_file()))<0)
	return result

func play_file(path: String) -> bool:
	var album := album_tracks(path.get_base_dir())
	for i in range(album.size()):
		if album[i].path==path:
			return select_album(album,i,path.get_base_dir())
	report_error("MP3 unavailable. Reconnect its drive or choose another file."); return false

func play_last_file() -> void:
	var config := ResumeStore.new().read("user://music-resume.cfg")
	if config.get_value("resume","kind","")=="local" and config.get_value("resume","path","")==last_file:
		restore_resume()
		if player.stream!=null and kind=="local": toggle_playback()
	else: play_file(last_file)

func play_album(folder: String) -> bool:
	var album := album_tracks(folder)
	if album.is_empty(): report_error("No MP3 tracks in this folder."); return false
	return select_album(album,0,folder)

func select_album(album: Array[Dictionary], index: int, folder: String) -> bool:
	var previous := tracks; var previous_folder := album_folder
	tracks=album; album_folder=folder
	if start_track(index): return true
	tracks=previous; album_folder=previous_folder; return false

func start_track(index: int, ready_only := false, saved_position := 0.0) -> bool:
	if index<0 or index>=tracks.size(): return false
	var path: String=tracks[index].path
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:
		report_error("MP3 unavailable. Reconnect its drive or choose another file."); return false
	if path.get_extension().to_lower()!="mp3" or file.get_length()>MAX_FILE_BYTES:
		report_error("Choose an MP3 no larger than 256 MB."); return false
	# Release the previous compressed track before loading the next; never preload an album.
	stop()
	var audio := AudioStreamMP3.load_from_file(path)
	if audio==null or audio.get_length()<=0:
		report_error("This file could not be decoded as MP3."); return false
	track_index=index; kind="local"; last_file=path; metadata=tracks[index]
	source=str(metadata.title)
	if not str(metadata.artist).is_empty(): source+=" — "+str(metadata.artist)
	audio.loop=false; player.stream=audio
	if ready_only:
		paused_seek=clampf(saved_position,0,maxf(0,audio.get_length()-.05))
		set_status("Ready · "+source)
	else:
		player.play(); set_status("Playing · "+source); save_resume(0)
	transport_changed.emit(); return true

func track_finished() -> void:
	if kind!="local": return
	if track_index+1<tracks.size():
		if not start_track(track_index+1): transport_changed.emit()
	elif loop:
		if not start_track(0): transport_changed.emit()
	else: set_status("Album finished · "+source); transport_changed.emit()

func can_skip(direction: int) -> bool:
	return kind=="local" and tracks.size()>1 and (loop or (track_index+direction>=0 and track_index+direction<tracks.size()))

func skip(direction: int) -> void:
	if not can_skip(direction): return
	start_track(posmod(track_index+direction,tracks.size()))

func toggle_playback() -> void:
	save_resume()
	if kind=="radio":
		if http!=null: stop()
		else: play_station(station_url)
	elif player.stream!=null and kind=="local":
		if player.playing and not player.stream_paused:
			# Godot may report playing=false once a paused voice reaches the mixer.
			# Keep our own cursor rather than treating it as a newly prepared song.
			paused_seek=position_seconds()
			player.stream_paused=true; save_resume(paused_seek)
			set_status("Paused · "+source)
		else:
			var start := maxf(0,paused_seek)
			player.stream_paused=false; player.play(start); paused_seek=-1
			set_status("Playing · "+source)
	elif track_index>=0: start_track(track_index)
	transport_changed.emit()

func playback_caption() -> String:
	if kind=="radio": return "Stop radio" if http!=null else "Play radio"
	return "Pause" if player.playing and not player.stream_paused else "Play"

func now_playing() -> String:
	if kind=="radio": return status
	if metadata.is_empty(): return status
	var detail := str(metadata.album)
	if tracks.size()>0: detail+=" · %d / %d" % [track_index+1,tracks.size()]
	return source+"\n"+detail

func progress_text() -> String:
	if kind!="local" or player.stream==null: return ""
	var elapsed := int(position_seconds())
	var duration := int(player.stream.get_length())
	return "%d:%02d / %d:%02d" % [elapsed/60,elapsed%60,duration/60,duration%60]

func play_station(url: String) -> bool:
	stop(); tracks.clear(); track_index=-1; metadata.clear(); kind="radio"
	station_url=url.strip_edges(); source="Web radio"; redirects=0
	save_resume()
	transport_changed.emit()
	if not ClassDB.class_exists("RadioMP3Decoder"):
		report_error("Radio decoder unavailable in this build."); return false
	decoder=ClassDB.instantiate("RadioMP3Decoder")
	return connect_url(station_url)

static func parse_url(url: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("^(https?)://([^/:?#]+)(?::([0-9]+))?([^#]*)$")
	var found := regex.search(url)
	if found==null: return {}
	var scheme := found.get_string(1)
	var port := int(found.get_string(3)) if not found.get_string(3).is_empty() else (443 if scheme=="https" else 80)
	return {"scheme":scheme,"host":found.get_string(2),"port":port,"path":found.get_string(4)}

func connect_url(url: String) -> bool:
	var parts := parse_url(url)
	if parts.is_empty() or parts.scheme not in ["http","https"] or str(parts.host).is_empty():
		report_error("Enter a direct http:// or https:// MP3 stream URL."); return false
	http=HTTPClient.new(); http.read_chunk_size=16384
	request_path=str(parts.path)
	if request_path.is_empty(): request_path="/"
	var error := http.connect_to_host(str(parts.host),int(parts.port),TLSOptions.client() if parts.scheme=="https" else null)
	if error!=OK: fail("Could not connect to the radio. Check the URL and network."); return false
	connecting=true; requested=false; idle=0; audio_idle=0
	set_status("Connecting to radio…"); return true

func fail(message: String) -> void:
	stop(); report_error(message)

func filter_icy(data: PackedByteArray) -> PackedByteArray:
	if icy_interval==0: return data
	var result := PackedByteArray()
	var offset := 0
	while offset<data.size():
		if metadata_remaining>0:
			var count := mini(metadata_remaining,data.size()-offset)
			metadata_remaining-=count; offset+=count
		elif icy_remaining==0:
			metadata_remaining=int(data[offset])*16; offset+=1; icy_remaining=icy_interval
		else:
			var count := mini(icy_remaining,data.size()-offset)
			result.append_array(data.slice(offset,offset+count)); offset+=count; icy_remaining-=count
	return result

func _process(delta: float) -> void:
	resume_elapsed+=delta
	# Stop, pause, track changes and quitting save immediately; this only bounds
	# what a crash could lose without rewriting the file every few seconds.
	if resume_elapsed>=30:
		resume_elapsed=0; save_resume()
	var audible := player.playing and not player.stream_paused and volume>0.0001
	var target := (1.0-duck_amount) if duck_game and audible else 1.0
	duck_gain=lerpf(duck_gain,target,1.0-exp(-maxf(delta,0)/(.15 if target<duck_gain else .4)))
	apply_game_level()
	if http==null: return
	idle+=delta; audio_idle+=delta
	if audio_idle>15:
		fail("No playable MP3 audio from this station. Check the stream URL."); return
	if idle>15:
		fail("Radio timed out. Check your connection and press Play radio to retry."); return
	http.poll()
	var state := http.get_status()
	if state in [HTTPClient.STATUS_CANT_RESOLVE,HTTPClient.STATUS_CANT_CONNECT,HTTPClient.STATUS_CONNECTION_ERROR,HTTPClient.STATUS_TLS_HANDSHAKE_ERROR,HTTPClient.STATUS_DISCONNECTED]:
		fail("Radio disconnected. Press Play radio to reconnect."); return
	if state==HTTPClient.STATUS_CONNECTED and not requested:
		requested=true
		if http.request(HTTPClient.METHOD_GET,request_path,["User-Agent: CRT XR/1.0","Icy-MetaData: 0","Accept: audio/mpeg"])!=OK:
			fail("Radio request failed. Check the stream URL.")
		return
	if http.has_response() and connecting:
		var code := http.get_response_code()
		var headers := http.get_response_headers_as_dictionary()
		var normal := {}
		for key in headers: normal[str(key).to_lower()]=str(headers[key])
		if code in [301,302,303,307,308] and redirects<5 and normal.has("location"):
			redirects+=1
			var location: String=normal.location
			if location.begins_with("/"):
				var old := parse_url(station_url)
				location=str(old.scheme)+"://"+str(old.host)+(":"+str(old.port) if int(old.port)>0 else "")+location
			http.close(); station_url=location; connect_url(location); return
		if code!=200:
			fail("Radio returned HTTP %d. Use a direct MP3 stream URL." % code); return
		var content: String=normal.get("content-type","")
		if not content.is_empty() and not ("mpeg" in content or "mp3" in content or "octet-stream" in content):
			fail("This is not an MP3 stream. AAC, HLS, playlists and station webpages are not supported yet."); return
		icy_interval=maxi(0,int(normal.get("icy-metaint","0"))); icy_remaining=icy_interval; metadata_remaining=0
		connecting=false; set_status("Buffering radio…")
	if state==HTTPClient.STATUS_BODY and not connecting:
		# Bounded reads/decoding keep network work out of the emulator's audio path.
		if decoder.get_buffered_bytes()<65536:
			var data := http.read_response_body_chunk()
			if not data.is_empty():
				idle=0
				if not decoder.append(filter_icy(data)): fail("Radio buffer overflow. Try this station again."); return
		if playback==null or playback.get_frames_available()>=1152:
			var limit := 8 if playback==null else mini(8,playback.get_frames_available()/1152)
			var frames: PackedVector2Array=decoder.decode(limit)
			if playback!=null and decoder.get_sample_rate()==0:
				fail("Radio audio format changed. Press Play radio to reconnect."); return
			if not frames.is_empty():
				audio_idle=0
				if playback==null:
					var generator := AudioStreamGenerator.new()
					generator.mix_rate=decoder.get_sample_rate(); generator.buffer_length=.75
					player.stream=generator; player.play(); playback=player.get_stream_playback()
					streaming=true; set_status("Playing · Web radio")
				playback.push_buffer(frames)
	elif state==HTTPClient.STATUS_CONNECTED and requested and not connecting:
		fail("Radio ended. Press Play radio to reconnect.")

func save_resume(position := -1.0, clear := false) -> Error:
	if restoring: return OK
	if not clear and (kind.is_empty() or (kind=="local" and player.stream==null)): return OK
	var config := ConfigFile.new()
	config.set_value("resume","kind","" if clear else kind)
	config.set_value("resume","path",str(metadata.get("path",last_file)) if not clear and kind=="local" else "")
	config.set_value("resume","position",(position if position>=0 else position_seconds()) if not clear and kind=="local" else 0.0)
	config.set_value("resume","url",station_url if not clear and kind=="radio" else "")
	var error := ResumeStore.write("user://music-resume.cfg",config)
	if error!=OK and not resume_warning:
		resume_warning=true; report_error("Music position could not be saved. Check free space and user-folder permissions.")
	elif error==OK: resume_warning=false
	return error

func restore_resume() -> void:
	var config := ResumeStore.new().read("user://music-resume.cfg")
	if not config.has_section("resume") and not last_file.is_empty():
		config.set_value("resume","kind","local"); config.set_value("resume","path",last_file)
	var saved_kind = config.get_value("resume","kind","")
	if saved_kind=="radio":
		var url = config.get_value("resume","url","")
		if url is String and not parse_url(url).is_empty():
			kind="radio"; station_url=url; source="Web radio"; set_status("Radio ready · Press Play to connect"); transport_changed.emit()
	elif saved_kind=="local":
		var path = config.get_value("resume","path","")
		var position = config.get_value("resume","position",0.0)
		if not path is String or path.is_empty(): return
		last_file=path
		if not position is float and not position is int: position=0.0
		if not is_finite(float(position)): position=0.0
		if not FileAccess.file_exists(path):
			report_error("Last music track unavailable. Reconnect its drive, then choose Play last MP3 in Audio."); return
		tracks=album_tracks(path.get_base_dir()); album_folder=path.get_base_dir()
		for i in range(tracks.size()):
			if tracks[i].path==path:
				restoring=true; start_track(i,true,float(position)); restoring=false; return

func reset_defaults() -> void:
	stop(); tracks.clear(); metadata.clear(); track_index=-1; kind=""
	save_resume(-1,true)
	transport_changed.emit()
	for key in DEFAULTS: set(key,DEFAULTS[key])
	apply()

func _exit_tree() -> void:
	stop()
	var index := AudioServer.get_bus_index(bus_name)
	if index>0: AudioServer.remove_bus(index)
