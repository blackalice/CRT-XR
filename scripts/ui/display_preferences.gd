extends RefCounted
## Display policy and sparse picture overrides. Runtime menu previews never
## become hardware calibration or another programme's inherited defaults.
var host: Node
var data: Dictionary = {"version":1,"last_screen":"standard","game_tv_policy":"standard","defaults":{"game":"standard","video":"wide"},"platforms":{},"games":{},"videos":{},"views":{},"pictures":{},"looks":{},"look_for":{}}
var initialized := false
var kind := "game"
var system := ""
var content := ""
var scope := 0 # This programme, platform, TV default
var base: Dictionary = {}
var applied: Dictionary = {}
var busy := false
## Looks: named pictures that games and consoles link to rather than copy.
## A look's values live in data.pictures["look.<id>"]; its name in data.looks;
## which consoles and games use it in data.look_for ("platform.<system>",
## "game.<content hash>" or "path.<ROM path>"). A game's picture is, in order:
## the TV defaults, its console's look, its console's changes, its own look,
## then its own changes. Editing a look changes every game that uses it.
var editing_look := ""
const LOOK_SHARE_PREFIX := "CRTXR-LOOK1:"
const DISPLAY_CHOICES := ["Standard · Fit","Standard · Fill","Standard · Stretch","Wide · Fit","Wide · Fill","Wide · Stretch"]
const WIDE_TV_PLATFORMS := ["ps2","gamecube","psp"]
const PLATFORM_DEFAULTS_VERSION := 1
const TV_POLICIES := ["standard", "wide", "console"]
const TV_POLICY_NAMES := ["Standard TV (4:3) for all consoles", "Wide TV (16:9) for all consoles", "TV model chosen by console"]
const TV_POLICY_CHOICES := ["Standard TV (4:3)", "Wide TV (16:9)", "Choose by console"]
const TV_POLICY_HELP := ["Uses the standard 4:3 TV cabinet for all consoles. Fits the game's original shape inside it, adding borders when needed. Individual overrides still apply.",
	"Uses the wide 16:9 TV cabinet for all consoles. A 4:3 game has side borders; it is not stretched. Does not enable widescreen emulation.",
	"Chooses the TV cabinet by console: wide for PS2, GameCube and PSP, standard for others. Each game keeps its original shape."]

func reset_platform_display_defaults() -> void:
	data.defaults.game="standard"
	data.game_tv_policy="standard"
	data.platform_defaults_version=PLATFORM_DEFAULTS_VERSION

func set_tv_policy(policy: String) -> void:
	if not policy in TV_POLICIES: return
	commit()
	# Old releases wrote their automatic choices as explicit console overrides.
	# Remove only matching seed fields when the user explicitly chooses a policy.
	if data.get("legacy_tv_seeds", false):
		for platform in preload("res://scripts/emulation/core_registry.gd").DEFINITIONS:
			var wide: bool = platform in WIDE_TV_PLATFORMS
			var screen: String = "wide" if wide else "standard"
			if entry("platforms", platform).get("screen", "") == screen: set_preference("platforms", platform, "")
			var key: String = "game." + screen + ".platform." + str(platform)
			var patch: Dictionary = data.pictures.get(key, {}).duplicate()
			if patch.get("picture.keep_aspect") == not wide: patch.erase("picture.keep_aspect")
			if patch.get("picture.fit_mode") == 0: patch.erase("picture.fit_mode")
			if patch.is_empty(): data.pictures.erase(key)
			else: data.pictures[key] = patch
		data.legacy_tv_seeds = false
	data.game_tv_policy = policy
	data.defaults.game = "wide" if policy == "wide" else "standard"
	for screen in ["standard", "wide"]:
		var key: String = "game." + screen + ".screen"
		var patch: Dictionary = data.pictures.get(key, {}).duplicate()
		patch["picture.keep_aspect"] = true
		patch["picture.fit_mode"] = 0
		data.pictures[key] = patch
	refresh_screen()

func policy_row(id: String, keep_current := false) -> Dictionary:
	var current: bool = keep_current or not data.get("game_tv_policy", "custom") in TV_POLICIES
	var offset: int = 1 if current else 0
	return {"id":id,"label":"TV for games","kind":"choice","visual":false,"value_width":260,
		"choices":(["Keep current"] if current else []) + TV_POLICY_CHOICES,
		"getter":func(): return 0 if current else TV_POLICIES.find(data.game_tv_policy),
		"setter":func(value):
			if int(value) >= offset:
				set_tv_policy(TV_POLICIES[int(value) - offset])
				if host.menu.mode == "welcome": host.menu.welcome.keep_display_preferences = false
				host.menu.refresh(),
		"help":"Keeps existing console and game preferences. Choose another option to change the starting TV for consoles." if current else TV_POLICY_HELP[TV_POLICIES.find(data.game_tv_policy)]}

