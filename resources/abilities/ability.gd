class_name Ability
extends Resource

## Base for character abilities, equipment and later enemy abilities. Passives are always on; actives are used when
## the player chooses - a limited number of times per level ([member uses_per_level], items), or once whenever they're
## ready ([member cooldown], characters). The turn system runs every ability (character and equipped items, see
## TurnController.abilities) through each hook; actives only take effect when [use_active] is set.
## A new ability is a subclass overriding the hooks it needs; items and characters list them as sub-resources.

## How an active ability is used
enum Use { ATTACK, BLOCK, ACTION, MOVE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var active: bool = false
## ATTACK: armed from the turn plan, applies to the next attack the player plans. BLOCK: chosen from the block
## prompt when the player is hit. ACTION: added to the turn plan as its own step and played out with the plan
## ([method perform]). MOVE: armed from the turn plan, then a tile is chosen (see DashAbility).
@export var use: Use = Use.ATTACK
## For actives: uses per level (when [member cooldown] is 0)
@export var uses_per_level: int = 0
## For actives: once used, ready again this many turns later (used in turn 2 with a cooldown of 3: ready in turn 5).
## Every cooldown is reset when a level starts. 0: limited by [member uses_per_level] instead
@export var cooldown: int = 0


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


## Extra dice rolled with the pool every turn (e.g. a fixed defence 1 die from armour).
func extra_dice() -> Array[DieType]:
	return []


## True if the player can't be given [status] (&"stun" or &"poison").
func prevents_status(_status: StringName) -> bool:
	return false


## ACTION actives: plays the ability out for the player. Awaitable.
func perform(_turn: TurnController) -> void:
	pass


## ACTION actives: true if it removes a stun - offered when the player would lose a turn to one.
func cures_stun() -> bool:
	return false


## True if the player heals 1 at the end of every round, not only after a round without damage.
func heals_every_turn() -> bool:
	return false


## Added to the attack range of every ranged enemy (never below 1).
func enemy_range_change() -> int:
	return 0


## Multiplies the chance of every enemy attack missing the player.
func miss_chance_multiplier() -> float:
	return 1.0


## BLOCK actives: true if the hit is sent on to an enemy the player picks rather than just blocked (RedirectAbility).
func redirects() -> bool:
	return false


## ACTION and MOVE actives: effects that last the rest of the turn once used: &"pierce" (every attack ignores
## defence) or &"crit" (the next attack crits its highest die).
func grants_boosts() -> Array[StringName]:
	return []
