class_name AttackContext
extends RefCounted

## One attack, from either side. Abilities modify the context before [damage] is read; planning previews build
## the same context. Damage is made of parts - one per die for the player, a single roll for enemies - each with its
## own multiplier, so a crit (or Ambush) doubles just one die - the highest - rather than the whole attack.

## Defence value that stops a whole hit (dodge face, block active): more than any attack can deal
const BLOCK_ALL: int = 999
## Damage dealt by an insta-kill: more than any enemy's HP, ignoring defence
const INSTA_KILL: int = 999
## What an insta-kill face is worth against a boss instead (with a crit)
const BOSS_INSTA_KILL_DAMAGE: int = 5

var attacker: BoardPiece
var target: BoardPiece
## Sum of the parts as rolled (before multipliers)
var base_damage: int
## Damage per die (one part for enemy attacks) and each part's multiplier (crits, Ambush)
var parts: Array[int] = []
var part_multipliers: Array[int] = []
## Parts from insta-kill faces
var insta_kill_parts: Array[int] = []
## Enemy defence stat, or the player's block
var defence: int
## Some part crit (for the turn plan and stats)
var crit: bool = false
var miss: bool = false
var insta_kill: bool = false
var ignore_defence: bool = false
## Multiplier on the whole attack (no ability uses it at the moment)
var multiplier: int = 1
## Fully blocked by an ability
var negated: bool = false
## Extra tiles hit (area attacks)
var aoe_tiles: Array[int] = []
## Modifiers: skip the target's next action, poison it, ignore this much of its defence
var stun: bool = false
var poison: bool = false
var penetrate: int = 0
## The player's first attack of the turn (Quick Strike crits it)
var first_attack: bool = false
## Names of the abilities that changed this attack, for the turn plan
var notes: PackedStringArray = []


## [base] is a single part (an enemy's roll); the player's attacks replace it with one part per die ([method add_part]).
func _init(attacking: BoardPiece, targeted: BoardPiece, base: int, target_defence: int) -> void:
	attacker = attacking
	target = targeted
	defence = target_defence
	if base > 0:
		add_part(base)


## Adds a die's worth of damage. Returns its index.
func add_part(value: int) -> int:
	parts.append(value)
	part_multipliers.append(1)
	base_damage += value
	return parts.size() - 1


## Doubles one part (a crit or Ambush on that die).
func crit_part(index: int) -> void:
	part_multipliers[index] *= 2
	crit = true


## Index of the part dealing the most (after its own multipliers), or -1.
func highest_part() -> int:
	var best := -1
	for i in parts.size():
		if best == -1 or parts[i] * part_multipliers[i] > parts[best] * part_multipliers[best]:
			best = i
	return best


## Damage before defence.
func raw() -> int:
	var total := 0
	for i in parts.size():
		total += parts[i] * part_multipliers[i]
	return total * multiplier


func damage() -> int:
	if miss or negated:
		return 0
	if insta_kill:
		return INSTA_KILL
	var total := raw()
	if not ignore_defence:
		total -= maxi(defence - penetrate, 0)
	return maxi(total, 0)


## A boss target turns each insta-kill part into BOSS_INSTA_KILL_DAMAGE (in place of the face's value of 1). Returns
## the crits that come with them (one each), for the caller to apply to the highest die.
func resist_insta_kill() -> int:
	insta_kill = false
	for i in insta_kill_parts:
		base_damage += BOSS_INSTA_KILL_DAMAGE - parts[i]
		parts[i] = BOSS_INSTA_KILL_DAMAGE
	notes.append("Boss resists insta-kill")
	return insta_kill_parts.size()


## Copy aimed at another target with its own defence, for area hits.
func split(other: BoardPiece, other_defence: int) -> AttackContext:
	var ctx := AttackContext.new(attacker, other, 0, other_defence)
	ctx.parts = parts.duplicate()
	ctx.part_multipliers = part_multipliers.duplicate()
	ctx.insta_kill_parts = insta_kill_parts.duplicate()
	ctx.base_damage = base_damage
	ctx.crit = crit
	ctx.multiplier = multiplier
	ctx.insta_kill = insta_kill
	ctx.ignore_defence = ignore_defence
	if insta_kill and other is Enemy and other.data.is_boss:
		for crit in ctx.resist_insta_kill():
			ctx.crit_part(ctx.highest_part())
	ctx.stun = stun
	ctx.poison = poison
	ctx.penetrate = penetrate
	return ctx


## Shows a defence value, with a whole-hit block as "ALL".
static func value_text(value: int) -> String:
	return "ALL" if value >= BLOCK_ALL else str(value)


## An enemy's attack: its fixed damage, with random crit/miss chances.
static func roll_enemy(enemy: Enemy, player: BoardPiece, assigned_defence: int = 0) -> AttackContext:
	var data := enemy.data
	var ctx := AttackContext.new(enemy, player, data.attack, assigned_defence)
	var roll := randf()
	ctx.miss = roll < data.miss_chance
	if not ctx.miss and roll < data.miss_chance + data.crit_chance:
		ctx.crit_part(0)
	return ctx
