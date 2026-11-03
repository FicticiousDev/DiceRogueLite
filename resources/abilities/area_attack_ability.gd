class_name AreaAttackAbility
extends Ability

## Attacks also hit every tile next to the target for the same damage; only the main target retaliates.
## Passive: every attack. Active: the one attack it's used on.


func modify_attack(ctx: AttackContext, use_active: bool) -> void:
	if (use_active or not active) and ctx.target and ctx.target.board:
		ctx.aoe_tiles = ctx.target.board.get_neighbours(ctx.target.tile_id)
		ctx.notes.append(display_name)
