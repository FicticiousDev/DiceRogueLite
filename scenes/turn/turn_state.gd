class_name TurnState
extends RefCounted

## Simulated state while planning. Rebuilt from the start of the turn and run through the planned actions
## in order whenever the plan changes.

var player_tile: int
## Pool indices spent by planned actions
var used_dice: Array[int] = []
var enemy_hp: Dictionary[Enemy, int] = {}
var enemy_shield: Dictionary[Enemy, int] = {}
var enemy_defence: Dictionary[Enemy, int] = {}
## Enemies attacked this turn (they don't act in the enemy turn)
var attacked: Array[Enemy] = []
## One entry per strike an enemy makes back during the plan; each uses up one of its attacks in the enemy turn
var retaliated: Array[Enemy] = []
## Active ability uses left (ability id -> uses; a cooldown active has 1 while ready)
var uses: Dictionary = {}
## Effects lasting the rest of the turn (see Ability.grants_boosts)
var boosts: Array[StringName] = []
## Enemies the plan sets on fire
var burning: Array[Enemy] = []
## Enemies that are stunned (no actions until the next round) / poisoned
var stunned: Array[Enemy] = []
var poisoned: Array[Enemy] = []
## Player attacks planned so far this turn
var attacks: int = 0


func _init(start_tile: int, enemies: Array[Enemy] = []) -> void:
	player_tile = start_tile
	for enemy in enemies:
		enemy_hp[enemy] = enemy.hp
		enemy_shield[enemy] = enemy.shield
		enemy_defence[enemy] = enemy.defence
		if enemy.stunned:
			stunned.append(enemy)
		if enemy.poisoned:
			poisoned.append(enemy)
		if enemy.burn > 0:
			burning.append(enemy)


func copy() -> TurnState:
	var state := TurnState.new(player_tile)
	state.used_dice = used_dice.duplicate()
	state.enemy_hp = enemy_hp.duplicate()
	state.enemy_shield = enemy_shield.duplicate()
	state.enemy_defence = enemy_defence.duplicate()
	state.attacked = attacked.duplicate()
	state.retaliated = retaliated.duplicate()
	state.uses = uses.duplicate()
	state.stunned = stunned.duplicate()
	state.poisoned = poisoned.duplicate()
	state.attacks = attacks
	state.boosts = boosts.duplicate()
	state.burning = burning.duplicate()
	return state


## Damage to [enemy]: defence takes it first (armour piercing bypasses it), then the ice shield ([shield_multiplier]
## per point), health the rest.
func hurt(enemy: Enemy, amount: int, shield_multiplier: int = 1) -> void:
	var defence: int = enemy_defence.get(enemy, 0)
	var shield: int = enemy_shield.get(enemy, 0)
	var past := Enemy.past_defence(defence, amount, shield_multiplier)
	enemy_defence[enemy] = defence - Enemy.defence_loss(defence, amount, shield_multiplier)
	enemy_shield[enemy] = shield - Enemy.shield_loss(shield, past, shield_multiplier)
	enemy_hp[enemy] -= Enemy.through_shield(shield, past, shield_multiplier)


func is_alive(enemy: Enemy) -> bool:
	return enemy_hp.get(enemy, 0) > 0


## Enemies killed by planned attacks, so movement can pass through their tiles.
func dead_enemies() -> Array[BoardPiece]:
	var dead: Array[BoardPiece] = []
	for enemy in enemy_hp:
		if enemy_hp[enemy] <= 0:
			dead.append(enemy)
	return dead
