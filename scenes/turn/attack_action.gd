class_name AttackAction
extends PlannedAction

## Attack an enemy in range and line of sight with the combined value of one or more attack dice. A surviving
## enemy retaliates once the plan moves on from any defend actions against it that directly follow the attack;
## enemies that attack first strike before the player, using defence assigned before the attack.

var enemy: Enemy
## Simulated outcome, for the action list
var damage: int
var _notes: PackedStringArray = []


func _init(attack_dice: Array[int], target: Enemy) -> void:
	dice = attack_dice.duplicate()
	enemy = target


func simulate(state: TurnState, turn: TurnController) -> bool:
	if not is_instance_valid(enemy) or not state.is_alive(enemy):
		return false
	if not turn.board.in_attack_range(state.player_tile, enemy.tile_id, turn.player.attack_range):
		return false
	_notes.clear()
	if enemy.data.attacks_first:
		_add_strike_note(state, "Strikes first")
	damage = turn.player_attack_context(enemy, dice).damage()
	state.enemy_hp[enemy] -= damage
	if state.enemy_hp[enemy] <= 0:
		_notes.append("Kills it (+%d gold)" % enemy.data.gold)
	elif not enemy.data.attacks_first and enemy.can_hit(state.player_tile):
		state.retaliation = self
	if not state.attacked.has(enemy):
		state.attacked.append(enemy)
	state.used_dice.append_array(dice)
	return true


## The pending retaliation lands: notes it and uses up the defence assigned against the enemy.
func settle_retaliation(state: TurnState) -> void:
	_add_strike_note(state, "Retaliates")
	state.retaliation = null


func _add_strike_note(state: TurnState, verb: String) -> void:
	if not enemy.can_hit(state.player_tile):
		return
	var blocked: int = state.defence.get(enemy, 0)
	state.defence.erase(enemy)
	_notes.append("%s %d–%d" % [verb, enemy.data.attack_min, enemy.data.attack_max] + (", %d blocked" % blocked if blocked > 0 else ""))


func resolve(turn: TurnController) -> void:
	await turn.resolve_attack(enemy, dice)


func describe(turn: TurnController) -> String:
	return "Attack %d  →  %s  (%d dmg)" % [turn.dice_value(dice), enemy.data.display_name if is_instance_valid(enemy) else "?", damage]


func warning(_turn: TurnController) -> String:
	return " · ".join(_notes)


func target_tile() -> int:
	return enemy.tile_id
