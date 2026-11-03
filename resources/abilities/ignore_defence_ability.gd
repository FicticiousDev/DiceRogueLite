class_name IgnoreDefenceAbility
extends Ability

## The player's attacks ignore enemies' defence. Passive: every attack. Active: the one attack it's used on.


func modify_attack(ctx: AttackContext, use_active: bool) -> void:
	if use_active or not active:
		ctx.ignore_defence = true
	if use_active:
		ctx.notes.append(display_name)
