class_name EvasionAbility
extends Ability

## Passive: enemy attacks are [multiplier] times as likely to miss the player.

@export var multiplier: float = 2.0


func miss_chance_multiplier() -> float:
	return multiplier
