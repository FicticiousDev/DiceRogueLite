class_name AbilityAction
extends PlannedAction

## An action active (e.g. a heal or cure) used as its own step of the turn plan. Uses no dice. Boosts it grants last
## the rest of the turn from this step on.

var ability: Ability


func _init(active: Ability) -> void:
	ability = active


func simulate(state: TurnState, _turn: TurnController) -> bool:
	if not TurnController.spend_use(ability, state.uses):
		return false
	state.boosts.append_array(ability.grants_boosts())
	return true


func resolve(turn: TurnController) -> void:
	await turn.resolve_ability(ability)


func describe(_turn: TurnController) -> String:
	return "%s  (%s)" % [ability.display_name, ability.description.get_slice(": ", 1).trim_suffix(".") if ability.description.contains(": ") else ability.description]
