class_name Enemy
extends BoardPiece

## An enemy piece built from [EnemyData]. Spawned from ENEMY markers.

signal died

var data: EnemyData
var hp: int
## Planning previews, read by the overhead info
var preview_hp: int
var preview_defence: int = 0
## True if the plan has it strike back, so it won't attack in the enemy turn
var preview_skips_attack: bool = false


func setup(enemy_data: EnemyData) -> void:
	data = enemy_data
	hp = data.hp
	preview_hp = hp
	name = data.display_name


func _ready() -> void:
	cutout.texture = data.texture
	cutout.tint = data.tint


func is_dead() -> bool:
	return hp <= 0


## True if [tile] is within attack range and line of sight from [from_tile] (defaults to its own tile).
func can_hit(tile: int, from_tile: int = -1) -> bool:
	return board.in_attack_range(tile_id if from_tile == -1 else from_tile, tile, data.attack_range)


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	preview_hp = hp
	hurt()
	popup("-%d" % amount if amount > 0 else "0", Color(1, 0.35, 0.25) if amount > 0 else Color(0.8, 0.8, 0.8))


## Shakes, gets torn away and is removed from the board. Awaitable.
func play_death() -> void:
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
