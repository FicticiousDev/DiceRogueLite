class_name EnemyRangeAbility
extends Ability

## Passive: ranged enemies' attack range changes by [amount] (never below 1; melee enemies are unaffected).

@export var amount: int = -1


func enemy_range_change() -> int:
	return amount
