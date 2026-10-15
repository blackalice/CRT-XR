extends PanelContainer
var title_label: Label
var detail_label: Label

func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size",28)
	column.add_child(title_label)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail_label)

func describe(title: String, detail: String) -> void:
	title_label.text = title
	detail_label.text = detail
