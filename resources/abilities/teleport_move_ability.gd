class_name TeleportMoveAbility
extends Ability

## Passive: every move is a teleport (range by line of sight, terrain ignored), whatever dice it uses.


func modify_move(ctx: MoveContext) -> void:
	ctx.teleport = true
