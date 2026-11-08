class_name DashAction
extends PlannedAction

## A move active (DashAbility) used as its own step of the turn plan: the player blinks to [target], hitting every
## enemy on the straight line between (and knocking them aside, for some). Uses no dice. Knockback isn't simulated:
## the plan keeps enemies where they stand.

var ability: DashAbility
var target: int
var _notes: PackedStringArray = []


func _init(dash: DashAbility, target_id: int) -> void:
	ability = dash
	target = target_id


func simulate(state: TurnState, turn: TurnController) -> bool:
	if state.uses.get(ability.id, 0) <= 0:
		return false
	if not turn.board.find_reachable(turn.dash_context(state, ability)).has(target):
		return false
	TurnController.spend_use(ability, state.uses)
	_notes.clear()
	if ability.damage > 0:
		for enemy in turn.dash_victims(state.player_tile, target):
			if not state.is_alive(enemy):
				continue
			var damage := turn.dash_damage(ability, enemy)
			state.hurt(enemy, damage, 2 if ability.ignore_defence else 1)
			_notes.append("%s %s" % [enemy.data.display_name, "killed" if not state.is_alive(enemy) else "-%d" % damage])
	state.player_tile = target
	state.boosts.append_array(ability.grants_boosts())
	return true


func resolve(turn: TurnController) -> void:
	await turn.resolve_dash(ability, target)


func describe(_turn: TurnController) -> String:
	return "%s  →  %s" % [ability.display_name, Hex.coords(target)]


func warning(_turn: TurnController) -> String:
	return " · ".join(_notes)


func target_tile() -> int:
	return target
