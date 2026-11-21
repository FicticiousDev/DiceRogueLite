class_name SummonerBehaviour
extends BossBehaviour

## Lives in the arena's pools (connected water tiles) and never walks. If it can't hit the player from where it is, it
## dives and resurfaces on the pool tile furthest from them that it can hit them from; with none it calls up to
## [member count] minions beside it instead (while fewer than [member max_minions] are alive). Damage sends it under
## straight away, leaving one minion where it was; it resurfaces in another pool on its next turn.

@export var count: int = 2
@export var max_minions: int = 4


func take_turn(turn: TurnController, boss: Enemy) -> void:
	var board := turn.board
	var target := turn.player.tile_id
	if not boss.submerged and boss.can_hit(target):
		await turn.enemy_strikes(boss)
		return
	# Back up from a dive: somewhere other than the pool it went under in
	var avoid: Array[int] = []
	if boss.submerged:
		avoid = pool_of(board, boss.tile_id)
	var tile := attack_tile(board, boss, target, avoid)
	if tile != -1:
		await move_to(boss, tile)
		await turn.enemy_strikes(boss)
		return
	if boss.submerged:
		var fallback := nearest_pool_tile(board, target, avoid)
		await boss.resurface(fallback if fallback != -1 else board.nearest_free(boss.tile_id))
	var tiles := summon_tiles(boss, target, mini(count, maxi(max_minions - boss.minions().size(), 0)))
	if tiles.size() > 0:
		await turn.summon(boss, tiles)


func on_damaged(turn: TurnController, boss: Enemy, _hp_before: int) -> void:
	if boss.is_dead() or boss.submerged:
		return
	var left: Array[int] = [boss.tile_id]
	await boss.dive()
	if boss.data.minion and turn.board.get_piece(left[0]) == null:
		await turn.summon(boss, left)


## Dives (unless it's already under) and comes up on [tile_id]; stays put if it's there already.
func move_to(boss: Enemy, tile_id: int) -> void:
	if not boss.submerged:
		if tile_id == boss.tile_id:
			return
		await boss.dive()
	await boss.resurface(tile_id)


## Free water tiles (its own tile counts) not in [avoid] that [boss] could hit [target] from; the one furthest from
## [target], ties by id. -1 if there are none.
func attack_tile(board: Board, boss: Enemy, target: int, avoid: Array[int]) -> int:
	var target_cell := Hex.coords(target)
	var best := -1
	var best_distance := -1
	for tile_id in pool_tiles(board, boss, avoid):
		if not boss.can_hit(target, tile_id):
			continue
		var distance := Hex.distance(Hex.coords(tile_id), target_cell)
		if distance > best_distance or (distance == best_distance and tile_id < best):
			best = tile_id
			best_distance = distance
	return best


## The free water tile not in [avoid] closest to [target], ties by id; -1 if there is none.
func nearest_pool_tile(board: Board, target: int, avoid: Array[int]) -> int:
	var target_cell := Hex.coords(target)
	var best := -1
	var best_distance := 0
	for tile_id in pool_tiles(board, null, avoid):
		var distance := Hex.distance(Hex.coords(tile_id), target_cell)
		if best == -1 or distance < best_distance or (distance == best_distance and tile_id < best):
			best = tile_id
			best_distance = distance
	return best


## Water tiles not in [avoid] with nothing on them ([boss]'s own tile counts as free).
func pool_tiles(board: Board, boss: Enemy, avoid: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for tile_id in board.tiles:
		var piece := board.get_piece(tile_id)
		if board.get_tile(tile_id).terrain == Terrain.Type.WATER and not avoid.has(tile_id) and (piece == null or (boss != null and piece == boss)):
			result.append(tile_id)
	return result


## The pool [tile_id] is in: it and every water tile joined to it. Just [tile_id] if it isn't water.
static func pool_of(board: Board, tile_id: int) -> Array[int]:
	var pool: Array[int] = [tile_id]
	var frontier: Array[int] = [tile_id]
	while frontier.size() > 0:
		var current: int = frontier.pop_back()
		if board.get_tile(current).terrain != Terrain.Type.WATER:
			continue
		for next in board.get_neighbours(current):
			if not pool.has(next) and board.get_tile(next).terrain == Terrain.Type.WATER:
				pool.append(next)
				frontier.append(next)
	return pool


## Free tiles next to [boss], the ones closest to [target] first, at most [amount].
func summon_tiles(boss: Enemy, target: int, amount: int) -> Array[int]:
	var board := boss.board
	var target_cell := Hex.coords(target)
	var free: Array[int] = []
	for tile_id in board.get_neighbours(boss.tile_id):
		if board.is_walkable(tile_id) and board.get_piece(tile_id) == null:
			free.append(tile_id)
	free.sort_custom(func(a: int, b: int):
		var da := Hex.distance(Hex.coords(a), target_cell)
		var db := Hex.distance(Hex.coords(b), target_cell)
		return da < db or (da == db and a < b))
	var result: Array[int] = []
	result.assign(free.slice(0, amount))
	return result
