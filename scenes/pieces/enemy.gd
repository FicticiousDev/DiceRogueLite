class_name Enemy
extends BoardPiece

## An enemy piece built from [EnemyData]. Spawned from ENEMY markers (or summoned by a boss).

signal died
## Its stats changed during the fight (a boss changing form): the overhead info rebuilds
signal stats_changed

## This piece's own copy of its stats - bosses change them mid-fight - and the shared definition it came from
var data: EnemyData
var base: EnemyData
var hp: int
## Ice shield left: it takes damage before health
var shield: int
## Planning previews, read by the overhead info
var preview_hp: int
var preview_shield: int
## True if the plan has it strike back, so it won't attack in the enemy turn
var preview_skips_attack: bool = false
## Statuses the plan will give it (stunned / poisoned live on BoardPiece)
var preview_stunned: bool = false
var preview_poisoned: bool = false

## Boss state (see [BossBehaviour], which holds none of its own): the boss that summoned this piece, the tile it
## started on, its current form, flame bursts still owed, whether it has called its half-health minions, and whether
## it has taken damage since the enemy phase last ended
var master: Enemy
var home: int = -1
var form: int = 0
var bursts: int = 0
var summoned: bool = false
var damaged_this_round: bool = false

var _stats_bar: EnemyStatsBar


func setup(enemy_data: EnemyData) -> void:
	base = enemy_data
	data = enemy_data.duplicate()
	hp = data.hp
	shield = data.shield
	preview_hp = hp
	preview_shield = shield
	name = data.display_name


func _ready() -> void:
	cutout.texture = data.texture
	cutout.tint = data.tint
	if not is_equal_approx(data.size, 1.0):
		cutout.height *= data.size
		cutout.thickness *= data.size
	_stats_bar = EnemyStatsBar.new()
	_stats_bar.setup(self)
	cutout.add_child(_stats_bar)


func is_dead() -> bool:
	return hp <= 0


## True if [tile] is within attack range and line of sight from [from_tile] (defaults to its own tile).
func can_hit(tile: int, from_tile: int = -1) -> bool:
	return board.in_attack_range(tile_id if from_tile == -1 else from_tile, tile, data.attack_range)


## Living enemies this piece summoned.
func minions() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy in board.get_enemies():
		if enemy.master == self:
			result.append(enemy)
	return result


## Damage that gets past a shield of [shield_left] and takes health.
static func through_shield(shield_left: int, amount: int) -> int:
	return amount - mini(shield_left, amount)


## Damage goes to the ice shield first and the rest carries over to health.
func take_damage(amount: int) -> void:
	damaged_this_round = damaged_this_round or amount > 0
	var through := through_shield(shield, amount)
	var absorbed := amount - through
	shield -= absorbed
	hp = maxi(hp - through, 0)
	preview_hp = hp
	preview_shield = shield
	hurt()
	if amount >= AttackContext.INSTA_KILL:
		popup("KILL", Color(1, 0.35, 0.25))
	elif through > 0:
		popup("-%d" % through, Color(1, 0.35, 0.25))
	elif absorbed > 0:
		popup("-%d" % absorbed, Color(0.6, 0.85, 1.0))
	else:
		popup("0", Color(0.8, 0.8, 0.8))
	if absorbed > 0 and shield == 0:
		popup("SHIELD BROKEN", Color(0.6, 0.85, 1.0))


## Gives back up to [amount] of the ice shield.
func regen_shield(amount: int) -> void:
	shield = mini(shield + amount, base.shield)
	preview_shield = shield
	popup("+%d SHIELD" % amount, Color(0.6, 0.85, 1.0))


## Charges through [path] (tile ids) without taking the tiles, calling [on_pass] (awaitable) with each as it gets there,
## then settles on [landing] (the tile it stands on, or another along the way). Awaitable.
func charge_along(path: Array[int], landing: int, on_pass: Callable) -> void:
	for next_id in path:
		var to := board.cell_top_local(Hex.coords(next_id))
		_face(to - position)
		var tween := create_tween()
		tween.tween_property(self, "position", to, Anim.t(0.1))
		await tween.finished
		await on_pass.call(next_id)
	var rest := board.cell_top_local(Hex.coords(landing))
	if not position.is_equal_approx(rest):
		var settle := create_tween()
		settle.tween_property(self, "position", rest, Anim.t(0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await settle.finished
	if landing != tile_id:
		_set_tile(landing)
	_land()


## Shakes, gets torn away and is removed from the board. Awaitable.
func play_death() -> void:
	_stats_bar.visible = false
	var body := cutout.body
	var tween := create_tween()
	for i in 6:
		tween.tween_property(body, "rotation:z", 0.12 * (1 if i % 2 == 0 else -1), Anim.t(0.04))
	tween.tween_property(body, "rotation:z", 0.6, Anim.t(0.08))
	tween.parallel().tween_property(cutout, "flash", Color(0.15, 0.1, 0.1, 0.6), Anim.t(0.08))
	tween.tween_property(body, "scale", Vector3(1.3, 0.0, 1.0), Anim.t(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(body, "rotation:z", 1.4, Anim.t(0.25))
	await tween.finished
	board.spawn_terrain_effect(tile_id)
	died.emit()
	remove_from_board()
