class_name WarlordBehaviour
extends BossBehaviour

## Moves and attacks like an ordinary enemy, but its second attack each turn is a slam: [member slam_damage] damage,
## shoving the player [member player_push] tiles directly away and the boss itself [member self_push] tiles directly
## back (each only as far as there is free floor). Its first attack, and its retaliation, is a plain swing for
## [member EnemyData.attack].


@export var slam_damage: int = 3
@export var player_push: int = 2
@export var self_push: int = 1


func take_turn(turn: TurnController, boss: Enemy) -> void:
	var path := EnemyAI.find_path(boss, turn.board, turn.player.tile_id)
	if path.size() > 0:
		await boss.move_along(path)
	await turn.enemy_slam_strikes(boss, slam_damage, player_push, self_push)
