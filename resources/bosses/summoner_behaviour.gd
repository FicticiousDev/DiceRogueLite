class_name SummonerBehaviour
extends BossBehaviour

## Keeps its distance and calls minions. Each turn it moves to the tile furthest from the player that is still in its
## range, then attacks. With no minions alive it spends its turn summoning [member count] beside it instead, preferring
## the tiles between it and the player; with one free tile it summons one, with none it attacks as usual.

@export var count: int = 2


func take_turn(turn: TurnController, boss: Enemy) -> void:
	if boss.minions().is_empty():
		var tiles := summon_tiles(boss, turn.player.tile_id)
		if tiles.size() > 0:
			await turn.summon(boss, tiles)
			return
	var path := EnemyAI.find_kite_path(boss, turn.board, turn.player.tile_id)
	if path.size() > 0:
		await boss.move_along(path)
	await turn.enemy_strikes(boss)


## Free tiles next to [boss], the ones closest to [target] first, at most [member count].
func summon_tiles(boss: Enemy, target: int) -> Array[int]:
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
	result.assign(free.slice(0, count))
	return result
