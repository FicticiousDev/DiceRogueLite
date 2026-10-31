class_name MoveContext
extends RefCounted

## Inputs and results of a movement range search. Abilities (Phase 08) adjust [cost_func] or [budget]
## before the search; the turn system reads [costs]/[path_to] after it.

var start: int
var budget: int
## Piece doing the moving; its own tile never blocks it
var mover: BoardPiece
## (tile_id: int) -> int. Cost to enter a tile, -1 if it can't be entered.
var cost_func: Callable
## Blink instead of walk: range is hex distance with line of sight, terrain costs ignored
var teleport: bool = false

## Filled by Board.find_reachable: tile id -> total cost, and the previous tile on the cheapest path
var costs: Dictionary[int, int] = {}
var came_from: Dictionary[int, int] = {}


func _init(start_id: int, move_budget: int, cost: Callable, moving_piece: BoardPiece = null) -> void:
	start = start_id
	budget = move_budget
	cost_func = cost
	mover = moving_piece


## Tiles from (excluding) the start to [tile_id], or empty if unreachable.
func path_to(tile_id: int) -> Array[int]:
	var path: Array[int] = []
	if not came_from.has(tile_id):
		return path
	var current := tile_id
	while current != start:
		path.push_front(current)
		current = came_from[current]
	return path
