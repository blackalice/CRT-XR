extends RefCounted
## Explicit ordered rows and stable IDs; bindings reuse the application's
## existing actions and preferences rather than a second settings store.
var host: Node
var menu: Control

func action(id: String, label: String, callback: Callable, help := "", disabled := false, value := "›") -> Dictionary:
	return {"id":id,"label":label,"kind":"action","action":callback,"help":help,"disabled":disabled,"value":value}

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
		item.unit = "degrees" if key=="hue" else ("x" if key in ["brightness","contrast"] else ("" if key in ["gamma","beam_softness"] else "percent"))
		result.append(item)
	return result

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
				crt.append(number("crt."+key,str(field[1]).replace(" (0 = flat)",""),h,key,0,field[2],field[3],h.SettingsDefaults.PICTURE[key],"percent","Adjusts the tube appearance. Changes are visible immediately.",func():
					w.screen_material.set_shader_parameter("scanlines",h.scanlines)
					w.screen_material.set_shader_parameter("mask_strength",h.phosphor_mask)
					w.screen_material.set_shader_parameter("glow_strength",h.phosphor_glow)
					w.glass_material.set_shader_parameter("reflection_strength",h.glass_reflections)
					w.set_curvature(h.screen_curvature)))
			crt.append_array(picture_fields(w.picture.BEAM_FIELDS))
			var fitting := picture_fields(w.picture.FIT_FIELDS)
			fitting.append(toggle("picture.aspect","Preserve game aspect",w.picture,"keep_aspect",true,"Keeps the full game picture at its intended display aspect, including handheld proportions.",refresh))
			fitting.append(toggle("picture.guides","Picture-edge guides",w.picture,"guides",false,"Highlights the game frame edges to check that the full picture is visible.",refresh))
			fitting.append(action("picture.restore_fit","Restore full-picture fit",func():
				w.picture.reset_fields(w.picture.FIT_FIELDS); w.picture.keep_aspect=true; refresh.call(); menu.refresh(),"Resets all fitting controls; leaves CRT and colour settings alone."))
			var presets: Array = []
			for pair in [["showcase","Deck Showcase (PAL)"],["clean","Clean source"],["rgb","RGB CRT"],["auto","Auto composite"],["pal","PAL composite"],["ntsc","NTSC composite"]]:
				var preset: String = pair[0]
				presets.append(action("preset."+preset,pair[1],func(): h.apply_picture_preset(preset),"Applies a starting point for CRT, colour and signal settings."))
			var signal_rows: Array = [{"id":"picture.connection","label":"Signal connection","kind":"choice","choices":["RGB","NTSC","PAL","Auto"],"default":0,"visual":true,"getter":func(): return w.picture.mode,"setter":func(value): w.picture.mode=value; refresh.call(),"help":"RGB is clean. Composite modes add colour decoding and interference; Auto uses the game rate."}]
			signal_rows.append_array(picture_fields(w.picture.COLOR_FIELDS.slice(6)))
			return [page("CRT",crt),page("Screen fit",fitting),page("Colour",picture_fields(w.picture.COLOR_FIELDS.slice(0,6))),page("Signal",signal_rows),page("Presets",presets)]
		2:
			var groups := {"Lighting":[],"Materials":[],"Placement & fade":[]}
			var tips := {
				"ambient":"Fills darker areas without casting additional shadows.","key_energy":"Brightness of the warm lamp; does not change the game image.",
				"fill_energy":"Soft front illumination to stop dark plastic losing detail.","warmth":"Balances the room lighting between cooler and warmer tones.",
				"shadow_strength":"Darkness of live shadows on furniture and floor. TV recesses use a separate baked map.",
				"cabinet_ao_strength":"Strength of Blender-baked shading in the TV's joins and recesses.",
				"cabinet_grain_strength":"Subtle static plastic finish. Fine grain fades at distance to avoid shimmer.",
				"spill_strength":"Picture-coloured light on the casing and surroundings. Zero disables both lights.",
				"floor_brightness":"Brightness of the carpet and woven rug.","fade_begin":"Distance where the small room island begins fading to black.","fade_end":"Distance where the surroundings become fully black."}
			for field in h.ROOM_FIELDS:
				var key: String = field[0]
				var group := "Materials" if key in ["cabinet_ao_strength","cabinet_grain_strength","floor_brightness","spill_strength"] else ("Placement & fade" if key in ["lamp_height","lamp_side","fade_begin","fade_end"] else "Lighting")
				groups[group].append({"id":"room."+key,"label":str(field[1]).replace(" (lower = lighter)","").replace(" (0 = off)",""),"kind":"number","min":field[2],"max":field[3],"step":field[4],"default":h.SettingsDefaults.ROOM[key],"visual":true,
					"unit":"m" if group=="Placement & fade" else ("percent" if key in ["warmth","shadow_strength","cabinet_ao_strength","cabinet_grain_strength","spill_strength"] else "x"),
					"getter":func(): return w.get(key),"setter":func(value): h.set_room_value(key,value),"help":tips.get(key,"Moves the room lamp while the TV stays stationary.")})
			groups.Lighting.append(toggle("room.shadows","Lamp shadows",w,"shadows",true,"Casts live shadows on the furniture and floor; the casing keeps its baked recess shading.",w.apply_room_settings))
			groups.Lighting.append(action("room.presets","Lighting presets",func(): menu.open_room_presets(),"Choose Warm bedroom, Bright inspection or Dim XR."))
			groups.Materials.append(toggle("room.rug","Bedroom rug",w,"show_rug",true,"Shows or hides the rug without changing the rest of the set.",w.apply_room_settings))
			var audio = h.emulator.tv_audio
			return [page("Lighting",groups.Lighting),page("Materials",groups.Materials),page("Placement & fade",groups["Placement & fade"]),page("Audio",[
				{"id":"audio.mode","label":"Sound mode","kind":"choice","choices":["Original","TV speakers","TV in room"],"default":2,"visual":false,"getter":func(): return audio.mode,"setter":func(value): audio.mode=value; audio.apply(),"help":"Original bypasses processing. TV speakers adds cabinet character. TV in room adds quiet reflections and head-relative panning. Resume the game to listen."},
				number("audio.room_amount","Room amount",audio,"room_amount",0,.25,.01,audio.DEFAULTS.room_amount,"percent","Quiet, short bedroom reflections. Applies in TV in room mode; the direct game sound stays immediate.",audio.apply,false),
				number("audio.speaker_character","Speaker character",audio,"speaker_character",0,1,.05,audio.DEFAULTS.speaker_character,"percent","Narrows the game's stereo image and gently reduces bass and treble, suggesting small TV speakers. Original bypasses this.",audio.apply,false),
				number("audio.directional_strength","Directional strength",audio,"directional_strength",0,1,.05,audio.DEFAULTS.directional_strength,"percent","In TV in room mode, sound stays towards the TV as you turn your head. Zero disables movement. Stereo panning, without binaural filtering.",audio.apply,false),
				toggle("atmosphere.power_on","TV power-on effect",h.power_on,"enabled",true,"A brief tube warm-up and quiet switch sound when the TV is first revealed. Does not pause or delay the game.",h.power_on.apply,false),
				number("atmosphere.power_sound","Power-on sound volume",h.power_on,"sound_level",0,1,.05,.60,"percent","Volume of the recorded CRT switch sound. Zero keeps the picture effect silent.",h.power_on.apply,false),
				action("atmosphere.preview","Preview TV power-on",h.preview_power_on,"Closes this menu and replays the short picture and sound effect.",not h.power_on.enabled)])]
		3:
			var tracking: Array = [
				action("tracking.real","Use glasses / retry",func(): h.use_tracking(true); menu.refresh(),"Connects or retries the glasses' tracking driver."),
				action("tracking.fixed","Use fixed view",func(): h.use_tracking(false); h.recenter(); menu.refresh(),"Uses a steady view. On desktop, mouse/keyboard simulation remains available."),
				toggle("tracking.diagnostics","Metrics overlay",h,"metrics_visible",false,"Shows frame rate, pose and tracking details. Off by default for a clean view. F1 also toggles it.",unchanged,false)]
			for axis in ["yaw","pitch","roll"]:
				tracking.append(toggle("tracking."+axis,"Invert "+axis,h.provider,"invert_"+axis,false,"Reverses this tracking axis. Only change it if movement feels reversed.",unchanged,false))
			return [page("Controller",[
				action("controls.mapping","Game button layout",func(): menu.notify(h.emulator.Registry.controls(h.emulator.system_id)),h.emulator.Registry.controls(h.emulator.system_id),false,h.emulator.Registry.SYSTEMS[h.emulator.system_id].name),
				toggle("controls.distance","Right stick adjusts distance",h,"right_stick_distance",true,"Stick up brings the TV closer; stick down moves it farther away.",unchanged,false),
				property_row("distance_speed","Distance adjustment speed",.2,2,.1,"m/s","Speed of the right-stick distance control, in metres per second.",false),
				{"id":"controls.preview","label":"Reduce input delay","kind":"choice","choices":["Off","1 frame","2 frames"],"default":1,"visual":false,"getter":func(): return h.emulator.run_ahead,"setter":func(value): h.emulator.run_ahead=value,"help":"Runs extra presentation-only game frames from a snapshot that is then restored. Two frames costs about twice the preview work."}]),
				page("Tracking",tracking),page("Calibration",[
				property_row("ipd","IPD (m)",0,.08,.001,"mm","Virtual eye separation; match your interpupillary distance."),
				property_row("convergence","Convergence (m)",1,10,.1,"m","Depth at which the stereo views have zero horizontal disparity."),
				property_row("vertical_fov","Vertical field of view",18,70,.5,"degrees","Advanced camera calibration. The glasses normally use 24 degrees."),
				property_row("smoothing","Smoothing (seconds)",0,.15,.01,"ms","Tracking smoothing; higher values can feel less immediate."),
				property_row("motion_predict","Motion prediction (seconds)",0,.08,.005,"ms","Extrapolates recent head rotation toward the frame being drawn, reducing perceived lag while moving. Zero keeps raw driver timing."),
				action("system.signal","Stop game / test signal",func(): h.emulator.stop(); menu.open_pause(),"Stops emulation and restores the calibration pattern.",not h.emulator.loaded),
				action("system.reset","Reset all settings",func(): menu.confirm_reset(),"Restores all option defaults, without deleting ROMs, save states or SRAM.")])]
		4:
			var slots: Array = [action("slot.showcase","Deck Showcase",h.load_showcase_setup,"Your tuned picture, placement, dark room and TV audio. Keeps display mode, platform FOV, tracking axes and per-game preference; hides metrics. Undo is available after loading.",false,"Built-in")]
			for i in range(3):
				var slot := i
				var config = h.settings_store.read("user://presets/slot-%d.cfg" % i)
				var saved: bool = config.has_section("view")
				slots.append(action("slot.%d" % i,str(config.get_value("meta","name",h.PROFILE_NAMES[i])),func(): menu.open_slot(slot),"Stores view, room and picture settings; does not switch display mode or tracking.",false,"Saved" if saved else "Empty"))
			if h.profile_undo!=null: slots.append(action("setups.undo","Undo last setup load",h.undo_profile,"Restore the setup from before loading Deck Showcase or a saved slot."))
			return [page("Setup slots",slots),page("Per-game picture",[
				{"id":"setups.pergame","label":"Remember picture per game","kind":"toggle","default":h.Showcase.PER_GAME_PICTURE,"visual":false,"getter":func(): return h.remember_game_picture,"setter":h.set_remember_game_picture,"help":"Fitting, CRT and colour belong to the game; room and view stay global."},
				action("setups.global","Use global picture for this game",h.forget_game_picture,"Removes this game's picture override; future global picture changes apply.",h.active_game_key.is_empty())])]
	return []
