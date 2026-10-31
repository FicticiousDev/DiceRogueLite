class_name SacrificeDialog
extends CanvasLayer

## Last stand prompt: pick a die from the pool to sacrifice, or accept defeat.
## Use: var index: int = await dialog.ask(SaveManager.run_data.dice)  (-1 = no sacrifice)

signal answered(index: int)

@onready var panel: PanelContainer = %Panel
@onready var dice_list: GridContainer = %DiceList
@onready var give_up_button: Button = %GiveUpButton

var _tween: Tween


func _ready() -> void:
	give_up_button.pressed.connect(answered.emit.bind(-1))


func ask(dice_ids: Array[String]) -> int:
	for child in dice_list.get_children():
		child.queue_free()
	for i in dice_ids.size():
		var type: DieType = Database.get_content("dice", dice_ids[i])
		var button := Button.new()
		button.text = type.display_name
		button.custom_minimum_size = Vector2(200, 52)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Rarity.COLORS[type.rarity])
		button.tooltip_text = "\n".join(type.faces.map(func(f: DieFace): return f.describe()))
		button.pressed.connect(answered.emit.bind(i))
		dice_list.add_child(button)

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
