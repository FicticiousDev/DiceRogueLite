class_name WarlordBehaviour
extends BossBehaviour

## Closes in like an ordinary enemy, then every attack in its own turn knocks the player [member knockback] tiles
## directly away (blocked hits too) and, while its move lasts, it steps in after them to strike again
## ([method TurnController.enemy_knockback_strikes]). A player with no room behind them is pinned and takes more. If it
## can't reach the player at all it throws a single attack from up to [member throw_range] tiles instead.


@export var knockback: int = 1
@export var throw_range: int = 3


func take_turn(turn: TurnController, boss: Enemy) -> void:
	var path := EnemyAI.find_path(boss, turn.board, turn.player.tile_id)
	var spent := 0
	for tile_id in path:
		spent += turn.board.move_cost(tile_id)
	if path.size() > 0:
		await boss.move_along(path)
	var strikes := turn.strikes_left(boss)
	if strikes == 0:
		return
	var made := await turn.enemy_knockback_strikes(boss, strikes, knockback, boss.data.move - spent)
	if made == 0:
		await turn.enemy_throw(boss, throw_range)
