class_name RangeDamageAbility
extends Ability

## Passive: attacks on enemies [from_range] or more tiles away deal 1 extra damage, +1 per tile further, up to
## [max_bonus]. Added after every other modifier, crits included, and before defence.

@export var from_range: int = 3
@export var max_bonus: int = 3


func modify_attack(ctx: AttackContext, _use_active: bool) -> void:
	if ctx.insta_kill or ctx.distance < from_range:
		return
	ctx.bonus += mini(ctx.distance - from_range + 1, max_bonus)
	ctx.notes.append(display_name)
