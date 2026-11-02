class_name StatusImmunityAbility
extends Ability

## Passive: the player can't be stunned and/or poisoned.

@export var stun: bool = true
@export var poison: bool = true


func prevents_status(status: StringName) -> bool:
	return (status == &"stun" and stun) or (status == &"poison" and poison)
