class_name BlockAttackAbility
extends Ability

## Active: fully blocks one hit, chosen from the block prompt when the player is hit.


func _init() -> void:
	active = true
	use = Use.BLOCK
