extends Control

## Attached by [method Tooltip.set_info] to controls without a script, so their tooltip is an [InfoPanel] too.


func _make_custom_tooltip(_for_text: String) -> Object:
	return Tooltip.make(self)