func video_tv_row(id: String) -> Dictionary:
	return {"id":id,"label":"TV for videos","kind":"choice","choices":["Wide TV (16:9)", "Standard TV (4:3)"],"visual":false,"value_width":260,
		"getter":func(): return 0 if data.defaults.video == "wide" else 1,
		"setter":func(value):
			data.defaults.video = "wide" if int(value) == 0 else "standard"
			if kind == "video": refresh_screen()
			host.menu.refresh(),
		"help":"Chooses the video TV cabinet independently of games. Its ratio describes the TV screen; each video keeps its own shape and fitting."}

func read(config: ConfigFile) -> void:
	var saved = config.get_value("display_profiles","data",{})
	var last = saved.get("last_screen", "") if saved is Dictionary else ""
	data.last_screen = last if last in ["standard","wide"] else ("wide" if bool(config.get_value("room","widescreen",false)) else "standard")
	if saved is Dictionary and int(saved.get("version",0)) == 1:
		var policy: String = str(saved.get("game_tv_policy", "custom"))
		data.game_tv_policy = policy if policy in TV_POLICIES else "custom"
		data.legacy_tv_seeds = saved.get("legacy_tv_seeds", not saved.has("game_tv_policy")) == true
		data["legacy_import"]=saved.get("legacy_import",true) if saved.get("legacy_import",true) is bool else true
		for key in ["defaults","platforms","games","videos","views","pictures","migrated","looks","look_for"]:
			if saved.get(key) is Dictionary: data[key]=saved[key].duplicate(true)
	elif not initialized:
		data.defaults.game="wide" if bool(config.get_value("room","widescreen",false)) else "standard"
		if not config.get_sections().is_empty(): data.game_tv_policy = "custom"
	for activity in ["game","video"]:
		if data.defaults.get(activity,"") not in ["standard","wide"]: data.defaults[activity]="wide" if activity=="video" else "standard"
	for group in ["platforms","games","videos"]:
		for id in data[group].keys():
			var item = data[group][id]
			if not item is Dictionary: data[group].erase(id)
			elif item.get("screen","") not in ["standard","wide"]: item.erase("screen")
	data.platform_defaults_version=saved.get("platform_defaults_version",0) if saved is Dictionary else 0
	# Never re-seed console overrides on load: a chosen policy also covers future consoles.
	initialized=true

func screen_id() -> String:
	return "wide" if host.world.widescreen else "standard"

func device_id() -> String:
	return "xr" if host.provider.real else "desktop"

func entry(group: String, id: String) -> Dictionary:
	var item = data[group].get(id,{})
	return item if item is Dictionary else {}

func preferred_screen(for_kind: String, platform: String, id: String) -> String:
	var result: String = str(data.defaults.get(for_kind,"standard"))
	if for_kind == "game" and data.get("game_tv_policy", "custom") == "console": result = "wide" if platform in WIDE_TV_PLATFORMS else "standard"
	if for_kind == "game": result=str(entry("platforms",platform).get("screen",result))
	result=str(entry("games" if for_kind=="game" else "videos",id).get("screen",result))
	return result if result in ["standard","wide"] else "standard"

func set_preference(group: String, id: String, screen: String) -> void:
	var item:=entry(group,id).duplicate(true)
	if screen.is_empty(): item.erase("screen")
	else: item.screen=screen
	if item.is_empty(): data[group].erase(id)
	else: data[group][id]=item

func live_picture() -> Dictionary:
	var result := {}
	for key in host.SettingsDefaults.PICTURE: result["crt."+key]=host.get(key)
	for key in host.world.picture.values: result["picture."+key]=host.world.picture.values[key]
	for key in ["keep_aspect","fit_mode","aspect_override","mode"]: result["picture."+key]=host.world.picture.get(key)
	return result

func base_into(config: ConfigFile) -> void:
	if base.is_empty(): return
	var names: Dictionary={"phosphor_mask":"mask","phosphor_glow":"glow","glass_reflections":"glass","screen_curvature":"curvature"}
	for key in base:
		var parts: PackedStringArray=key.split(".",true,1)
		var field: String=parts[1]
		if parts[0]=="crt": field=names.get(field,field)
		elif field=="mode": field="connection"
		config.set_value(parts[0],field,base[key])

