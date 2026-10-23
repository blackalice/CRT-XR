extends RefCounted
## The on-screen keyboard for names, paths, radio addresses and searches.
var host: Node
var menu: Control
var caps := false

func focus_entry() -> void:
	if menu.input_kind=="keyboard": menu.rename_field.grab_focus()
	else: menu.rename_field.release_focus()

func text_keys() -> Array:
	var result: Array=[]
	var letters := "abcdefghijklmnopqrstuvwxyz0123456789:/._-\\?=&%#@+~"
	if caps: letters=letters.to_upper()
	for i in range(letters.length()):
		var character := letters.substr(i,1)
		var key: Dictionary = menu.catalog.action("key.%d" % i,character,func(): insert_text(character),"Insert at the cursor.",false,"")
		key.layout="key"; result.append(key)
	for pair in [["space","Space"],["erase","Delete"],["caps","Aa"],["left","←"],["right","→"]]:
		var command: String=pair[0]
		var key: Dictionary = menu.catalog.action("key."+command,pair[1],func(): edit_text(command),"Edit the text above.",false,"")
		key.layout="key"; result.append(key)
	return result

func insert_text(value: String) -> void:
	var field: LineEdit = menu.rename_field
	var start := field.get_selection_from_column() if field.has_selection() else field.caret_column
	var end := field.get_selection_to_column() if field.has_selection() else start
	var available := field.max_length-(field.text.length()-(end-start))
	var inserted := value.left(maxi(0,available))
	field.text=field.text.left(start)+inserted+field.text.substr(end)
	field.caret_column=start+inserted.length()

func edit_text(command: String) -> void:
	var field: LineEdit = menu.rename_field
	match command:
		"space": insert_text(" ")
		"erase": field.delete_char_at_caret()
		"left": field.caret_column=maxi(0,field.caret_column-1)
		"right": field.caret_column=mini(field.text.length(),field.caret_column+1)
		"caps":
			var cursor := field.caret_column
			caps=not caps; menu.remember(); menu.render()
			field.caret_column=cursor

func navigate_keys(next: Vector2i) -> void:
	var keys: Array=menu.rows.filter(func(row): return row.item.get("layout","")=="key")
	var row=menu.selected_row()
	if row==null: return
	if row.item.get("layout","")=="key":
		var index := keys.find(row)
		var target := index+(next.x if next.x!=0 else next.y*10)
		if target>=keys.size() and next.y>0:
			for candidate in menu.rows:
				if candidate.item.get("layout","")!="key": menu.select(candidate.item.id); return
		if target>=0 and target<keys.size(): menu.select(keys[target].item.id)
	elif next.y<0 and not keys.is_empty(): menu.select(keys[-1].item.id)
	elif next.y>0:
		var index: int = menu.rows.find(row)+1
		if index<menu.rows.size(): menu.select(menu.rows[index].item.id)
