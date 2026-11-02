class_name BlockPrompt
extends CanvasLayer

## Centre-screen prompt when an enemy's attack lands in the enemy turn: block with held defence dice or take
## the hit, or use a block active (one button each). Doesn't block the mouse, so dice in the row can still be clicked.

signal block_pressed
signal take_pressed
## The [index]th block active named in [method show_prompt]
signal ability_pressed(index: int)

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %Title
@onready var damage_label: Label = %Damage
@onready var block_button: Button = %BlockButton
@onready var take_button: Button = %TakeButton
@onready var ability_button: Button = %AbilityButton


func _ready() -> void:
	block_button.pressed.connect(block_pressed.emit)
	take_button.pressed.connect(take_pressed.emit)
	ability_button.visible = false


## [abilities] name the block actives the player can use instead.
func show_prompt(attacker: String, damage: int, abilities: Array = []) -> void:
	for child in ability_button.get_parent().get_children():
		if child.has_meta("ability"):
			child.queue_free()
	for i in abilities.size():
		var button: Button = ability_button.duplicate()
		button.unique_name_in_owner = false
		button.set_meta("ability", true)
		button.visible = true
		button.text = String(abilities[i]).to_upper()
		button.pressed.connect(ability_pressed.emit.bind(i))
		ability_button.add_sibling(button)
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
	block_button.text = "BLOCK %s" % AttackContext.value_text(value) if value > 0 else "BLOCK"


func hide_prompt() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE * 0.7, Anim.t(0.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, Anim.t(0.15))
	await tween.finished
	visible = false
