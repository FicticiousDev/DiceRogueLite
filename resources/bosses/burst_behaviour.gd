class_name BurstBehaviour
extends BossBehaviour

## Each time a health segment is emptied (not the last) its next turn is a flame burst instead of its move and attack:
## [member damage] to every piece within [member reach] tiles along all six straight lines, which walls and obstacles stop.


@export var reach: int = 4
@export var damage: int = 3


func on_damaged(_turn: TurnController, boss: Enemy, hp_before: int) -> void:
	boss.bursts += segments_emptied(boss.base, hp_before, boss.hp)


func take_turn(turn: TurnController, boss: Enemy) -> void:
	if boss.bursts > 0:
		boss.bursts -= 1
		await turn.flame_burst(boss, reach, damage)
	else:
		await turn.standard_enemy_turn(boss)