func apply_picture(values: Dictionary) -> void:
	for field in host.SettingsDefaults.PICTURE:
		var value = values.get("crt."+field)
		if value is float or value is int:
			var limit: float={"scanlines":.7,"phosphor_mask":.5,"phosphor_glow":.4,"glass_reflections":.4}.get(field,1.0)
			if is_finite(float(value)): host.set(field,clampf(float(value),0,limit))
	for field in host.world.picture.all_fields():
		var value = values.get("picture."+field[0])
		if value is float or value is int:
			if is_finite(float(value)): host.world.picture.values[field[0]]=clampf(float(value),field[2],field[3])
	for key in ["keep_aspect","fit_mode","aspect_override","mode"]:
		var value = values.get("picture."+key)
		if key=="keep_aspect":
			if value is bool: host.world.picture.keep_aspect=value
		elif value is int or value is float:
			if is_finite(float(value)): host.world.picture.set(key,clampi(int(value),0,1 if key=="fit_mode" else (3 if key=="mode" else 2)))
	host.world.screen_material.set_shader_parameter("scanlines",host.scanlines)
	host.world.screen_material.set_shader_parameter("mask_strength",host.phosphor_mask)
	host.world.screen_material.set_shader_parameter("glow_strength",host.phosphor_glow)
	host.world.glass_material.set_shader_parameter("reflection_strength",host.glass_reflections)
	host.world.set_curvature(host.screen_curvature)
	host.world.picture.refresh()

func picture_keys() -> Array[String]:
	var prefix:=kind+"."+screen_id()+"."
	var keys: Array[String]=[prefix+"screen"]
	if not editing_look.is_empty():
		keys.append("look."+editing_look)
		return keys
	if kind=="game" and not system.is_empty() and scope!=2:
		var console_look := look_for_console(system)
		if not console_look.is_empty(): keys.append("look."+console_look)
		keys.append(prefix+"platform."+system)
	if not content.is_empty() and scope==0:
		var game_look := look_for_game(content, host.emulator.rom_path if kind=="game" else "")
		if not game_look.is_empty(): keys.append("look."+game_look)
		keys.append(prefix+"content."+content)
	return keys

# ── Looks ───────────────────────────────────────────────────────────────────

func looks() -> Dictionary:
	if not data.get("looks") is Dictionary: data.looks = {}
	return data.looks

func look_links() -> Dictionary:
	if not data.get("look_for") is Dictionary: data.look_for = {}
	return data.look_for

func look_exists(id: String) -> bool:
	return not id.is_empty() and looks().has(id) and data.pictures.get("look."+id) is Dictionary

func look_name(id: String) -> String:
	var item = looks().get(id, {})
	return str(item.get("name", "Look")) if item is Dictionary else "Look"

## Looks in name order, as [id, name] pairs.
func look_list() -> Array:
	var result: Array = []
	for id in looks():
		if look_exists(id): result.append([id, look_name(id)])
	result.sort_custom(func(a, b): return str(a[1]).naturalnocasecmp_to(str(b[1])) < 0)
	return result

func look_for_console(platform: String) -> String:
	var id := str(look_links().get("platform."+platform, ""))
	return id if look_exists(id) else ""

func look_for_game(hash: String, path := "") -> String:
	var id := str(look_links().get("game."+hash, "")) if not hash.is_empty() else ""
	if not look_exists(id) and not path.is_empty(): id = str(look_links().get("path."+path, ""))
	return id if look_exists(id) else ""

## The fields a look carries: the tube, colour and signal, never the fitting,
## which belongs to each game's shape and the TV it plays on.
func look_fields() -> Array[String]:
	var fit: Array = ["picture.keep_aspect","picture.fit_mode","picture.aspect_override"]
	for field in host.world.picture.FIT_FIELDS: fit.append("picture."+str(field[0]))
	var result: Array[String] = []
	for key in live_picture():
		if not key in fit: result.append(key)
	return result

func look_values_from(values: Dictionary) -> Dictionary:
	var result := {}
	for key in look_fields():
		if values.has(key): result[key] = values[key]
	return result

func new_look_id() -> String:
	var id := "l%d" % Time.get_unix_time_from_system()
	var n := 0
	while looks().has(id if n == 0 else "%s_%d" % [id, n]): n += 1
	return id if n == 0 else "%s_%d" % [id, n]

