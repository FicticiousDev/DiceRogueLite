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


## Top line of the action's entry in the turn plan.
func describe(_turn: TurnController) -> String:
	return ""


## Second line of the entry: how the values add up and everything that changes them (abilities, enemy defence,
## retaliation, lost teleport...), or "" for none.
func detail(_turn: TurnController) -> String:
	return ""


## Colour of the entry once it's set (MOVE / ATTACK / OTHER).
func kind() -> DieFace.Category:
	return DieFace.Category.OTHER


## Tile the action targets, for previews (-1 if none).
func target_tile() -> int:
	return -1
