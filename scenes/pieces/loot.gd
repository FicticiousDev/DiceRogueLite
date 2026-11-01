class_name Loot
extends BoardPiece

## A chest of gold, spawned on some LOOT markers. Doesn't occupy its tile; the player takes it by moving onto it.

var gold: int = 0


## Not registered on the tile, so anything can stand on or pass over it.
func place(on_board: Board, new_tile_id: int) -> void:
	board = on_board
	tile_id = new_tile_id
	position = board.cell_top_local(Hex.coords(tile_id))


func remove_from_board() -> void:
	queue_free()


## Pops and frees the chest. Returns its gold.
func collect() -> int:
	var amount := gold
	gold = 0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 0.6, Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
	return amount
