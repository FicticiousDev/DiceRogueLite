class_name DefendAction
extends PlannedAction

## Assign one or more defence dice against a specific enemy. Blocks that enemy's next attack this turn: the
## retaliation from an attack directly before it, a later retaliation, or (Phase 07) its enemy-turn attack.

var enemy: Enemy
var _blocks_retaliation: bool = false


func _init(defence_dice: Array[int], target: Enemy) -> void:
	dice = defence_dice.duplicate()
	enemy = target


func simulate(state: TurnState, turn: TurnController) -> bool:
	if not is_instance_valid(enemy) or not state.is_alive(enemy):
		return false
	_blocks_retaliation = state.retaliation != null and state.retaliation.enemy == enemy
	state.defence[enemy] = state.defence.get(enemy, 0) + turn.dice_value(dice)
	state.used_dice.append_array(dice)
	return true


func resolve(turn: TurnController) -> void:
	await turn.resolve_defend(enemy, turn.dice_value(dice))


func describe(turn: TurnController) -> String:
	return "Defend %d  →  %s" % [turn.dice_value(dice), enemy.data.display_name if is_instance_valid(enemy) else "?"]


func warning(_turn: TurnController) -> String:
	return "Blocks its retaliation" if _blocks_retaliation else ""


## True if this defends against the retaliation pending from an attack on [target].
func defends_against(target: Enemy) -> bool:
	return enemy == target


func target_tile() -> int:
	return enemy.tile_id
