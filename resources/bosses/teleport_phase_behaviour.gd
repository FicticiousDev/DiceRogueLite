class_name TeleportPhaseBehaviour
extends BossBehaviour

## Each time a health segment is emptied the boss teleports to the marked tile (Board.Marker.BOSS_POINT) furthest from
## the player, calls a minion onto the marked tile closest to them and swaps form. The first form is the one in its
## [EnemyData]; the forms swap stats in place.

## Stats each form sets, in the order the boss alternates through them
const FORMS: Array[Dictionary] = [
	{ "attack_range": 4, "attack": 3, "move": 2, "defence": 1 },
	{ "attack_range": 1, "attack": 4, "move": 3, "defence": 2 },
]


func setup(boss: Enemy, _board: Board) -> void:
	apply_form(boss, 0)


func on_damaged(turn: TurnController, boss: Enemy, hp_before: int) -> void:
	for i in segments_emptied(boss.base, hp_before, boss.hp):
		if boss.is_dead():
			return
		await phase(turn, boss)


func apply_form(boss: Enemy, index: int) -> void:
	boss.form = index
	for stat in FORMS[index]:
		boss.data.set(stat, FORMS[index][stat])
	boss.stats_changed.emit()


func phase(turn: TurnController, boss: Enemy) -> void:
	var board := turn.board
	var player_cell := Hex.coords(turn.player.tile_id)
	var markers: Array[int] = []
	for cell in board.get_marker_cells(Board.Marker.BOSS_POINT):
		markers.append(Hex.id(cell))
	if markers.is_empty():
		return
	# Furthest first; ties by id so the choice is stable
	markers.sort_custom(func(a: int, b: int):
		var da := Hex.distance(Hex.coords(a), player_cell)
		var db := Hex.distance(Hex.coords(b), player_cell)
		return da > db or (da == db and a < b))
	var closest := markers[-1]
	for tile_id in markers:
		var piece := board.get_piece(tile_id)
		if piece == null or piece == boss:
			if tile_id != boss.tile_id:
				boss.popup("TELEPORT", Color(0.75, 0.55, 1.0))
				await boss.teleport_to(tile_id)
			break
	var spawn := board.nearest_free(closest)
	if spawn != -1:
		var tiles: Array[int] = [spawn]
		await turn.summon(boss, tiles)
	apply_form(boss, (boss.form + 1) % FORMS.size())
	boss.popup("NEW FORM", Color(0.75, 0.55, 1.0))
	await turn.get_tree().create_timer(Anim.t(0.4)).timeout
