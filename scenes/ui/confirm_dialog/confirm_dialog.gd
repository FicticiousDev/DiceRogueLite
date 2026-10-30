extends CanvasLayer
class_name ConfirmDialog

## Yes/no prompt. Use: if await dialog.ask("Title", "Message"): ...

signal answered(confirmed: bool)

@onready var confirm_button: TextureButton = $Panel/Confirm
@onready var cancel_button: TextureButton = $Panel/Cancel
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Title
@onready var description_label: Label = $Panel/Description

var _tween: Tween


func _ready() -> void:
	confirm_button.pressed.connect(answered.emit.bind(true))
	cancel_button.pressed.connect(answered.emit.bind(false))


## Shows the dialog and returns true if confirmed.
func ask(title: String, description: String) -> bool:
	title_label.text = title
	description_label.text = description
	_show_dialog()
	var confirmed: bool = await answered
	_hide_dialog()
	return confirmed


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		answered.emit(false)


func _show_dialog() -> void:
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
	_tween.tween_property(panel, "modulate:a", 1.0, Anim.t(0.35)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), Anim.t(0.25)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _hide_dialog() -> void:
	panel.pivot_offset = panel.size / 2.0

	if _tween:
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "modulate:a", 0.0, Anim.t(0.2)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(panel, "scale", Vector2(0.0, 0.0), Anim.t(0.2)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	await _tween.finished
	visible = false
