extends RefCounted
## Explicit ordered rows and stable IDs; bindings reuse the application's
## existing actions and preferences rather than a second settings store.
const VideoSession = preload("res://scripts/video/video_session.gd")
var host: Node
var menu: Control

func action(id: String, label: String, callback: Callable, help := "", disabled := false, value := "›") -> Dictionary:
	return {"id":id,"label":label,"kind":"action","action":callback,"help":help,"disabled":disabled,"value":value}

# Says why a greyed-out row is unavailable, inline under its title.
func unavailable(item: Dictionary, reason: String) -> Dictionary:
	if item.get("disabled",false): item.disabled_reason=reason
	return item

func number(id: String, label: String, target: Object, key: String, low: float, high: float, step: float, fallback: float, unit: String, help: String, changed: Callable, visual := true) -> Dictionary:
	return {"id":id,"label":label,"kind":"number","min":low,"max":high,"step":step,"default":fallback,"unit":unit,"help":help,"visual":visual,
		"getter":func(): return target.get(key),"setter":func(value): target.set(key,value); changed.call()}

func toggle(id: String, label: String, target: Object, key: String, fallback: bool, help: String, changed: Callable, visual := true) -> Dictionary:
	return {"id":id,"label":label,"kind":"toggle","default":fallback,"help":help,"visual":visual,
		"getter":func(): return target.get(key),"setter":func(value): target.set(key,value); changed.call()}

func page(title: String, rows: Array) -> Dictionary:
	return {"title":title,"rows":rows}

func property_row(key: String, caption: String, low: float, high: float, step: float, unit: String, help: String, visual := true) -> Dictionary:
	return number("view."+key,caption.replace(" (m)","").replace(" (seconds)",""),host,key,low,high,step,float(host.SettingsDefaults.slider_default(caption,host)),unit,help,func():
		host.fade_material.set_shader_parameter("fade_width",host.edge_fade),visual)

func picture_fields(fields: Array) -> Array:
	var result: Array = []
	var tips := {
		"gamma":"Lower gamma lightens midtones; it does not change the black level.",
		"beam_softness":"Controls the sharpness of the CRT beam reconstruction.",
		"vignette":"Gently shades the outer edges of the tube.",
		"safe_border":"Leaves room between the complete game frame and the curved aperture.",
		"width":"Limits picture width without cropping the game frame.",
		"height":"Limits picture height without cropping the game frame.",
		"shift_x":"Moves the complete image within the available horizontal border.",
		"shift_y":"Moves the complete image within the available vertical border.",
		"phase_noise":"Composite chroma instability; visible only in a composite signal mode.",
		"signal_motion":"Animated composite interference. The game stays paused while adjusting.",
		"composite_strength":"Blends decoded composite colour with the clean source.",
		"artifact_strength":"Strength of composite colour bleeding and edge artifacts."}
	for field in fields:
		var key: String = field[0]
		var item := {"id":"picture."+key,"label":str(field[1]).replace(" (lower = lighter)","").replace(" (0 = off)",""),"kind":"number","min":field[2],"max":field[3],"step":field[4],"default":field[5],"visual":true,
			"getter":func(): return host.world.picture.values[key],"setter":func(value): host.world.picture.set_value(key,value),
			"help":tips.get(key,"Adjusts the picture immediately. Y restores this option's default.")}
		if key in ["composite_strength","artifact_strength","phase_noise","signal_motion"] and host.world.picture.mode==0:
			item.disabled=true; item.disabled_reason="Available in composite signal mode."
			item.help += " " + item.disabled_reason
		item.unit = "degrees" if key=="hue" else ("x" if key in ["brightness","contrast"] else ("" if key in ["gamma","beam_softness"] else "percent"))
		result.append(item)
	return result

## Videos → Picture: which picture videos use, and how a video fills the tube.
func video_picture_rows() -> Array:
	var h = host
	return [{"id":"video.own_picture","label":"Video picture","kind":"choice","choices":["Own settings","Same as games"],"default":0,
			"getter":func(): return 0 if h.video_own_picture else 1,"setter":func(value): h.set_video_own_picture(int(value)==0); menu.refresh(),
			"help":"Own settings: every video shares one picture, starting from Auto composite so videos look like broadcast TV. While a video plays, the Picture settings change it. Same as games: videos use your global picture."},
		unavailable(action("video.reset_picture","Reset video picture",func(): menu.ask("Reset the video picture?","Videos go back to your global picture with Auto composite. Games are not affected.",h.reset_video_picture),
			"Starts the video picture again from your global picture, with Auto composite.",not h.video_own_picture,""),"Videos use your global picture."),
		{"id":"video.default_style","label":"Picture shape for new videos","kind":"choice","choices":VideoSession.STYLES,"default":0,
			"getter":func(): return h.video_style,"setter":func(value): h.video_style=int(value); h.save_library(),
			"help":"Letterbox shows the whole widescreen picture; 14:9 trims the sides a little; Fill 4:3 crops to the tube; Stretch squeezes. Each video remembers its own choice."},
		{"id":"video.lines","label":"Picture lines","kind":"choice","choices":["240 · CRT look","480 · sharper"],"default":0,
			"getter":func(): return 1 if h.video_lines==480 else 0,"setter":func(value): h.video_lines=480 if int(value)==1 else 240; h.save_library(),
			"help":"240 lines is one broadcast field, the line structure a CRT shows, so scanlines and the phosphor mask are visible. 480 is sharper, but its lines are too fine to show on the virtual tube. Applies from the next video you open."},
		{"id":"video.interlace","label":"Interlaced video","kind":"choice","choices":["Field motion · TV","Blend"],"default":0,
			"getter":func(): return h.video_interlace,"setter":func(value): h.video_interlace=int(value); h.video.set_interlace(h.video_interlace); h.save_library(),
			"help":"For interlaced recordings such as DVDs and TV captures. Field motion shows each field in turn, 50 or 60 a second, for the smooth motion of broadcast TV. Blend mixes the two fields into one picture."}]

## Videos → VCR: the recorder the videos play from.
func vcr_rows() -> Array:
	var h = host
	return [{"id":"video.tape","label":"Tape look","kind":"choice","choices":["Off","VHS","Worn VHS"],"default":0,
			"getter":func(): return h.video_tape,"setter":func(value): h.video_tape=int(value); h.video.set_tape(h.video_tape); h.save_library(),
			"help":"Plays videos as if from a VHS tape: softer detail, smeared colour, wobbling lines and a torn bottom edge, with noise bars when you fast-forward or rewind. Worn VHS adds more noise, dropouts and a shaky pause. Also in the Start menu while watching."},
		{"id":"video.osd","label":"On-screen text","kind":"toggle","default":true,
			"getter":func(): return h.video_osd,"setter":func(value): h.video_osd=bool(value); h.video.osd_enabled=h.video_osd; h.video.update_osd(); h.save_library(),
			"help":"Shows PLAY, PAUSE, FF and REW in green VCR lettering on the picture, like a video recorder."},
		{"id":"video.vcr_sounds","label":"Mechanism sounds","kind":"toggle","default":true,
			"getter":func(): return h.video_vcr_sounds,"setter":func(value): h.video_vcr_sounds=bool(value); h.vcr_sounds.enabled=h.video_vcr_sounds; h.save_library(),
			"help":"The recorder's clunks for play, pause and stop, and its motor whirring while you fast-forward or rewind. They follow the game volume."}]

## Videos → Playback: subtitles, decoding and where the videos are.
func playback_rows() -> Array:
	var h = host
	return [{"id":"video.subtitles_default","label":"Subtitles for new videos","kind":"toggle","default":false,
			"getter":func(): return h.video_subtitles,"setter":func(value): h.video_subtitles=bool(value); h.save_library(),
			"help":"Turns on a video's first subtitles when you open it. A choice you make for a video is remembered for that video."},
		{"id":"video.hardware","label":"Hardware video decoding","kind":"toggle","default":true,
			"getter":func(): return h.video_hardware,"setter":func(value): h.video_hardware=bool(value); h.save_library(),
			"help":"Decodes on the GPU (VA-API on Steam Deck), leaving the CPU for the room and tracking. Falls back to software by itself when a file or GPU cannot use it. Applies from the next video."},
		action("video.folder","Video folder",func(): menu.videos.open_video_folder_picker(),"Choose where CRT XR looks for videos. Subfolders are included.",false,h.video_dir)]

