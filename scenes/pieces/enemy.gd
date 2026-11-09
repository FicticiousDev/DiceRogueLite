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
## Defence segments left: soaked up before the ice shield, one per point of damage
var defence: int
## Planning previews, read by the overhead info
var preview_hp: int
var preview_shield: int
var preview_defence: int
## True if the plan has it strike back, so it won't attack in the enemy turn
var preview_skips_attack: bool = false
## Retaliation indicator: shown on the player's turn, and whether it would strike back if attacked now (not if it is
## stunned, or attacked before the player moved this round)
var show_retaliation: bool = false
var can_retaliate: bool = true
## Statuses the plan will give it (stunned / poisoned live on BoardPiece)
var preview_stunned: bool = false
var preview_poisoned: bool = false
var preview_burning: bool = false

## Boss state (see [BossBehaviour], which holds none of its own): the boss that summoned this piece, the tile it
## started on, its current form, flame bursts still owed, whether it has called its half-health minions, and whether
## it has taken damage since the enemy phase last ended
var master: Enemy
var home: int = -1
var form: int = 0
var bursts: int = 0
var summoned: bool = false
var damaged_this_round: bool = false
## True once play_death has started, so it can't run twice on the same piece
var dying: bool = false
## Taken off a ranged attack range by the player's abilities (see TurnController._sync_enemies)
var range_reduction: int = 0

var _stats_bar: EnemyStatsBar


func setup(enemy_data: EnemyData) -> void:
	base = enemy_data
	data = enemy_data.duplicate()
	hp = data.hp
	shield = data.shield
	defence = data.defence
	preview_hp = hp
	preview_shield = shield
	preview_defence = defence
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


## Attack range as it stands: ranged enemies lose [member range_reduction] (never below 1), melee ones are unaffected.
func reach() -> int:
	return maxi(data.attack_range - range_reduction, 1) if data.attack_range > 1 else data.attack_range


## True if [tile] is within attack range and line of sight from [from_tile] (defaults to its own tile).
func can_hit(tile: int, from_tile: int = -1) -> bool:
	return board.in_attack_range(tile_id if from_tile == -1 else from_tile, tile, reach())


## Living enemies this piece summoned.
func minions() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy in board.get_enemies():
		if enemy.master == self:
			result.append(enemy)
	return result


## Damage that gets past [defence_left] segments of defence. [shield_multiplier] above 1 (armour piercing) bypasses it.
static func past_defence(defence_left: int, amount: int, shield_multiplier: int = 1) -> int:
	return amount if shield_multiplier > 1 else amount - mini(defence_left, amount)


## Defence segments lost to [amount] damage (see [method past_defence]).
static func defence_loss(defence_left: int, amount: int, shield_multiplier: int = 1) -> int:
	return 0 if shield_multiplier > 1 else mini(defence_left, amount)


## Health lost to [amount] damage once defence and then the ice shield have taken their share.
static func health_loss(defence_left: int, shield_left: int, amount: int, shield_multiplier: int = 1) -> int:
	return through_shield(shield_left, past_defence(defence_left, amount, shield_multiplier), shield_multiplier)


## Damage that gets past a shield of [shield_left] and takes health. Each point of damage takes [multiplier] shield
## (2 for armour piercing attacks).
static func through_shield(shield_left: int, amount: int, multiplier: int = 1) -> int:
	return amount - mini(ceili(float(shield_left) / multiplier), amount)


## Shield lost to [amount] damage (see [method through_shield]).
static func shield_loss(shield_left: int, amount: int, multiplier: int = 1) -> int:
	return mini(shield_left, (amount - through_shield(shield_left, amount, multiplier)) * multiplier)


## Damage goes to defence first, then the ice shield, and the rest carries over to health. [shield_multiplier]: shield
## taken per point of damage (2 for armour piercing attacks, which also bypass defence).
func take_damage(amount: int, shield_multiplier: int = 1) -> void:
	damaged_this_round = damaged_this_round or amount > 0
	var soaked := defence_loss(defence, amount, shield_multiplier)
	var past := past_defence(defence, amount, shield_multiplier)
	var through := through_shield(shield, past, shield_multiplier)
	var absorbed := shield_loss(shield, past, shield_multiplier)
	defence -= soaked
	shield -= absorbed
	hp = maxi(hp - through, 0)
	preview_hp = hp
	preview_shield = shield
	preview_defence = defence
	hurt()
	if amount >= AttackContext.INSTA_KILL:
		popup(tr("POPUP_KILL"), Color(1, 0.35, 0.25))
	elif through > 0:
		popup("-%d" % through, Color(1, 0.35, 0.25))
	elif absorbed > 0:
		popup("-%d" % absorbed, Color(0.6, 0.85, 1.0))
	elif soaked > 0:
		popup("-%d" % soaked, Color(0.45, 0.7, 1.0))
	else:
		popup("0", Color(0.8, 0.8, 0.8))
	if soaked > 0 and defence == 0:
		popup(tr("POPUP_DEFENCE_BROKEN"), Color(0.45, 0.7, 1.0))
	if absorbed > 0 and shield == 0:
		popup(tr("POPUP_SHIELD_BROKEN"), Color(0.6, 0.85, 1.0))


## Sets the defence segments left (a boss changing form refills them for the new form).
func set_defence(value: int) -> void:
	defence = clampi(value, 0, data.defence)
	preview_defence = defence


## End of round: one defence segment comes back.
func recover_defence() -> void:
	if defence < data.defence:
		set_defence(defence + 1)


## Gives back up to [amount] of the ice shield.
func regen_shield(amount: int) -> void:
	shield = mini(shield + amount, base.shield)
	preview_shield = shield
	popup(tr("POPUP_SHIELD_GAINED") % amount, Color(0.6, 0.85, 1.0))


## Charges through [path] (tile ids) without taking the tiles, calling [on_pass] (awaitable) with each as it gets there,
## then settles on the last tile of the path that is free once it has passed (pieces in the way may have been knocked
## aside), or back on its own tile if there is none. Awaitable.
func charge_along(path: Array[int], on_pass: Callable) -> void:
	for next_id in path:
		var to := board.cell_top_local(Hex.coords(next_id))
		_face(to - position)
		var tween := create_tween()
		tween.tween_property(self, "position", to, Anim.t(0.1))
		await tween.finished
		await on_pass.call(next_id)
	var landing := tile_id
	for tile in path:
		var piece := board.get_piece(tile)
		if piece == null or piece == self:
			landing = tile
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
	# Already on its way out (killed in the same blow as its boss, say): the first call finishes the job and emits died
	if dying:
		return
	dying = true
	if is_instance_valid(_stats_bar):
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
	# The board may have been torn down while this played (level cleared as the last minions fell)
	if is_instance_valid(board) and board.is_inside_tree():
		board.spawn_terrain_effect(tile_id)
	died.emit()
	if is_instance_valid(board):
		remove_from_board()
	else:
		queue_free()
