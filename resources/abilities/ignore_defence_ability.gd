class_name IgnoreDefenceAbility
extends Ability

## Passive: the player's attacks ignore enemies' defence.


func modify_attack(ctx: AttackContext, _use_active: bool) -> void:
	ctx.ignore_defence = true
