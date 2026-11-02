class_name IgnoreTerrainAbility
extends Ability

## Passive: every walkable tile costs 1 to enter, whatever its terrain.


func modify_move(ctx: MoveContext) -> void:
	var base := ctx.cost_func
	ctx.cost_func = func(tile_id: int) -> int:
		var cost: int = base.call(tile_id)
		return mini(cost, 1) if cost > 0 else cost