## A new look holding the picture on screen now. Returns its id.
func create_look(name: String, values := {}) -> String:
	commit()
	var id := new_look_id()
	looks()[id] = {"name": clean_look_name(name)}
	data.pictures["look."+id] = look_values_from(values if not values.is_empty() else live_picture())
	return id

static func clean_look_name(name: String) -> String:
	var title := name.strip_edges().left(32)
	return title if not title.is_empty() else "My look"

func rename_look(id: String, name: String) -> void:
	if looks().has(id): looks()[id]["name"] = clean_look_name(name)

func duplicate_look(id: String) -> String:
	if not look_exists(id): return ""
	return create_look((look_name(id) + " copy").left(32), data.pictures["look."+id])

## Removes a look; consoles and games that used it go back to their own picture.
func delete_look(id: String) -> void:
	if editing_look == id: end_look_edit()
	commit()
	looks().erase(id)
	data.pictures.erase("look."+id)
	for key in look_links().keys():
		if str(look_links()[key]) == id: look_links().erase(key)
	resolve_picture()

## Links a console ("platform.snes"), a game ("game.<hash>") or a ROM path
## ("path.<path>") to a look; an empty id unlinks it.
func link_look(target: String, id: String) -> void:
	commit()
	if id.is_empty(): look_links().erase(target)
	else: look_links()[target] = id
	resolve_picture()

## The loaded game's link key: by content, which survives renaming the file.
func game_link_key() -> String:
	return "game."+content if not content.is_empty() else ""

func look_usage(id: String) -> Dictionary:
	var consoles: Array = []
	var games := 0
	for key in look_links():
		if str(look_links()[key]) != id: continue
		if str(key).begins_with("platform."): consoles.append(str(key).trim_prefix("platform."))
		else: games += 1
	return {"consoles": consoles, "games": games}

## Edit a look itself: the Picture tabs then change the look, and so every game
## using it, until end_look_edit (or the menu closes).
func begin_look_edit(id: String) -> void:
	if not look_exists(id): return
	commit()
	editing_look = id
	applied.clear()
	resolve_picture()

func end_look_edit() -> void:
	if editing_look.is_empty(): return
	commit()
	editing_look = ""
	applied.clear()
	resolve_picture()

## A short text that carries a look to another CRT XR: name and values only.
func look_share_code(id: String) -> String:
	if not look_exists(id): return ""
	var payload := {"name": look_name(id), "values": data.pictures["look."+id]}
	return LOOK_SHARE_PREFIX + Marshalls.utf8_to_base64(JSON.stringify(payload))

## Adds a look from a share code. Unknown fields and values that are not
## numbers or switches are dropped. Returns its id, or "" if the code is not a look.
func import_look(code: String) -> String:
	var text := code.strip_edges()
	var at := text.find(LOOK_SHARE_PREFIX)
	if at < 0: return ""
	var rest := text.substr(at + LOOK_SHARE_PREFIX.length()).strip_edges()
	var words := rest.split(" ", false)
	if words.is_empty(): return ""
	text = words[0]
	var parsed = JSON.parse_string(Marshalls.base64_to_utf8(text))
	if not parsed is Dictionary or not parsed.get("values") is Dictionary: return ""
	var known := live_picture()
	var values := {}
	for key in parsed.values:
		var value = parsed.values[key]
		if not known.has(key) or not str(key) in look_fields(): continue
		if typeof(known[key]) == TYPE_BOOL:
			if value is bool: values[key] = value
		elif (value is float or value is int) and is_finite(float(value)):
			values[key] = int(value) if typeof(known[key]) == TYPE_INT else float(value)
	if values.is_empty(): return ""
	return create_look(str(parsed.get("name", "Shared look")), values)

func resolve_picture() -> void:
	if busy: return
	if base.is_empty(): base=live_picture()
	var values:=base.duplicate(true)
	if kind=="video": values["picture.mode"]=3
	for key in picture_keys():
		var patch = data.pictures.get(key,{})
		if patch is Dictionary: values.merge(patch,true)
	apply_picture(values)
	applied=live_picture()

func inherited_value(id: String, fallback: Variant) -> Variant:
	var value = base.get(id,fallback)
	var keys:=picture_keys()
	keys.pop_back()
	for key in keys:
		var patch = data.pictures.get(key,{})
		if patch is Dictionary: value=patch.get(id,value)
	if (value is float or value is int) and not is_finite(float(value)): return fallback
	return value if typeof(value)==typeof(fallback) or (value is float or value is int) and (fallback is float or fallback is int) else fallback

