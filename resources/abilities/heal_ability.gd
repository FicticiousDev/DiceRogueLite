class_name HealAbility
extends Ability

## Active action: restores [amount] HP (a heal cures poison instead, as every heal does).

@export var amount: int = 2


func _init() -> void:
	active = true
	use = Use.ACTION


func perform(turn: TurnController) -> void:
	await turn.heal_player(amount)
