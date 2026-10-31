class_name MoveAction
extends PlannedAction

## Move the player to a tile using the combined value of one or more movement dice. If all of them have a
## teleport symbol the player blinks there instead (range by line of sight, terrain ignored); mixed with
## normal movement dice the teleport is lost.

var target: int
## Tiles walked, recalculated from the simulated start position each time the plan changes
var path: Array[int] = []
var teleport: bool = false


func _init(move_dice: Array[int], target_id: int) -> void:
	dice = move_dice.duplicate()
	target = target_id


func simulate(state: TurnState, turn: TurnController) -> bool:
	var ctx := turn.move_context(state, dice)
	teleport = ctx.teleport
	if not turn.board.find_reachable(ctx).has(target):
		return false
	path = ctx.path_to(target)
	state.player_tile = target
	state.used_dice.append_array(dice)
	return true


func resolve(turn: TurnController) -> void:
	if teleport:
		await turn.player.teleport_to(target)
	else:
		await turn.player.move_along(path)


func describe(turn: TurnController) -> String:
	return "%s %d  →  %s" % ["Teleport" if teleport else "Move", turn.dice_value(dice), Hex.coords(target)]


func warning(turn: TurnController) -> String:
	return "Teleport lost: combined with normal movement" if turn.is_teleport_lost(dice) else ""


func target_tile() -> int:
	return target
