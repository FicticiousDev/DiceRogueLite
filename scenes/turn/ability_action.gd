class_name AbilityAction
extends PlannedAction

## An action active (e.g. a heal or cure) used as its own step of the turn plan. Uses no dice.

var ability: Ability


func _init(active: Ability) -> void:
	ability = active


func simulate(state: TurnState, _turn: TurnController) -> bool:
	return TurnController.spend_use(ability, state.uses)


func resolve(turn: TurnController) -> void:
	await turn.resolve_ability(ability)


func describe(_turn: TurnController) -> String:
	return "%s  (%s)" % [ability.display_name, ability.description.trim_prefix("Once per level, as an action: ").trim_suffix(".")]
