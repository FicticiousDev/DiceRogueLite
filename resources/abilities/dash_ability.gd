class_name DashAbility
extends Ability

## Active move: armed from the turn plan, then a tile is chosen. The player blinks up to [member reach] tiles away (a
## teleport: line of sight, terrain ignored, onto a free tile). Every enemy on the straight line between takes
## [member damage] (its defence applies unless [member ignore_defence]) and, with [member knockback], is shoved onto a
## free tile beside the line. [member boosts] last the rest of the turn (see Ability.grants_boosts).

@export var reach: int = 4
@export var damage: int = 0
@export var ignore_defence: bool = false
@export var knockback: bool = false
@export var boosts: Array[StringName] = []


func _init() -> void:
	active = true
	use = Use.MOVE


func grants_boosts() -> Array[StringName]:
	return boosts
