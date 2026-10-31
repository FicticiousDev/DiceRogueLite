class_name BlockAttackAbility
extends Ability

## Active: aimed at an enemy, fully blocks its next attack (planned like a block-all defence die, or chosen
## from the block prompt in the enemy turn).


func _init() -> void:
	active = true
	use = Use.BLOCK
