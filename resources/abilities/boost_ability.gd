class_name BoostAbility
extends Ability

## Active action: added to the turn plan; from that step on, [member boosts] apply for the rest of the turn (see
## Ability.grants_boosts), e.g. &"pierce" - every attack ignores defence.

@export var boosts: Array[StringName] = [&"pierce"]


func _init() -> void:
	active = true
	use = Use.ACTION


func grants_boosts() -> Array[StringName]:
	return boosts
