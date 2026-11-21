class_name FrostBehaviour
extends BossBehaviour

## With its ice shield up it closes the gap and attacks from adjacent; once the shield breaks it keeps away and shoots
## from as far as its range allows. In any round it takes no damage the shield recovers [member EnemyData.shield_regen].
## From the turn after the shield first breaks, every [member avalanche_every] turns it ends its turn by marking an
## avalanche: a band 3 tiles wide reaching [member avalanche_reach] tiles towards the player (walls and obstacles stop
## it). At the start of its next turn the avalanche hits everything still on it for [member avalanche_damage].

@export var avalanche_damage: int = 5
@export var avalanche_reach: int = 3
@export var avalanche_every: int = 3


func setup(boss: Enemy, _board: Board) -> void:
	sync_range(boss)


func take_turn(turn: TurnController, boss: Enemy) -> void:
	if boss.avalanche.size() > 0:
		await turn.avalanche(boss, avalanche_damage)
		if SaveManager.run_data.health <= 0:
			return
	sync_range(boss)
	if boss.shield > 0:
		await turn.standard_enemy_turn(boss)
	else:
		var path := EnemyAI.find_kite_path(boss, turn.board, turn.player.tile_id)
		if path.size() > 0:
			await boss.move_along(path)
		await turn.enemy_strikes(boss)
	if boss.avalanche_wait > 0:
		boss.avalanche_wait -= 1
		if boss.avalanche_wait == 0:
			boss.avalanche_wait = avalanche_every
			await turn.mark_avalanche(boss, zone(turn, boss))


func on_damaged(_turn: TurnController, boss: Enemy, _hp_before: int) -> void:
	sync_range(boss)
	# The first break starts the avalanches: one marked at the end of its next turn
	if boss.shield == 0 and boss.avalanche_wait == -1:
		boss.avalanche_wait = 1


func end_of_round(_turn: TurnController, boss: Enemy) -> void:
	if not boss.damaged_this_round and boss.shield < boss.base.shield:
		boss.regen_shield(boss.data.shield_regen)
		sync_range(boss)


## Adjacent while the shield holds, its full range after.
func sync_range(boss: Enemy) -> void:
	var wanted := 1 if boss.shield > 0 else boss.base.attack_range
	if boss.data.attack_range != wanted:
		boss.data.attack_range = wanted
		boss.stats_changed.emit()


## The avalanche's tiles: the line from [boss] towards the player and a line either side of it, starting beside the
## boss, each [member avalanche_reach] tiles long and stopped by walls and obstacles.
func zone(turn: TurnController, boss: Enemy) -> Array[int]:
	var board := turn.board
	var here := Hex.coords(boss.tile_id)
	var forward := turn.away_offset(here, Hex.coords(turn.player.tile_id))
	var d := Hex.NEIGHBOUR_OFFSETS.find(forward)
	var starts: Array[Vector2i] = [here + forward, here + Hex.NEIGHBOUR_OFFSETS[(d + 1) % 6], here + Hex.NEIGHBOUR_OFFSETS[(d + 5) % 6]]
	var tiles: Array[int] = []
	for start in starts:
		var cell := start
		for step in avalanche_reach:
			var tile_id := Hex.id(cell)
			if not board.has_tile(tile_id) or board.blocks_sight(tile_id):
				break
			tiles.append(tile_id)
			cell += forward
	return tiles
