class_name TurnOrderPrompt
extends CanvasLayer

## Round button on the right edge of the screen, level with the dice row, that lets the enemies take their turn before
## the player's. Shown through the round; greyed out whenever it can't be used (see
## [method TurnController._refresh_controls]).

signal pressed

const ICON_PATH: String = "res://assets/ui/icons/enemies_first.png"
const MARGIN: float = 28.0

## Height of the dice row as a fraction of the screen (DiceTray.row_screen_y)
var row_y: float = 0.91

var _button: CircleButton
var _icon: Texture2D


func _ready() -> void:
	UITheme.watch(self)
	_icon = load(ICON_PATH)
	_button = CircleButton.create(_icon)
	_button.pressed.connect(pressed.emit)
	add_child(_button)
	get_viewport().size_changed.connect(_place)
	visible = false


## Shows the button (popping in if it was hidden), usable or greyed out.
func show_button(usable: bool) -> void:
	_button.disabled = not usable
	var rows: Array[Dictionary] = [InfoPanel.row(_icon, Color.WHITE, tr("TIP_ENEMIES_FIRST"))]
	if not usable:
		rows.append(InfoPanel.row(_icon, CircleButton.ICON_DISABLED, tr("TIP_ENEMIES_FIRST_UNAVAILABLE")))
	_button.set_info(tr("BTN_ENEMIES_FIRST"), rows)
	if visible:
		return
	visible = true
	_place()
	_button.scale = Vector2.ONE * 0.6
	_button.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_button, "scale", Vector2.ONE, Anim.t(0.35)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_button, "modulate:a", 1.0, Anim.t(0.15))


func hide_button() -> void:
	visible = false


## Right edge of the screen, centred on the dice row.
func _place() -> void:
	var screen := get_viewport().get_visible_rect().size
	var size := _button.custom_minimum_size
	_button.position = Vector2(screen.x - MARGIN - size.x, screen.y * row_y - size.y / 2.0)
