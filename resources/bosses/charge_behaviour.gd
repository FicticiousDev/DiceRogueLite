class_name ChargeBehaviour
extends BossBehaviour

## Doesn't walk: each turn it charges up to its move in tiles along one of the six hex lines - the one closest to the
## direction of the player - stopping before a wall or anything else it can't pass. Every piece it passes through
## takes its attack. At half health it calls its minion onto each side of the arena (the points of the arena's six
## sides, [member EnemyData.minion]).


func setup(boss: Enemy, _board: Board) -> void:
	boss.home = boss.tile_id


func take_turn(turn: TurnController, boss: Enemy) -> void:
	var path := plan(turn.board, boss, turn.player)
	if path.is_empty():
		return
	boss.popup(tr("POPUP_CHARGE"), Color(1.0, 0.6, 0.25))
	await turn.charge(boss, path)


func on_damaged(turn: TurnController, boss: Enemy, _hp_before: int) -> void:
	if boss.summoned or boss.is_dead() or boss.hp * 2 > boss.base.hp:
		return
	boss.summoned = true
	await turn.summon(boss, side_tiles(turn.board, boss))


## Tiles the charge covers, in order: along the hex line closest to the player's direction that isn't blocked at once.
func plan(board: Board, boss: Enemy, target: BoardPiece) -> Array[int]:
	var here := Hex.coords(boss.tile_id)
	var to_target := board.cell_to_local(Hex.coords(target.tile_id)) - board.cell_to_local(here)
	var wanted := Vector2(to_target.x, to_target.z).angle()
	var options: Array[Array] = []
	for i in Hex.NEIGHBOUR_OFFSETS.size():
		var step := board.cell_to_local(here + Hex.NEIGHBOUR_OFFSETS[i]) - board.cell_to_local(here)
		options.append([absf(angle_difference(wanted, Vector2(step.x, step.z).angle())), i])
	options.sort_custom(func(a: Array, b: Array): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for option in options:
		var path := line(board, boss, Hex.NEIGHBOUR_OFFSETS[option[1]])
		if path.size() > 0:
			return path
	return []


## Up to [member EnemyData.move] tiles from the boss along [offset]; stops before a wall or a fixed piece (anything but
## a player or enemy).
func line(board: Board, boss: Enemy, offset: Vector2i) -> Array[int]:
	var path: Array[int] = []
	var cell := Hex.coords(boss.tile_id)
	for step in boss.data.move:
		cell += offset
		var tile_id := Hex.id(cell)
		if not board.is_walkable(tile_id):
			break
		var piece := board.get_piece(tile_id)
		if piece != null and piece.blocks_movement and not (piece is Player or piece is Enemy):
			break
		path.append(tile_id)
	return path


## One free tile (or the nearest) at the middle of each of the arena's six sides, around the boss's starting tile.
func side_tiles(board: Board, boss: Enemy) -> Array[int]:
	var home := Hex.coords(boss.home)
	var reach := 0
	for tile_id in board.tiles:
		if board.is_walkable(tile_id):
			reach = maxi(reach, Hex.distance(home, Hex.coords(tile_id)))
	var tiles: Array[int] = []
	for i in 6:
		var near := reach / 2
		var cell := home + Hex.NEIGHBOUR_OFFSETS[i] * near + Hex.NEIGHBOUR_OFFSETS[(i + 1) % 6] * (reach - near)
		var tile_id := board.nearest_free(Hex.id(cell))
		if tile_id != -1 and not tiles.has(tile_id):
			tiles.append(tile_id)
	return tiles
