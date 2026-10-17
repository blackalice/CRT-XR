extends RefCounted
## Copy old app data once; never move it or overwrite existing CRT XR data.
static func migrate(current := "", legacy := "") -> Dictionary:
	if current.is_empty(): current=ProjectSettings.globalize_path("user://").trim_suffix("/")
	if legacy.is_empty(): legacy=current.get_base_dir().path_join("RetroCRT XR")
	var marker := current.path_join("migration-v1.cfg")
	if FileAccess.file_exists(marker) or DirAccess.open(legacy)==null: return {"copied":0,"error":OK}
	var result := copy_folder(legacy,current)
	if result.error==OK:
		var record := ConfigFile.new(); record.set_value("migration","source",legacy)
		record.set_value("migration","copied",result.copied)
		result.error=record.save(marker)
	return result
static func copy_folder(source: String,target: String) -> Dictionary:
	var count := 0
	var error := DirAccess.make_dir_recursive_absolute(target)
	if error!=OK:return {"copied":count,"error":error}
	var directory := DirAccess.open(source)
	if directory==null:return {"copied":count,"error":ERR_CANT_OPEN}
	for name in directory.get_directories():
		if name in ["logs","shader_cache"] or directory.is_link(name):continue
		var result := copy_folder(source.path_join(name),target.path_join(name))
		count+=result.copied
		if result.error!=OK:return {"copied":count,"error":result.error}
	for name in directory.get_files():
		if directory.is_link(name) or name.ends_with(".tmp"):continue
		var destination := target.path_join(name)
		if FileAccess.file_exists(destination):continue
		error=DirAccess.copy_absolute(source.path_join(name),destination)
		if error!=OK:return {"copied":count,"error":error}
		count+=1
	return {"copied":count,"error":OK}
