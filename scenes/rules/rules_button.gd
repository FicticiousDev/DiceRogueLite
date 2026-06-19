extends Area3D

signal rules_pressed


func _on_input_event(_camera, event, _position, _normal, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		emit_signal("rules_pressed")
