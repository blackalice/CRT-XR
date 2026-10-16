extends RefCounted
static func page(app, category: int, subsection := 0) -> void:
	if not app.menu.visible: app.toggle_settings()
	app.menu.open_settings()
	app.menu.category=category; app.menu.subsection=subsection; app.menu.render()

static func select(app, id: String) -> Dictionary:
	for category in range(app.menu.CATEGORIES.size()):
		var pages: Array = app.menu.catalog.pages(category)
		for section in range(pages.size()):
			for item in pages[section].rows:
				if item.id==id:
					page(app,category,section)
					app.menu.select(id)
					return item
	push_error("Unknown menu option: "+id)
	return {}

static func set_value(app, id: String, value) -> void:
	var item := select(app,id)
	item.setter.call(value)
	app.menu.selected_row().refresh()

static func get_value(app, id: String):
	return select(app,id).getter.call()

static func reset(app, id: String) -> void:
	select(app,id)
	app.menu.reset_option()
