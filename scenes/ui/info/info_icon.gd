class_name InfoIcon
extends TextureRect

## An icon with a [Tooltip] (title + explained rows).


func set_info(title: String, rows: Array[Dictionary] = []) -> void:
	Tooltip.set_info(self, title, rows)


func _make_custom_tooltip(_for_text: String) -> Object:
	return Tooltip.make(self)
