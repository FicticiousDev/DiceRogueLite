class_name Ability
extends Resource

## Base for character abilities, equipment (Phase 12), and later enemy abilities. A character has one passive
## (always on) and one active (the player chooses when to use it, a limited number of times per level).
## The turn system runs every ability through each hook; actives only take effect when [use_active] is set.

## How an active ability is aimed
enum Use { ATTACK, BLOCK }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var active: bool = false
## ATTACK: applies to the next attack the player plans. BLOCK: aimed at an enemy, fully blocks its next attack.
@export var use: Use = Use.ATTACK
## For actives: uses per level
@export var uses_per_level: int = 0


## A rolled die once the row forms. Returns true if it changed the result (the face is redrawn).
func modify_result(_result: DieResult) -> bool:
	return false


## The player's attack, before damage is read. [use_active] is true if the player spent this active on it.
func modify_attack(_ctx: AttackContext, _use_active: bool) -> void:
	pass


## An attack on the player, after the enemy's roll.
func modify_incoming_attack(_ctx: AttackContext) -> void:
	pass


## A player movement search, before it runs.
func modify_move(_ctx: MoveContext) -> void:
	pass


## True if the player always strikes before enemies that attack first.
func strikes_first() -> bool:
	return false