func target_key() -> String:
	var keys:=picture_keys()
	return keys[-1]

func commit() -> void:
	if busy or applied.is_empty(): return
	var current:=live_picture()
	var stored = data.pictures.get(target_key(),{})
	var patch: Dictionary=stored.duplicate(true) if stored is Dictionary else {}
	for key in current:
		if current[key] != applied.get(key): patch[key]=current[key]
	if target_key().begins_with("look."):
		# A look never carries fitting: that stays with each game and TV.
		var fitting: Array = []
		for key in patch:
			if not key in look_fields(): fitting.append(key)
		for key in fitting: patch.erase(key)
	if not patch.is_empty(): data.pictures[target_key()]=patch
	applied=current

func set_scope(value: int) -> void:
	commit()
	scope=clampi(value,0,2)
	resolve_picture()

func inherit_picture() -> void:
	data.pictures.erase(target_key())
	resolve_picture()

func context_label() -> String:
	if not editing_look.is_empty(): return "Look · " + look_name(editing_look)
	var screen: String="Wide" if host.world.widescreen else "Standard"
	if scope==2 or content.is_empty() and system.is_empty(): return "%s TV · %s defaults" % [screen,kind]
	if scope==1: return "%s · %s defaults" % [screen,system.to_upper()]
	return "%s TV · %s" % [screen,"This video" if kind=="video" else "This game"]

func field_source(field: String) -> String:
	var current := live_picture()
	if current.get(field) != applied.get(field): return "Custom at this scope"
	var patch = data.pictures.get(target_key(), {})
	if patch is Dictionary and patch.has(field): return "Custom at this scope"
	var keys := picture_keys()
	keys.pop_back()
	keys.reverse()
	for key in keys:
		var parent = data.pictures.get(key, {})
		if parent is Dictionary and parent.has(field):
			if key.begins_with("look."): return "Using look"
			return "Using console default" if ".platform." in key else "Using TV default"
	return "Using TV default" if scope != 2 and not content.is_empty() else "Using app default"

func save_view() -> void:
	data.views[device_id()+"."+screen_id()]={"distance":host.distance,"height_offset":host.height_offset,"tv_scale":host.tv_scale}

func restore_view() -> void:
	var id:=device_id()+"."+screen_id()
	var standard = data.views.get(device_id()+".standard",{})
	var fallback: Dictionary={"distance":host.distance,"height_offset":host.height_offset,"tv_scale":host.tv_scale}
	if standard is Dictionary: fallback.merge(standard,true)
	for field in fallback:
		if not (fallback[field] is float or fallback[field] is int) or not is_finite(float(fallback[field])): fallback[field]=host.get(field)
	if screen_id()=="wide" and not data.views.has(id) and standard is Dictionary and not standard.is_empty(): fallback.distance=clampf(float(fallback.distance)*4.0/3.0,1.2,5)
	var values = data.views.get(id,fallback)
	if not values is Dictionary: values=fallback
	for field in [["distance",1.2,5],["height_offset",-1.5,1.5],["tv_scale",.5,1.6]]:
		var value = values.get(field[0],fallback.get(field[0]))
		if (value is float or value is int) and is_finite(float(value)): host.set(field[0],clampf(float(value),field[1],field[2]))
	save_view()

func leave_context() -> void:
	if busy: return
	commit()
	if not base.is_empty(): apply_picture(base)
	applied.clear();base.clear()

func begin_context(active: bool, key: String) -> void:
	if busy: return
	applied.clear();base.clear()
	kind="video" if active and key==host.VIDEO_PROFILE else "game"
	system=host.emulator.system_id if active and kind=="game" else ""
	content=host.video.path.sha256_text() if active and kind=="video" and not host.video.path.is_empty() else (host.emulator.rom_hash if active and kind=="game" else "")
	scope=0
	var desired:=preferred_screen(kind,system,content)=="wide"
	busy=true
	host._switch_cabinet(desired)
	busy=false
	if active: data.last_screen=screen_id()

func choose_screen(enabled: bool) -> void:
	leave_context()
	var selected: String="wide" if enabled else "standard"
	if scope==0 and not content.is_empty(): set_preference("games" if kind=="game" else "videos",content,selected)
	elif scope==1 and kind=="game" and not system.is_empty(): set_preference("platforms",system,selected)
	else:
		data.defaults[kind]=selected
		if kind == "game": data.game_tv_policy = selected
	busy=true
	host._switch_cabinet(enabled)
	busy=false
	if scope==0 and (not content.is_empty() or kind=="game"): data.last_screen=screen_id()
	base=live_picture();applied.clear()
	migrate_picture()
	resolve_picture()

