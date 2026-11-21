class_name BlockPrompt
extends CanvasLayer

## Centre-screen prompt when an enemy's attack lands in the enemy turn: block with held defence dice or take
## the hit. Block actives that can answer the hit are named here and used from their buttons beside the dice row
## (AbilityBar). Doesn't block the mouse, so dice in the row and the ability buttons can still be clicked.

signal block_pressed
signal take_pressed

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %Title
@onready var damage_label: Label = %Damage
@onready var hint_label: Label = %Hint
@onready var block_button: Button = %BlockButton
@onready var take_button: Button = %TakeButton


func _ready() -> void:
	block_button.pressed.connect(block_pressed.emit)
	take_button.pressed.connect(take_pressed.emit)


## [abilities] name the block actives the player can use instead.
func show_prompt(attacker: String, damage: int, abilities: Array = []) -> void:
	title_label.text = tr("BLOCK_TITLE") % attacker.to_upper()
	damage_label.text = tr("BLOCK_DAMAGE") % damage
	hint_label.text = tr("BLOCK_INSTRUCTIONS")
	if abilities.size() > 0:
		hint_label.text += "\n" + tr("BLOCK_ABILITY_HINT") % ", ".join(PackedStringArray(abilities))
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
	block_button.text = tr("BLOCK_BUTTON_VALUE") % AttackContext.value_text(value) if value > 0 else tr("BLOCK_BUTTON")


func hide_prompt() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE * 0.7, Anim.t(0.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, Anim.t(0.15))
	await tween.finished
	visible = false
