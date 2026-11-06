extends RefCounted
## Display policy and sparse picture overrides. Runtime menu previews never
## become hardware calibration or another programme's inherited defaults.
var host: Node
var data: Dictionary = {"version":1,"defaults":{"game":"standard","video":"wide"},"platforms":{},"games":{},"videos":{},"views":{},"pictures":{}}
var initialized := false
var kind := "game"
var system := ""
var content := ""
var scope := 0 # This programme, platform, TV default
var base: Dictionary = {}
var applied: Dictionary = {}
var busy := false

func read(config: ConfigFile) -> void:
	var saved = config.get_value("display_profiles","data",{})
	if saved is Dictionary and int(saved.get("version",0)) == 1:
		data["legacy_import"]=saved.get("legacy_import",true) if saved.get("legacy_import",true) is bool else true
		for key in ["defaults","platforms","games","videos","views","pictures","migrated"]:
			if saved.get(key) is Dictionary: data[key]=saved[key].duplicate(true)
	elif not initialized:
		data.defaults.game="wide" if bool(config.get_value("room","widescreen",false)) else "standard"
		data.platforms.psp={"screen":"wide"}
		data.platforms.wii={"screen":"wide"}
	for activity in ["game","video"]:
		if data.defaults.get(activity,"") not in ["standard","wide"]: data.defaults[activity]="wide" if activity=="video" else "standard"
	for group in ["platforms","games","videos"]:
		for id in data[group].keys():
			var item = data[group][id]
			if not item is Dictionary: data[group].erase(id)
			elif item.get("screen","") not in ["standard","wide"]: item.erase("screen")
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
	if kind=="game" and not system.is_empty() and scope!=2: keys.append(prefix+"platform."+system)
	if not content.is_empty() and scope==0: keys.append(prefix+"content."+content)
	return keys

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
	var screen: String="Wide" if host.world.widescreen else "Standard"
	if scope==2 or content.is_empty() and system.is_empty(): return "%s TV · %s defaults" % [screen,kind]
	if scope==1: return "%s · %s defaults" % [screen,system.to_upper()]
	return "%s TV · %s" % [screen,"This video" if kind=="video" else "This game"]

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

func choose_screen(enabled: bool) -> void:
	leave_context()
	var selected: String="wide" if enabled else "standard"
	if scope==0 and not content.is_empty(): set_preference("games" if kind=="game" else "videos",content,selected)
	elif scope==1 and kind=="game" and not system.is_empty(): set_preference("platforms",system,selected)
	else: data.defaults[kind]=selected
	busy=true
	host._switch_cabinet(enabled)
	busy=false
	base=live_picture();applied.clear()
	migrate_picture()
	resolve_picture()

func set_platform_screen(platform: String, value: int) -> void:
	set_preference("platforms",platform,["","standard","wide"][clampi(value,0,2)])
	if platform==system: refresh_screen()

func inherit_screen() -> void:
	if not content.is_empty(): set_preference("games" if kind=="game" else "videos",content,"")
	refresh_screen()

func refresh_screen() -> void:
	leave_context();busy=true
	host._switch_cabinet(preferred_screen(kind,system,content)=="wide")
	busy=false
	base=live_picture();applied.clear();migrate_picture();resolve_picture()

func finish_edit() -> void:
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
