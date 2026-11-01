class_name InfoIcon
extends TextureRect

## An icon whose tooltip is an [InfoPanel] (title + explained rows) rather than plain text.

var info_title: String
var info_rows: Array[Dictionary] = []


func set_info(title: String, rows: Array[Dictionary]) -> void:
	info_title = title
	info_rows = rows
	# Built-in tooltips only open when there's some text
	tooltip_text = title
	mouse_filter = Control.MOUSE_FILTER_PASS


func _make_custom_tooltip(_for_text: String) -> Object:
	return InfoPanel.content(info_title, info_rows)
