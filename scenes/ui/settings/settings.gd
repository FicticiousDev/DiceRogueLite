extends CanvasLayer
class_name SettingsScene

## Autoloaded settings menu. Saved settings are applied on startup by SettingsOptions.
## Call Settings.show_settings() from any scene.

@onready var menu: ColorRect = $Menu
@onready var mouse_blocker: ColorRect = $MouseBlocker

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_settings() -> void:
	# Set pivot to centre of the menu so it scales from the middle
	menu.pivot_offset = menu.size / 2.0

	menu.visible = true
	mouse_blocker.visible = true

	# Kill any running tween to avoid conflicts
	if _tween:
		_tween.kill()

	# Start from invisible & scaled-down
	menu.modulate.a = 0.0
	menu.scale = Vector2(0.7, 0.7)

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(menu, "modulate:a", 1.0, Anim.t(0.35)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(menu, "scale", Vector2(1.0, 1.0), Anim.t(0.25)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func hide_settings() -> void:
	# Set pivot to centre of the menu so it scales from the middle
	menu.pivot_offset = menu.size / 2.0

	# Kill any running tween to avoid conflicts
	if _tween:
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(menu, "modulate:a", 0.0, Anim.t(0.2)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(menu, "scale", Vector2(0.0, 0.0), Anim.t(0.2)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	# Wait for the tween to finish before hiding
	await _tween.finished
	menu.visible = false
	mouse_blocker.visible = false


func is_open() -> bool:
	return menu.visible


func _on_done_button_pressed():
	SaveManager.save_data()
	hide_settings()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_on_done_button_pressed()
