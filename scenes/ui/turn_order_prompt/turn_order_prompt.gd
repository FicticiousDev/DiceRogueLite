class_name TurnOrderPrompt
extends CanvasLayer

## A button beside the dice row that lets the enemies take their turn before the player's. The controller shows it
## only while the turn is untouched (see [method TurnController._refresh_order_button]).

signal pressed

## Gap between the right-most die and the button, in screen pixels
const GAP: float = 90.0

var _button: Button


func _ready() -> void:
	layer = 40
	_button = Button.new()
	_button.text = tr("BTN_ENEMIES_FIRST")
	_button.tooltip_text = tr("TIP_ENEMIES_FIRST")
	_button.custom_minimum_size = Vector2(220.0, 56.0)
	_button.add_theme_font_size_override("font_size", 22)
	_button.visible = false
	_button.pressed.connect(pressed.emit)
	add_child(_button)


## Shows the button to the right of [row_end], the screen position of the row's last die.
func show_at(row_end: Vector2) -> void:
	_button.position = row_end + Vector2(GAP, -_button.size.y / 2.0)
	if _button.visible:
		return
	_button.visible = true
	_button.pivot_offset = _button.size / 2.0
	_button.scale = Vector2.ONE * 0.6
	_button.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_button, "scale", Vector2.ONE, Anim.t(0.35)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_button, "modulate:a", 1.0, Anim.t(0.15))


func hide_button() -> void:
	_button.visible = false
