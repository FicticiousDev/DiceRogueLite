class_name TurnState
extends RefCounted

## Simulated state while planning. Rebuilt from the start of the turn and run through the planned actions
## in order whenever the plan changes. Later phases add fields (held defence, ability charges).

var player_tile: int
## Pool indices spent by planned actions
var used_dice: Array[int] = []
var enemy_hp: Dictionary[Enemy, int] = {}
## Defence dice assigned against each enemy and not yet used up by its attack
var defence: Dictionary[Enemy, int] = {}
## Enemies attacked this turn (they don't act in the enemy turn)
var attacked: Array[Enemy] = []
## Attack whose retaliation is still to come: it lands once the plan moves on from defend actions
## against the same enemy, so defence assigned right after an attack blocks it
var retaliation: AttackAction
## Enemies that strike back during the plan; they still move in the enemy turn but don't attack
var retaliated: Array[Enemy] = []
## Active ability uses left this level (ability id -> uses)
var uses: Dictionary = {}
## Enemies that will skip their next action / are poisoned
var stunned: Array[Enemy] = []
var poisoned: Array[Enemy] = []


func _init(start_tile: int, enemies: Array[Enemy] = []) -> void:
	player_tile = start_tile
	for enemy in enemies:
		enemy_hp[enemy] = enemy.hp
		if enemy.stunned:
			stunned.append(enemy)
		if enemy.poisoned:
			poisoned.append(enemy)


func copy() -> TurnState:
	var state := TurnState.new(player_tile)
	state.used_dice = used_dice.duplicate()
	state.enemy_hp = enemy_hp.duplicate()
	state.defence = defence.duplicate()
	state.attacked = attacked.duplicate()
	state.retaliation = retaliation
	state.retaliated = retaliated.duplicate()
	state.uses = uses.duplicate()
	state.stunned = stunned.duplicate()
	state.poisoned = poisoned.duplicate()
	return state


func is_alive(enemy: Enemy) -> bool:
	return enemy_hp.get(enemy, 0) > 0


## Enemies killed by planned attacks, so movement can pass through their tiles.
func dead_enemies() -> Array[BoardPiece]:
	var dead: Array[BoardPiece] = []
	for enemy in enemy_hp:
		if enemy_hp[enemy] <= 0:
			dead.append(enemy)
	return dead
