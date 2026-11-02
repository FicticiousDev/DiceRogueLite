class_name AttackModifierAbility
extends Ability

## Active: adds modifiers to one attack (all its dice): a stun, and/or a crit on its highest die.

@export var stun: bool = false
@export var crit_highest: bool = false


func _init() -> void:
	active = true


func modify_attack(ctx: AttackContext, use_active: bool) -> void:
	if not use_active:
		return
	if stun:
		ctx.stun = true
	if crit_highest and not ctx.insta_kill and ctx.parts.size() > 0:
		ctx.crit_part(ctx.highest_part())
	ctx.notes.append(display_name)
