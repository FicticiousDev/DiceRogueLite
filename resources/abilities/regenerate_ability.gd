class_name RegenerateAbility
extends Ability

## Passive: the player heals 1 at the end of every round, whatever damage they took (a heal cures poison instead).


func heals_every_turn() -> bool:
	return true
