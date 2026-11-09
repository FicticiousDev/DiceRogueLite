class_name SacrificeDialog
extends CanvasLayer

## Last stand prompt: pick a die from the pool to sacrifice, or accept defeat. Each die is a card that can be turned
## or clicked for its six faces.
## Use: var index: int = await dialog.ask(SaveManager.run_data.dice)  (-1 = no sacrifice)

signal answered(index: int)

@onready var panel: PanelContainer = %Panel
@onready var dice_list: GridContainer = %DiceList
@onready var give_up_button: Button = %GiveUpButton

const COLUMNS: int = 5
const VIEW_SIZE: float = 96.0

var _tween: Tween


func _ready() -> void:
	give_up_button.pressed.connect(answered.emit.bind(-1))
	InputMode.register_menu(self, _entry)
	ButtonPrompt.footer(self, ButtonPrompt.standard("Select", ""))


## The first die's button; giving up is never the default.
func _entry() -> Control:
	for card in dice_list.get_children():
		if card is DieCard and card.button and not card.is_queued_for_deletion():
			return card.button
	return give_up_button


func ask(dice_ids: Array[String]) -> int:
	for child in dice_list.get_children():
		child.queue_free()
	dice_list.columns = COLUMNS
	for i in dice_ids.size():
		var card := DieCard.create(Database.get_content("dice", dice_ids[i]), VIEW_SIZE, "SACRIFICE")
		card.button_pressed.connect(answered.emit.bind(i))
		dice_list.add_child(card)

	visible = true
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * 0.7
	panel.modulate.a = 0.0
	_animate(Vector2.ONE, 1.0, Tween.TRANS_ELASTIC, Tween.EASE_OUT, 0.35)
	var index: int = await answered
	_animate(Vector2.ONE * 0.7, 0.0, Tween.TRANS_BACK, Tween.EASE_IN, 0.2)
	await _tween.finished
	visible = false
	return index


func _animate(target_scale: Vector2, alpha: float, trans: Tween.TransitionType, easing: Tween.EaseType, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "scale", target_scale, Anim.t(duration)).set_trans(trans).set_ease(easing)
	_tween.tween_property(panel, "modulate:a", alpha, Anim.t(duration * 0.6))
