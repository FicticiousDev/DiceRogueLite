class_name BossBehaviour
extends Resource

## A boss's unique rules (set on [member EnemyData.behaviour]). One resource is shared by every copy of the boss, so
## it holds no state: anything that changes during the fight lives on the [Enemy]. Override only the hooks the boss
## needs; the defaults are an ordinary enemy.


## The level has started: the boss (and its starting minions) are on the board.
func setup(_boss: Enemy, _board: Board) -> void:
	pass


## The boss's turn in the enemy phase, in place of the usual move and attack. Awaitable.
func take_turn(turn: TurnController, boss: Enemy) -> void:
	await turn.standard_enemy_turn(boss)


## The boss lost health ([hp_before] is what it had). Runs before it retaliates. Awaitable.
func on_damaged(_turn: TurnController, _boss: Enemy, _hp_before: int) -> void:
	pass


## The enemy phase is over (each round). Awaitable.
func end_of_round(_turn: TurnController, _boss: Enemy) -> void:
	pass


## How many of [data]'s health segment boundaries lie between [before] and [after] health, i.e. segments emptied
## (the last segment has no boundary after it).
static func segments_emptied(data: EnemyData, before: int, after: int) -> int:
	var count := 0
	for k in range(1, data.segments):
		var boundary := data.hp * (data.segments - k) / data.segments
		if before > boundary and after <= boundary:
			count += 1
	return count
