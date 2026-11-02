class_name DoubleAttackAbility
extends Ability

## Active: doubles the highest die of one attack - like a crit on it, and it stacks with one.


func _init() -> void:
	active = true


func modify_attack(ctx: AttackContext, use_active: bool) -> void:
	if use_active and not ctx.insta_kill and ctx.parts.size() > 0:
		ctx.part_multipliers[ctx.highest_part()] *= 2
		ctx.notes.append(display_name)
