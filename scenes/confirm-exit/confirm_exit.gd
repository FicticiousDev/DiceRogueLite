extends CanvasLayer
class_name ConfirmExit

signal exit_confirmed
signal cancel_exit


@onready var confirm_button: TextureButton = $Panel/Confirm
@onready var cancel_button: TextureButton = $Panel/Cancel
@onready var panel: Panel = $Panel

var _tween: Tween


func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)


func _on_confirm_button_pressed() -> void:
	exit_confirmed.emit()


func _on_cancel_button_pressed() -> void:
	cancel_exit.emit()


func show_confirmation() -> void:
	# Set pivot to centre of the menu so it scales from the middle
	panel.pivot_offset = panel.size / 2.0

	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Kill any running tween to avoid conflicts
	if _tween:
		_tween.kill()

	# Start from invisible & scaled-down
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.7, 0.7)

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func hide_confirmation() -> void:
	# Set pivot to centre of the menu so it scales from the middle
	panel.pivot_offset = panel.size / 2.0

	# Kill any running tween to avoid conflicts
	if _tween:
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(panel, "scale", Vector2(0.0, 0.0), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	# Wait for the tween to finish before hiding the layer
	await _tween.finished
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED