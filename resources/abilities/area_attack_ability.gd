class_name AreaAttackAbility
extends Ability

## Active: one attack also hits every tile next to the target for the same damage. Only the main target
## retaliates.


func _init() -> void:
	active = true


func modify_attack(ctx: AttackContext, use_active: bool) -> void:
	if use_active and ctx.target and ctx.target.board:
		ctx.aoe_tiles = ctx.target.board.get_neighbours(ctx.target.tile_id)
		ctx.notes.append(display_name)