func pages(category: int) -> Array:
	var h = host
	var w = h.world
	var refresh := func(): w.picture.refresh()
	var unchanged := func(): pass
	match category:
		0:
			return [page("Placement",[
				property_row("distance","TV distance (m)",1.2,5,.1,"m","Moves the entire TV and stand closer or farther."),
				property_row("height_offset","Screen height offset (m)",-1.5,1.5,.05,"m","Moves the TV, furniture and floor together vertically."),
				property_row("tv_scale","TV scale",.5,1.6,.05,"percent","Scales the whole set; this is independent of picture fitting."),
				action("view.fit","Fit TV to view",h.fit_tv_to_view,"Fits the physical TV inside your neutral view."),
				action("view.recenter","Recenter head",h.recenter,"Also available on R3, without opening the menu.")]),
				page("Display",[
				toggle("view.stereo","Side-by-side stereo",h,"stereo",false,"Use with the glasses' physical SBS mode. This does not switch the glasses themselves.",func(): h.set_stereo(h.stereo)),
				action("view.fullscreen","Toggle fullscreen",h.toggle_fullscreen,"Switch the local application window between fullscreen and windowed mode."),
				property_row("edge_fade","Soft view edges",0,.2,.005,"percent","Fades the edges of the glasses' viewing window into black.")])]
		1:
			var crt: Array = []
			for field in [["scanlines","Scanlines",.7,.05],["phosphor_mask","Phosphor mask",.5,.05],["phosphor_glow","Phosphor glow",.4,.02],["glass_reflections","Glass reflections",.4,.02],["screen_curvature","Screen curvature (0 = flat)",1,.05]]:
				var key: String = field[0]
				crt.append(number("crt."+key,str(field[1]).replace(" (0 = flat)",""),h,key,0,field[2],field[3],h.SettingsDefaults.PICTURE[key],"strength","Adjusts the tube appearance. Changes are visible immediately.",func():
					w.screen_material.set_shader_parameter("scanlines",h.scanlines)
					w.screen_material.set_shader_parameter("mask_strength",h.phosphor_mask)
					w.screen_material.set_shader_parameter("glow_strength",h.phosphor_glow)
					w.glass_material.set_shader_parameter("reflection_strength",h.glass_reflections)
					w.set_curvature(h.screen_curvature)))
			crt.append_array(picture_fields(w.picture.BEAM_FIELDS))
			crt.append(action("crt.degauss","Degauss",h.degauss,"Like the button on an old set: closes the menu, then the picture wobbles and swirls with colour as the tube's field clears.",false,""))
			var fitting := picture_fields(w.picture.FIT_FIELDS)
			fitting.append(toggle("picture.aspect","Preserve picture shape",w.picture,"keep_aspect",true,"Keeps the whole game or video picture at its intended shape, including handheld proportions. A video's widescreen shape is set by Picture shape.",refresh))
			fitting.append(toggle("picture.guides","Picture-edge guides",w.picture,"guides",false,"Highlights the game frame edges to check that the full picture is visible.",refresh))
			fitting.append(action("picture.restore_fit","Restore full-picture fit",func():
				w.picture.reset_fields(w.picture.FIT_FIELDS); w.picture.keep_aspect=true; refresh.call(); menu.refresh(),"Resets all fitting controls; leaves CRT and colour settings alone."))
			var presets: Array = []
			for pair in [["showcase","Deck Showcase (PAL)","Warm PAL colour and pronounced scanlines."],["clean","Clean source","Crisp source pixels; scanlines and phosphor effects off."],["rgb","RGB CRT","Clean RGB colour with a defined CRT beam."],["auto","Auto composite","Composite character matched to the game’s frame rate."],["pal","PAL composite","Soft PAL colour blending and analog texture."],["ntsc","NTSC composite","NTSC colour bleed and classic composite artifacts."]]:
				var preset: String = pair[0]
				presets.append(action("preset."+preset,pair[1],func(): menu.pictures.apply_preset(preset),pair[2],false,"✓ Active" if menu.pictures.applied_preset()==preset else "Apply"))
			if menu.pictures.has_custom_picture():
				presets.append(unavailable(action("preset.custom","Restore my custom picture",menu.pictures.restore_custom_picture,"Brings back the picture you had tuned yourself before choosing a preset.",menu.pictures.applied_preset().is_empty()),"Your custom picture is already in use."))
			for i in range(menu.pictures.MY_PRESET_COUNT):
				var index: int = i
				var state := "✓ Active" if menu.pictures.applied_preset()=="mine.%d" % index else ("Saved" if menu.pictures.my_preset_saved(index) else "Empty")
				presets.append(action("preset.mine.%d" % index,menu.pictures.my_preset_name(index),func(): menu.pictures.open_my_preset(index),"Your own saved picture: apply, save the current picture here, rename or delete.",false,state))
			if menu.pictures.picture_undo!=null: presets.append(action("preset.undo","Undo picture preset",menu.pictures.undo_picture_preset,"Restore the picture from before the last preset."))
			var signal_rows: Array = [{"id":"picture.connection","label":"Signal connection","kind":"choice","choices":["RGB","NTSC","PAL","Auto"],"default":0,"visual":true,"getter":func(): return w.picture.mode,"setter":func(value): w.picture.mode=value; refresh.call(); menu.refresh(),"help":"RGB is clean. Composite modes add colour decoding and interference. Auto picks PAL or NTSC from the game's or video's frame rate."}]
			signal_rows.append_array(picture_fields(w.picture.COLOR_FIELDS.slice(6)))
			var picture_pages := [page("Presets",presets),page("CRT",crt),page("Screen fit",fitting),page("Colour",picture_fields(w.picture.COLOR_FIELDS.slice(0,6))),page("Signal",signal_rows)]
			return picture_pages
		3:
			var groups := {"Lighting":[],"Materials":[],"Placement":[]}
			var tips := {
				"ambient":"Fills darker areas without casting additional shadows.","key_energy":"Brightness of the warm lamp; does not change the game image.",
				"fill_energy":"Soft front illumination to stop dark plastic losing detail.","warmth":"Balances the room lighting between cooler and warmer tones.",
				"shadow_strength":"Darkness of live shadows on unbaked objects. Baked contact shading stays fixed.",
				"cabinet_ao_strength":"Strength of Blender-baked shading in the TV's joins and recesses.",
				"cabinet_grain_strength":"Subtle static plastic finish. Fine grain fades at distance to avoid shimmer.",
				"spill_strength":"Picture-coloured light on the casing and surroundings. Zero disables both lights.",
				"floor_brightness":"Brightness of the floor.","fade_begin":"Distance where the small room island begins fading to black.","fade_end":"Distance where the surroundings become fully black."}
			for field in h.ROOM_FIELDS:
				var key: String = field[0]
				var group := "Materials" if key in ["cabinet_ao_strength","cabinet_grain_strength","floor_brightness","spill_strength"] else ("Placement" if key in ["lamp_height","lamp_side","fade_begin","fade_end"] else "Lighting")
				groups[group].append({"id":"room."+key,"label":str(field[1]).replace(" (lower = lighter)","").replace(" (0 = off)",""),"kind":"number","min":field[2],"max":field[3],"step":field[4],"default":h.SettingsDefaults.ROOM[key],"visual":true,
					"unit":"m" if group=="Placement" else ("percent" if key in ["warmth","shadow_strength","cabinet_ao_strength","cabinet_grain_strength","spill_strength"] else "x"),
					"getter":func(): return w.get(key),"setter":func(value): h.set_room_value(key,value),"help":tips.get(key,"Moves the room lamp while the TV stays stationary.")})
			groups.Lighting.append(toggle("room.shadows","Lamp shadows",w,"shadows",true,"Controls live shadows on unbaked objects. The TV and table keep their soft baked contact shading.",w.apply_room_settings))
			groups.Materials.push_front({"id":"room.floor_style","label":"Floor","kind":"choice","choices":w.FLOOR_STYLES,"default":h.Showcase.ROOM.floor_style,"visual":true,
				"getter":func(): return w.floor_style,"setter":func(value): w.floor_style=value; w.apply_room_settings(),
				"help":"90s confetti carpet, a plain wool carpet with natural wear, or wooden floorboards."})
			var props: Array = [
				toggle("room.clock_radio","Clock radio",w,"show_clock_radio",true,"A clock radio beside the TV showing the time on a dim red display. Music plays from its side of the room.",w.apply_room_settings),
				toggle("room.clock_24_hour","24-hour clock",w,"clock_24_hour",false,"Shows the clock radio and VCR time in 24-hour format.",w.apply_room_settings),
				toggle("room.vcr","VCR",w,"show_vcr",true,"A video recorder on the shelf under the TV. Its display shows the time, or the tape counter while a video plays.",w.apply_room_settings),
				toggle("room.game_boxes","Game boxes",w,"show_game_boxes",true,"A small stack of game boxes beside the TV.",func(): w.apply_room_settings(); menu.refresh()),
				toggle("room.game_cover","Your game on the box",w,"show_game_cover",true,"The top box shows the playing game's cover, from your existing scrapes (covers or box2dfront).",w.apply_room_settings)]
			if not w.show_game_boxes:
				props[-1].disabled=true; props[-1].disabled_reason="Show the game boxes first."; props[-1].help += " " + props[-1].disabled_reason
			groups.Lighting.append(toggle("room.follow_clock","Follow the time of day",w,"follow_clock",false,"Brighter and cooler by day, warmer in the evening and dimmer late at night, around your own lighting.",w.apply_room_settings))
			var ambience_level := number("room.ambience_level","Room sound volume",w,"ambience_level",0,1,.05,h.Showcase.ROOM.ambience_level,"percent","Kept well under the game or video.",w.apply_room_settings,false)
			if w.ambience==0:
				ambience_level.disabled=true; ambience_level.disabled_reason="Choose a room sound first."; ambience_level.help += " " + ambience_level.disabled_reason
			var sound: Array = [{"id":"room.ambience","label":"Room sound","kind":"choice","choices":w.room_sound.CHOICES,"default":h.Showcase.ROOM.ambience,"visual":false,
				"getter":func(): return w.ambience,"setter":func(value): w.ambience=value; w.apply_room_settings(); menu.refresh(),
				"help":"Quiet sound for the room around the TV: still air, rain on the window, or rain with a ticking clock."},
				ambience_level,
				toggle("room.crt_whine","Tube whine",w,"crt_whine",false,"The high-pitched whine of a CRT's line transformer (15.7 kHz). Very quiet, and many people can't hear it at all.",w.apply_room_settings,false)]
			var presets: Array = [menu.room_choice("room.preset")]
			for i in range(h.rooms.COUNT):
				var index: int = i
				var state := "✓ Active" if h.rooms.active()=="mine.%d" % index else ("Saved" if h.rooms.saved(index) else "Empty")
				presets.append(action("room.mine.%d" % index,h.rooms.name(index),func(): menu.open_my_room(index),"Your own room: apply it, save the current room here, rename or delete.",false,state))
			return [page("Presets",presets),page("Lighting",groups.Lighting),page("Materials",groups.Materials),page("Props",props),page("Sound",sound),page("Placement",groups["Placement"])]

		4:
			var glasses_source: String = "VITURE glasses" if OS.get_name() == "Windows" else "XR Gaming"
			var tracking: Array = [
				{"id":"tracking.source","label":"Tracking source","kind":"choice","choices":[glasses_source,"OpenTrack"],"default":0,
					"getter":func(): return 1 if h.tracking_source == "opentrack" else 0,"setter":func(value): h.set_tracking_source("opentrack" if int(value) == 1 else "glasses"); menu.refresh(),
					"help":"OpenTrack lets other glasses track: run a tool that sends OpenTrack UDP to 127.0.0.1 port 4242, such as opentrack, PhoenixHeadTracker (XREAL) or VertoXR (Rokid, RayNeo). If a direction is reversed, invert that axis below."},
				action("tracking.real","Connect glasses",func(): h.use_tracking(true); menu.refresh(),"Connects or retries the glasses' tracking driver."),
				action("tracking.fixed","Use fixed view",func(): h.use_tracking(false); h.recenter(); menu.refresh(),"Uses a steady view. On desktop, mouse/keyboard simulation remains available."),
				toggle("tracking.diagnostics","Metrics overlay",h,"metrics_visible",false,"Shows frame rate, pose and tracking details. Off by default for a clean view. F1 also toggles it.",unchanged,false)]
			for axis in ["yaw","pitch","roll"]:
				tracking.append(toggle("tracking."+axis,"Invert "+axis,h.provider,"invert_"+axis,false,"Reverses this tracking axis. Only change it if movement feels reversed.",unchanged,false))
			var input_delay: Dictionary = {"id":"controls.preview","label":"Reduce input delay","kind":"choice","choices":["Off","1 frame","2 frames"],"default":1,"visual":false,"getter":func(): return h.emulator.run_ahead,"setter":func(value): h.emulator.run_ahead=value,"help":"Runs extra presentation-only game frames from a snapshot that is then restored. Two frames costs about twice the preview work."}
			if h.emulator.loaded and not h.emulator.preview_possible():
				input_delay.disabled=true
				var console: String=h.emulator.Registry.SYSTEMS[h.emulator.system_id].name
				if h.emulator.preview_suspended: input_delay.disabled_reason="Paused for this game: it needs the full frame time. Reload the game to try again."
				elif h.emulator.separate_preview: input_delay.disabled_reason="The separate preview core could not start for %s." % console
				else: input_delay.disabled_reason="%s needs Separate preview core: its sound buzzes with a same-core preview." % console
			var separate_preview := toggle("controls.separate_preview","Separate preview core",h.emulator,"separate_preview",true,"Runs the input preview in a second copy of the emulator, so game sound is never rewound. Works on every console; uses a little more memory. Off limits the preview to SNES.",func(): h.emulator.set_separate_preview(h.emulator.separate_preview); menu.refresh(),false)
			return [page("Controller",[
				action("controls.mapping","Game button layout",func(): menu.notify(h.emulator.Registry.controls(h.emulator.system_id)),h.emulator.Registry.controls(h.emulator.system_id),false,h.emulator.Registry.SYSTEMS[h.emulator.system_id].name),
				toggle("controls.distance","Right stick adjusts distance",h,"right_stick_distance",true,"Stick up brings the TV closer; stick down moves it farther away.",unchanged,false),
				property_row("distance_speed","Distance adjustment speed",.2,2,.1,"m/s","Speed of the right-stick distance control, in metres per second.",false),
				input_delay,separate_preview]),
				page("Tracking",tracking),page("Advanced calibration",[
				property_row("ipd","IPD (m)",0,.08,.001,"mm","Virtual eye separation; match your interpupillary distance."),
				property_row("convergence","Convergence (m)",1,10,.1,"m","Depth at which the stereo views have zero horizontal disparity."),
				property_row("vertical_fov","Vertical field of view",18,70,.5,"degrees","Advanced camera calibration. The glasses normally use 24 degrees."),
				property_row("smoothing","Smoothing (seconds)",0,.15,.01,"ms","Tracking smoothing; higher values can feel less immediate."),
				property_row("motion_predict","Motion prediction (seconds)",0,.08,.005,"ms","Optional lead for recent head movement. Recommended default: 0 ms for raw driver timing. Increase only if tracking feels delayed; too much can feel oversensitive."),
				unavailable(action("system.signal","Stop and show test signal",func():
					if h.video.loaded: h.stop_video()
					if h.emulator.loaded: h.emulator.stop()
					menu.open_pause(),"Stops the game or video and shows the calibration pattern.",not h.emulator.loaded and not h.video.loaded),"Nothing is playing.")])]
		5:
			var slots: Array = [action("slot.showcase","Deck Showcase",h.load_showcase_setup,"The tuned Deck picture, placement, dark room and TV audio. Display mode, tracking and per-game settings stay as they are; you can undo it.",false,"Built-in")]
			for i in range(3):
				var slot := i
				var config = h.settings_store.read("user://presets/slot-%d.cfg" % i)
				var saved: bool = config.has_section("view")
				slots.append(action("slot.%d" % i,str(config.get_value("meta","name",h.PROFILE_NAMES[i])),func(): menu.open_slot(slot),"Stores view, room and picture settings; does not switch display mode or tracking.",false,"Saved" if saved else "Empty"))
			if h.profile_undo!=null: slots.append(action("setups.undo","Undo last setup load",h.undo_profile,"Restore the setup from before loading Deck Showcase or a saved slot."))
			return [page("Setup slots",slots),page("Per-game picture",[
				{"id":"setups.pergame","label":"Remember picture per game","kind":"toggle","default":h.Showcase.PER_GAME_PICTURE,"visual":false,"getter":func(): return h.remember_game_picture,"setter":h.set_remember_game_picture,"help":"Each game keeps its own fitting, CRT and colour; room and view stay global. Off: games use the global picture. Videos have their own setting under Videos → Picture."},
				unavailable(action("setups.global","Use global picture for this game",h.forget_game_picture,"Removes this game's picture override; future global picture changes apply.",h.active_game_key.is_empty() or h.active_game_key==h.VIDEO_PROFILE),"Start a game with its own picture first.")])]
		6:
			return [page("About & Help",[
				action("system.version","CRT XR",func(): menu.notify("CRT XR "+str(ProjectSettings.get_setting("application/config/version"))),"A little CRT room for your XR glasses.",false,str(ProjectSettings.get_setting("application/config/version"))),
				action("system.glasses","Using glasses",func(): menu.open_help("Using glasses",menu.play.glasses_guide()),"How to connect glasses, start in side-by-side 3D and recentre."),
				action("system.device","Device status",func(): menu.open_help("Device status",menu.status_title+"\n\n"+menu.status_detail),"Current display and tracking status."),
				action("system.controls","Controls",func(): menu.open_help("Controls","Menu: L1 + R1 + Start / Escape. Recenter: R3 / R. Navigate: D-pad / arrows. Select: A / Enter. Back: B / Backspace. Categories: L1 / R1 (Q / E); sections: L2 / R2 (Z / C). Reset option: Y. Picture preview: X."),"Controller and keyboard shortcuts."),
				action("system.help","Troubleshooting",func(): menu.open_help("Troubleshooting","Tracking unavailable? Retry glasses in Controls & XR → Tracking, or choose fixed view. Double image? Match the glasses’ SBS mode with View → Display. Missing games? Check Library locations. Games can be plain files or ZIPs for a supported console; Sega CD discs can be .cue/.bin or CHD in a Sega CD folder. No radio? Use a direct MP3 stream URL. Save failed? Check free space and folder permissions."),"Help with glasses, games, audio and saving."),
				action("system.credits","Credits & licences",func(): menu.open_help("Credits & licences",FileAccess.get_file_as_string("res://THIRD_PARTY.md")),"Godot, libretro, and the artists and developers behind CRT XR."),
				action("system.diagnostics","Copy diagnostics",func():
					DisplayServer.clipboard_set("CRT XR "+str(ProjectSettings.get_setting("application/config/version"))+" | "+OS.get_name()+" | Godot "+str(Engine.get_version_info().string)+" | "+DisplayServer.get_name()); menu.notify("Version and platform details copied; no ROM or music paths included."),"Copies version/platform information for a bug report."),
				action("system.reset","Reset all settings",menu.confirm_reset,"Restores defaults without deleting games or saves.")]),page("Accessibility",[
				toggle("access.large","Larger menu text",h,"menu_large_text",false,"Larger text and taller rows; lists scroll to keep focus visible.",menu.apply_accessibility,false),
				toggle("access.contrast","Stronger menu contrast",h,"menu_high_contrast",false,"Brighter text and clearer borders on a dark background.",menu.apply_accessibility,false),
				toggle("access.motion","Reduced animation",h,"menu_reduced_motion",false,"Instant focus changes and no TV warm-up animation.",menu.apply_accessibility,false),
				toggle("access.sounds","Menu sounds",h,"menu_sounds",false,"Quiet feedback for focus and confirmation.",unchanged,false),
				toggle("access.depth","Menu depth",h,"menu_depth",true,"In side-by-side 3D the menu floats in front of the TV, the selected item lifts towards you and the room dims behind. Off gives a flat menu.",func(): menu.refresh(),false),
				unavailable(toggle("access.curve","Curved menu",h,"menu_curve",false,"Bends the menu gently towards you at its sides, like a curved monitor. Best in side-by-side 3D.",unchanged,false).merged({"disabled":not h.menu_depth},true),"Needs Menu depth."),
				toggle("access.haptics","Controller vibration",h,"menu_haptics",false,"A light tick as the selection moves and a firmer one when you confirm.",func(): menu.refresh(),false),
				unavailable(number("access.haptic_strength","Vibration strength",h,"haptic_strength",0.1,1.0,0.1,0.8,"percent","How strong the ticks feel. The Steam Deck passes on only part of it, so it may need to be higher there.",func(): h.menu_vibrate(1.0, 0.07),false).merged({"disabled":not h.menu_haptics},true),"Turn on Controller vibration first.")])]
		8:
			if not menu.videos.videos_shown():
				return [page("Videos",[action("videos.setup","Set up videos",menu.games.open_library_tools,"Choose a video folder in Library locations. Its videos appear after your consoles, and their settings appear here.",false,"›")])]
			return [page("Picture",video_picture_rows()),page("VCR",vcr_rows()),page("Playback",playback_rows())]
		7:
			var quick: Array = []
			for source in pages(0)[0].rows:
				if source.id in ["view.distance","view.height_offset","view.recenter"]:
					var copy: Dictionary=source.duplicate(); copy.id="quick."+source.id; quick.append(copy)
			# Custom restores your own tuned picture; saved presets follow the built-in ones.
			var preset_ids: Array = [""]+menu.pictures.PRESET_IDS
			var preset_names: Array = ["Custom"]+menu.pictures.PRESET_NAMES
			for i in range(menu.pictures.MY_PRESET_COUNT):
				if menu.pictures.my_preset_saved(i): preset_ids.append("mine.%d" % i); preset_names.append(menu.pictures.my_preset_name(i))
			quick.append({"id":"quick.preset","label":"Picture preset","kind":"choice","choices":preset_names,"getter":func(): return maxi(0,preset_ids.find(menu.pictures.applied_preset())),"setter":func(value):
				var id: String=preset_ids[value]
				if id.is_empty(): menu.pictures.restore_custom_picture()
				elif id.begins_with("mine."): menu.pictures.apply_my_preset(int(id.get_slice(".",1)))
				else: menu.pictures.apply_preset(id),"help":"Choose a look. Custom brings back your own tuned picture; save your own on Picture → Presets.","visual":true})
			quick.append(menu.room_choice("quick.room"))
			quick.append(number("quick.game_volume","Game volume",h.music,"game_volume",0,1,.05,1,"percent","Independent game volume.",h.music.apply,false))
			quick.append(number("quick.music_volume","Music volume",h.music,"volume",0,1,.05,.45,"percent","Independent music volume.",h.music.apply,false))
			return [page("Everyday",quick)]
		2:
			var audio = h.emulator.tv_audio
			var audio_rows: Array=[
				{"id":"audio.mode","label":"Sound mode","kind":"choice","choices":["Original","TV speakers","TV in room"],"default":2,"visual":false,"getter":func(): return audio.mode,"setter":func(value): audio.mode=value; audio.apply(); menu.refresh(),"help":"Original bypasses processing. TV speakers adds cabinet character. TV in room adds reflections and head-relative panning."},
				number("audio.room_amount","Room amount",audio,"room_amount",0,.25,.01,audio.DEFAULTS.room_amount,"percent","Adds short reflections around the TV.",audio.apply,false),
				number("audio.speaker_character","Speaker character",audio,"speaker_character",0,1,.05,audio.DEFAULTS.speaker_character,"percent","Narrows stereo and softens bass and treble.",audio.apply,false),
				number("audio.directional_strength","Directional strength",audio,"directional_strength",0,1,.05,audio.DEFAULTS.directional_strength,"percent","Keeps the sound towards the TV as your head turns.",audio.apply,false)]
			for index in [1,2,3]:
				if (index==2 and audio.mode==0) or (index!=2 and audio.mode!=2):
					audio_rows[index].disabled=true
					audio_rows[index].disabled_reason="Available with TV speakers or TV in room mode." if index==2 else "Available in TV in room mode."
					audio_rows[index].help += " " + audio_rows[index].disabled_reason
			audio_rows.append(action("audio.preview","Preview sound",audio.preview_sample,"Plays a short sample through the selected sound mode while the game stays paused."))
			audio_rows.append(toggle("atmosphere.power_on","TV power-on effect",h.power_on,"enabled",true,"Brief tube warm-up and switch sound when first revealed.",func(): h.power_on.apply(); menu.refresh(),false))
			audio_rows.append(toggle("atmosphere.channel_change","Channel change effect",h.tv_effects,"channel_change",true,"A burst of static and a rolling picture when a game or video starts, like changing channel.",menu.refresh,false))
			audio_rows.append(toggle("atmosphere.power_off","Power-off effect",h.tv_effects,"power_off_effect",true,"The picture shrinks to a fading dot as CRT XR closes.",menu.refresh,false))
			var volume=number("atmosphere.power_sound","TV effect sounds",h.power_on,"sound_level",0,1,.05,.60,"percent","Volume of the switch, static, degauss and power-off sounds. Zero keeps them silent.",h.power_on.apply,false)
			if not (h.power_on.enabled or h.tv_effects.channel_change or h.tv_effects.power_off_effect):
				volume.disabled=true; volume.disabled_reason="Turn on a TV effect first."; volume.help += " " + volume.disabled_reason
			audio_rows.append(volume)
			audio_rows.append(action("atmosphere.preview","Preview TV power-on",h.preview_power_on,"Closes settings and replays the picture and sound effect.",not h.power_on.enabled))
			var music = h.music
			audio_rows.push_front(number("music.game_volume","Game volume",music,"game_volume",0,1,.05,1,"percent","Independent of music volume. Game sound pauses with emulation.",music.apply,false))
			var duck_toggle=toggle("music.duck_game","Dip game during music",music,"duck_game",false,"Automatically lowers game audio while music is audible; restores it when paused or stopped.",func(): music.apply(); menu.refresh(),false)
			var duck_amount=number("music.duck_amount","Game volume dip",music,"duck_amount",0,1,.05,.5,"percent","How much to reduce the chosen game volume while music plays. Fades smoothly.",music.apply,false)
			if not music.duck_game:
				duck_amount.disabled=true; duck_amount.disabled_reason="Enable Dip game during music first."
			return [page("TV sound",audio_rows),page("Music balance",[duck_toggle,duck_amount]),page("Music & radio",[
				action("music.file","Choose music / album",menu.music.open_music_browser,"Browse local storage or an SD card. Music keeps playing in menus."),
				unavailable(action("music.replay","Play last MP3",func(): music.play_last_file(); menu.refresh(); menu.notify(music.status),"Continues the saved track and position without changing the game.",music.last_file.is_empty()),"No MP3 has been played yet."),
				action("music.url","Radio stream URL",menu.music.edit_radio_url,"Enter a direct MP3 stream URL. Station webpages, AAC and HLS are not supported.",false,"Edit"),
				unavailable(action("music.radio","Play radio",func(): music.play_station(music.station_url); menu.refresh(); menu.notify(music.status),"Streams a direct MP3 radio station with a bounded audio buffer.",music.station_url.is_empty()),"Add a radio stream URL first."),
				action("music.stop","Stop music",func(): music.stop(); menu.refresh(); menu.notify(music.status),"Stops music or radio. Leaves game sound unchanged.",music.player.stream==null and not music.connecting),
				number("music.volume","Music volume",music,"volume",0,1,.05,.45,"percent","Independent music level. Continues while the game is paused.",music.apply,false),
				toggle("music.loop","Repeat album",music,"loop",true,"Repeat the folder after its last track. Off stops at the album end.",music.apply,false)]),page("Music space",[
				number("music.reverb","Music room reverb",music,"reverb",0,.3,.01,.12,"percent","Short, subtle reflections from the room; zero disables the effect.",music.apply,false),
				number("music.directional","Music direction",music,"directional",0,1,.05,.8,"percent","Sound stays beside the TV as you turn your head. Zero keeps normal stereo.",music.apply,false),
				number("music.side","Radio position",music,"side",-2,2,.1,-1.1,"m","Position left or right of the TV, independent of the game speakers.",music.apply,false)])]
	return []
