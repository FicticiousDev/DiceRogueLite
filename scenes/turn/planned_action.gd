class_name PlannedAction
extends RefCounted

## One step of the player's planned turn. [dice] are pool indices (one or more dice of the same kind).

var dice: Array[int] = []


## Applies the action to [state]. Returns false if it's no longer valid, in which case it's dropped from the plan.
func simulate(_state: TurnState, _turn: TurnController) -> bool:
	return true


## Plays the action out for real. Awaitable.
func resolve(_turn: TurnController) -> void:
	pass


## Short text for the action list.
func describe(_turn: TurnController) -> String:
	return ""


## Warning shown under the action in the list, or "" for none.
func warning(_turn: TurnController) -> String:
	return ""


## Tile the action targets, for previews (-1 if none).
func target_tile() -> int:
	return -1
