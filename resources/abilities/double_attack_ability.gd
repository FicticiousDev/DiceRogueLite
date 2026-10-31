class_name DoubleAttackAbility
extends Ability

## Active: doubles the damage of one attack.


func _init() -> void:
	active = true


func modify_attack(ctx: AttackContext, use_active: bool) -> void:
	if use_active and not ctx.insta_kill:
		ctx.multiplier *= 2
		ctx.notes.append(display_name)
