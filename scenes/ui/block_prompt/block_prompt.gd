class_name BlockPrompt
extends CanvasLayer

## Centre-screen prompt when an enemy's attack lands in the enemy turn: block with held defence dice or take
## the hit. Doesn't block the mouse, so dice in the row can still be clicked.

signal block_pressed
signal take_pressed

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %Title
@onready var damage_label: Label = %Damage
@onready var block_button: Button = %BlockButton
@onready var take_button: Button = %TakeButton


func _ready() -> void:
	block_button.pressed.connect(block_pressed.emit)
	take_button.pressed.connect(take_pressed.emit)


func show_prompt(attacker: String, damage: int) -> void:
	title_label.text = "%s ATTACKS!" % attacker.to_upper()
	damage_label.text = "Hits you for %d damage.\nBlock or take it?" % damage
	set_block_value(0)
	visible = true
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * 0.6
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, Anim.t(0.4)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, Anim.t(0.2))


## Total defence of the selected dice; BLOCK is only available once some are selected.
func set_block_value(value: int) -> void:
	block_button.disabled = value <= 0
	block_button.text = "BLOCK %d" % value if value > 0 else "BLOCK"


func hide_prompt() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE * 0.7, Anim.t(0.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, Anim.t(0.15))
	await tween.finished
	visible = false
