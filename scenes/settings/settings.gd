extends CanvasLayer
class_name SettingsScene

@onready var menu = $Menu

var _tween: Tween


func show_settings() -> void:
	# Set pivot to centre of the menu so it scales from the middle
	menu.pivot_offset = menu.size / 2.0

	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Kill any running tween to avoid conflicts
	if _tween:
		_tween.kill()

	# Start from invisible & scaled-down
	menu.modulate.a = 0.0
	menu.scale = Vector2(0.7, 0.7)

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(menu, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(menu, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func hide_settings() -> void:
	# Set pivot to centre of the menu so it scales from the middle
	menu.pivot_offset = menu.size / 2.0

	# Kill any running tween to avoid conflicts
	if _tween:
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(menu, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(menu, "scale", Vector2(0.0, 0.0), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	# Wait for the tween to finish before hiding the layer
	await _tween.finished
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _on_done_button_pressed():
	SaveManager.save_data()
	hide_settings()
