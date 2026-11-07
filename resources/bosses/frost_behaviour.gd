class_name FrostBehaviour
extends BossBehaviour

## With its ice shield up it closes the gap and attacks from adjacent; once the shield breaks it keeps away and shoots
## from as far as its range allows. In any round it takes no damage the shield recovers [member EnemyData.shield_regen].


func setup(boss: Enemy, _board: Board) -> void:
	sync_range(boss)


func take_turn(turn: TurnController, boss: Enemy) -> void:
	sync_range(boss)
	if boss.shield > 0:
		await turn.standard_enemy_turn(boss)
		return
	var path := EnemyAI.find_kite_path(boss, turn.board, turn.player.tile_id)
	if path.size() > 0:
		await boss.move_along(path)
	await turn.enemy_strikes(boss)


func on_damaged(_turn: TurnController, boss: Enemy, _hp_before: int) -> void:
	sync_range(boss)


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
