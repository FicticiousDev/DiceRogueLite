class_name TurnState
extends RefCounted

## Simulated state while planning. Rebuilt from the start of the turn and run through the planned actions
## in order whenever the plan changes. Later phases add fields (enemy HP, held defence, ability charges).

var player_tile: int
## Pool indices spent by planned actions
var used_dice: Array[int] = []


func _init(start_tile: int) -> void:
	player_tile = start_tile
