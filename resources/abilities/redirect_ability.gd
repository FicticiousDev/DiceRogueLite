class_name RedirectAbility
extends Ability

## Active (block prompt): an enemy striking back (a retaliation or a first strike) has its hit sent on to any enemy the
## player picks within as many tiles of the player as the striker stands away, with line of sight. The hit lands as
## rolled; the new target's defence applies.


func _init() -> void:
	active = true
	use = Use.BLOCK


func redirects() -> bool:
	return true
