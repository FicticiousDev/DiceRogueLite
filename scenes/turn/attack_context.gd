class_name AttackContext
extends RefCounted

## One attack, from either side. Abilities (Phase 08) modify the context before [damage] is read; planning
## previews build the same context.

var attacker: BoardPiece
var target: BoardPiece
var base_damage: int
## Enemy defence stat, or defence dice assigned against an enemy
var defence: int
var crit: bool = false
var miss: bool = false
var insta_kill: bool = false
var ignore_defence: bool = false
## Extra tiles hit (Mage AoE, Phase 08)
var aoe_tiles: Array[int] = []


func _init(attacking: BoardPiece, targeted: BoardPiece, base: int, target_defence: int) -> void:
	attacker = attacking
	target = targeted
	base_damage = base
	defence = target_defence


func damage() -> int:
	if miss:
		return 0
	var total := base_damage * (2 if crit else 1)
	if not ignore_defence:
		total -= defence
	return maxi(total, 0)


## An enemy's attack: random damage in its min-max range, with crit/miss chances.
static func roll_enemy(enemy: Enemy, player: BoardPiece, assigned_defence: int) -> AttackContext:
	var data := enemy.data
	var ctx := AttackContext.new(enemy, player, randi_range(data.attack_min, data.attack_max), assigned_defence)
	var roll := randf()
	ctx.miss = roll < data.miss_chance
	ctx.crit = not ctx.miss and roll < data.miss_chance + data.crit_chance
	return ctx
