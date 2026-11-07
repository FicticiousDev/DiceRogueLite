class_name EnemyAI
extends RefCounted

## Gloomhaven-style monster movement with the player as the focus. Bosses reuse it.
## - Already able to hit the target: stay put
## - Otherwise head for the hex it can attack from (in range + line of sight) that costs the least movement,
##   going as far along the cheapest path as this turn's move allows
## - Terrain costs apply; occupied tiles can't be entered; no attack hex reachable at all: don't move

## Effectively unlimited, for finding the cheapest path to an attack hex beyond this turn's move
const SEARCH_BUDGET: int = 999


## Tiles to move through this turn, excluding the current tile. Empty if the enemy stays put.
static func find_path(enemy: Enemy, board: Board, target: int) -> Array[int]:
	if enemy.can_hit(target):
		return []
	var ctx := MoveContext.new(enemy.tile_id, SEARCH_BUDGET, board.move_cost, enemy)
	var endable := board.find_reachable(ctx)
	var best := -1
	for tile_id in endable:
		if not enemy.can_hit(target, tile_id):
			continue
		# Least movement, ties broken by tile id so the choice is stable
		if best == -1 or ctx.costs[tile_id] < ctx.costs[best] or (ctx.costs[tile_id] == ctx.costs[best] and tile_id < best):
			best = tile_id
	if best == -1:
		return []

	var path := ctx.path_to(best)
	var steps := path.size()
	while steps > 0 and (ctx.costs[path[steps - 1]] > enemy.data.move or not endable.has(path[steps - 1])):
		steps -= 1
	return path.slice(0, steps)


## For enemies that shoot from as far away as they can: of the tiles reachable this turn (staying put counts) that are in
## range of [target] with line of sight, the one furthest from it, least movement on ties. If none is in range it closes
## in as [method find_path] does.
static func find_kite_path(enemy: Enemy, board: Board, target: int) -> Array[int]:
	var ctx := MoveContext.new(enemy.tile_id, enemy.data.move, board.move_cost, enemy)
	var options := board.find_reachable(ctx)
	options.append(enemy.tile_id)
	var target_cell := Hex.coords(target)
	var best := -1
	var best_distance := -1
	for tile_id in options:
		if not enemy.can_hit(target, tile_id):
			continue
		var distance := Hex.distance(Hex.coords(tile_id), target_cell)
		var cost: int = ctx.costs.get(tile_id, 0)
		var best_cost: int = ctx.costs.get(best, 0)
		if best == -1 or distance > best_distance or (distance == best_distance and (cost < best_cost or (cost == best_cost and tile_id < best))):
			best = tile_id
			best_distance = distance
	if best == -1:
		return find_path(enemy, board, target)
	if best == enemy.tile_id:
		var stay: Array[int] = []
		return stay
	return ctx.path_to(best)
