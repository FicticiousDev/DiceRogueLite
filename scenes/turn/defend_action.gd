class_name DefendAction
extends PlannedAction

## Assign one or more defence dice against a specific enemy, or spend a block active ability ([ability], no
## dice: blocks everything). Blocks that enemy's next attack this turn: the retaliation from an attack directly
## before it, a later retaliation, or its enemy-turn attack.

var enemy: Enemy
var ability: Ability
var _blocks_retaliation: bool = false


func _init(defence_dice: Array[int], target: Enemy, block_ability: Ability = null) -> void:
	dice = defence_dice.duplicate()
	enemy = target
	ability = block_ability


func simulate(state: TurnState, turn: TurnController) -> bool:
	if not is_instance_valid(enemy) or not state.is_alive(enemy):
		return false
	if ability and not TurnController.spend_use(ability, state.uses):
		return false
	_blocks_retaliation = state.retaliation != null and state.retaliation.enemy == enemy
	state.defence[enemy] = state.defence.get(enemy, 0) + _value(turn)
	state.used_dice.append_array(dice)
	return true


func _value(turn: TurnController) -> int:
	return AttackContext.BLOCK_ALL if ability else turn.dice_value(dice)


func resolve(turn: TurnController) -> void:
	await turn.resolve_defend(enemy, _value(turn), ability)


func describe(turn: TurnController) -> String:
	var target := enemy.data.display_name if is_instance_valid(enemy) else "?"
	if ability:
		return "%s  →  %s" % [ability.display_name, target]
	return "Defend %s  →  %s" % [AttackContext.value_text(turn.dice_value(dice)), target]


func warning(_turn: TurnController) -> String:
	return "Blocks its retaliation" if _blocks_retaliation else ""


## True if this defends against the retaliation pending from an attack on [target].
func defends_against(target: Enemy) -> bool:
	return enemy == target


func target_tile() -> int:
	return enemy.tile_id
