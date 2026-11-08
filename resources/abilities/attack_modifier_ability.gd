class_name AttackModifierAbility
extends Ability

## Active: adds modifiers to one attack (all its dice): a stun, a crit on its highest die, and/or setting what it hits on
## fire (half the damage it dealt again at the start of the next round).

@export var stun: bool = false
@export var crit_highest: bool = false
@export var fire: bool = false


func _init() -> void:
	active = true


func modify_attack(ctx: AttackContext, use_active: bool) -> void:
	if not use_active:
		return
	if stun:
		ctx.stun = true
	if fire:
		ctx.fire = true
	if crit_highest and not ctx.insta_kill and ctx.parts.size() > 0:
		ctx.crit_part(ctx.highest_part())
	ctx.notes.append(display_name)
