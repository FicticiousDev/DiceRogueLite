class_name Loot
extends BoardPiece

## A chest of gold, spawned on some LOOT markers, sometimes holding a die or an item as well. Doesn't occupy its tile; the
## player takes it by moving onto it.

var gold: int = 0
## Die type id, or empty
var die_id: StringName = &""
## Item id, or empty
var item_id: StringName = &""


## Not registered on the tile, so anything can stand on or pass over it.
func place(on_board: Board, new_tile_id: int) -> void:
	board = on_board
	tile_id = new_tile_id
	position = board.cell_top_local(Hex.coords(tile_id))


func remove_from_board() -> void:
	queue_free()


## Sinks into its tile with a puff and frees itself, contents lost (left behind when the level is cleared).
func vanish() -> void:
	gold = 0
	die_id = &""
	item_id = &""
	board.spawn_terrain_effect(tile_id)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.3, 0.2, 1.3), Anim.t(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - 0.15, Anim.t(0.25))
	await tween.finished
	queue_free()


## Pops and frees the chest. Returns its contents: { gold, die, item } (die / item: ids, or empty).
func collect() -> Dictionary:
	var contents := { "gold": gold, "die": die_id, "item": item_id }
	gold = 0
	die_id = &""
	item_id = &""
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 0.6, Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
	return contents