func display_choice() -> int:
	var picture=host.world.picture
	return (3 if host.world.widescreen else 0)+(picture.fit_mode if picture.keep_aspect else 2)

func choose_display(value: int) -> void:
	value=clampi(value,0,DISPLAY_CHOICES.size()-1)
	# Quick Display always edits the current programme, even after previewing a
	# platform's settings. Restore the selected TV before applying its fitting.
	set_scope(0)
	choose_screen(value>=3)
	var fitting:=value%3
	host.world.picture.keep_aspect=fitting!=2
	host.world.picture.fit_mode=1 if fitting==1 else 0
	host.world.picture.refresh()
	commit()
	# Selecting a combined mode is an explicit fitting choice, including when
	# it currently matches an inherited default that may change in the future.
	var stored=data.pictures.get(target_key(),{})
	var patch:Dictionary=stored.duplicate(true) if stored is Dictionary else {}
	patch["picture.keep_aspect"]=fitting!=2
	patch["picture.fit_mode"]=1 if fitting==1 else 0
	data.pictures[target_key()]=patch

func set_platform_screen(platform: String, value: int) -> void:
	set_preference("platforms",platform,["","standard","wide"][clampi(value,0,2)])
	if platform==system: refresh_screen()

func inherit_screen() -> void:
	if not content.is_empty(): set_preference("games" if kind=="game" else "videos",content,"")
	refresh_screen()

func restore_last_screen() -> void:
	# Startup is not a new game's launch. Keep the previous cabinet and its view,
	# independently of the default TV that the next game/video will inherit.
	leave_context();busy=true
	host._switch_cabinet(data.last_screen=="wide")
	busy=false
	base=live_picture();applied.clear();migrate_picture();resolve_picture()

func refresh_screen() -> void:
	leave_context();busy=true
	host._switch_cabinet(preferred_screen(kind,system,content)=="wide")
	busy=false
	if scope==0 and not content.is_empty(): data.last_screen=screen_id()
	base=live_picture();applied.clear();migrate_picture();resolve_picture()

func finish_edit() -> void:
	end_look_edit()
	commit()
	if kind=="video" and not host.video.loaded and not host.emulator.loaded:
		leave_context();kind="game";system="";content="";scope=0;refresh_screen()
		return
	if scope!=0: scope=0;refresh_screen()

## Import existing cabinet/game files once, without changing or deleting them.
func migrate_picture() -> void:
	if not data.get("legacy_import",true): return
	var marker:=kind+"."+screen_id()+"."+(content if kind=="game" else "legacy")
	var migrated: Dictionary=data.get("migrated",{})
	if migrated.has(marker): return
	migrated[marker]=true;data.migrated=migrated
	if kind=="game" and (content.is_empty() or not host.remember_game_picture): return
	var key: String=host.VIDEO_PROFILE if kind=="video" else content
	var file: String=host.game_picture_path(key)
	var target:=kind+"."+screen_id()+"."+("screen" if kind=="video" else "content."+content)
	if data.pictures.has(target): return
	var patch: Dictionary={}
	if kind=="video" and not host.video_own_picture:
		data.pictures[target]={"picture.mode":base.get("picture.mode",host.Showcase.CONNECTION)}
		return
	if FileAccess.file_exists(file) or FileAccess.file_exists(file+".bak"):
		var config: ConfigFile=host.SettingsStore.new().read(file)
		var names: Dictionary={"mask":"phosphor_mask","glow":"phosphor_glow","glass":"glass_reflections","curvature":"screen_curvature","connection":"mode"}
		for section in ["crt","picture"]:
			if not config.has_section(section): continue
			for field in config.get_section_keys(section):
				var name: String=names.get(field,field)
				var id: String=section+"."+name
				var inherited = 3 if kind=="video" and id=="picture.mode" else base.get(id)
				if base.has(id) and inherited!=config.get_value(section,field): patch[id]=config.get_value(section,field)
	elif kind=="video" and host.video_own_picture: patch["picture.mode"]=3
	if not patch.is_empty(): data.pictures[target]=patch

func reset_field(id: String) -> void:
	reset_fields([id])

func reset_fields(ids: Array) -> void:
	commit()
	var stored = data.pictures.get(target_key(),{})
	var patch: Dictionary=stored.duplicate(true) if stored is Dictionary else {}
	for id in ids: patch.erase(id)
	data.pictures[target_key()]=patch
	resolve_picture()
