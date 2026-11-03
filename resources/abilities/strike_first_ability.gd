class_name StrikeFirstAbility
extends Ability

## The player always strikes before enemies that attack first, and their first attack each turn is a crit (its
## highest die doubled, stacking with other crits).


func strikes_first() -> bool:
	return true


func modify_attack(ctx: AttackContext, _use_active: bool) -> void:
	if ctx.first_attack and not ctx.insta_kill and ctx.parts.size() > 0:
		ctx.crit_part(ctx.highest_part())
		ctx.notes.append(display_name)
