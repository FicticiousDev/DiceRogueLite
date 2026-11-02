class_name CureAbility
extends Ability

## Active action: removes the player's poison and/or stun. One that removes stun is also offered at the start of
## a turn the player would lose to a stun.

@export var poison: bool = true
@export var stun: bool = false


func _init() -> void:
	active = true
	use = Use.ACTION


func perform(turn: TurnController) -> void:
	await turn.cure_player(poison, stun)


func cures_stun() -> bool:
	return stun
