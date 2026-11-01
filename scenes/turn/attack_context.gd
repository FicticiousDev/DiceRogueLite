class_name AttackContext
extends RefCounted

## One attack, from either side. Abilities modify the context before [damage] is read; planning previews build
## the same context.

## Defence value that stops a whole hit (dodge face, block active): more than any attack can deal
const BLOCK_ALL: int = 999
## Damage dealt by an insta-kill: more than any enemy's HP, ignoring defence
const INSTA_KILL: int = 999
## What an insta-kill face is worth against a boss instead (with a crit)
const BOSS_INSTA_KILL_DAMAGE: int = 5

var attacker: BoardPiece
var target: BoardPiece
var base_damage: int
## Enemy defence stat, or the player's block
var defence: int
var crit: bool = false
var miss: bool = false
var insta_kill: bool = false
var ignore_defence: bool = false
## Damage multiplier from abilities (e.g. double attack)
var multiplier: int = 1
## Fully blocked by an ability
var negated: bool = false
## Extra tiles hit (area attacks)
var aoe_tiles: Array[int] = []
## Modifiers: skip the target's next action, poison it, ignore this much of its defence
var stun: bool = false
var poison: bool = false
var penetrate: int = 0
## Names of the abilities that changed this attack, for the turn plan
var notes: PackedStringArray = []


func _init(attacking: BoardPiece, targeted: BoardPiece, base: int, target_defence: int) -> void:
	attacker = attacking
	target = targeted
	base_damage = base
	defence = target_defence


func damage() -> int:
	if miss or negated:
		return 0
	if insta_kill:
		return INSTA_KILL
	var total := base_damage * (2 if crit else 1) * multiplier
	if not ignore_defence:
		total -= maxi(defence - penetrate, 0)
	return maxi(total, 0)


## A boss target turns [faces] insta-kill faces into BOSS_INSTA_KILL_DAMAGE each (in place of the face's value
## of 1) and a crit.
func resist_insta_kill(faces: int) -> void:
	insta_kill = false
	crit = true
	base_damage += (BOSS_INSTA_KILL_DAMAGE - 1) * faces
	notes.append("Boss resists insta-kill")


## Copy aimed at another target with its own defence, for area hits.
func split(other: BoardPiece, other_defence: int) -> AttackContext:
	var ctx := AttackContext.new(attacker, other, base_damage, other_defence)
	ctx.crit = crit
	ctx.multiplier = multiplier
	ctx.insta_kill = insta_kill
	ctx.ignore_defence = ignore_defence
	if insta_kill and other is Enemy and other.data.is_boss:
		ctx.resist_insta_kill(1)
	ctx.stun = stun
	ctx.poison = poison
	ctx.penetrate = penetrate
	return ctx


## Shows a defence value, with a whole-hit block as "ALL".
static func value_text(value: int) -> String:
	return "ALL" if value >= BLOCK_ALL else str(value)


## An enemy's attack: random damage in its min-max range, with crit/miss chances.
static func roll_enemy(enemy: Enemy, player: BoardPiece, assigned_defence: int = 0) -> AttackContext:
	var data := enemy.data
	var ctx := AttackContext.new(enemy, player, randi_range(data.attack_min, data.attack_max), assigned_defence)
	var roll := randf()
	ctx.miss = roll < data.miss_chance
	ctx.crit = not ctx.miss and roll < data.miss_chance + data.crit_chance
	return ctx
