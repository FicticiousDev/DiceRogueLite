class_name BoardPiece
extends Node3D

## Anything that sits on a tile. Occupancy is stored on the HexTile; the board is told when it changes.

signal moved(from_id: int, to_id: int)

@export var occupies_tile: bool = true
@export var blocks_movement: bool = true
@export var blocks_line_of_sight: bool = false
@export var hop_duration: float = 0.22
@export var hop_height: float = 0.35
@export var intro_duration: float = 0.5
@export var intro_drop: float = 2.0

@onready var cutout: Cutout = get_node_or_null("Cutout")

var board: Board
var tile_id: int = -1


## Puts the piece on a tile instantly. Called by Board.add_piece.
func place(on_board: Board, new_tile_id: int) -> void:
	board = on_board
	_set_tile(new_tile_id)
	position = board.cell_top_local(Hex.coords(tile_id))


## Hops along [path] (tile ids, excluding the current tile). Awaitable.
func move_along(path: Array[int]) -> void:
	for next_id in path:
		var from_id := tile_id
		await _hop_to(next_id)
		moved.emit(from_id, next_id)


## Blinks out of the current tile and back in on [target_id]. Awaitable.
func teleport_to(target_id: int) -> void:
	var from_id := tile_id
	var body: Node3D = cutout.body if cutout else self
	var x := signf(body.scale.x) if cutout else 1.0
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector3(0.0, 1.6, 1.0), Anim.t(0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	_face(board.cell_top_local(Hex.coords(target_id)) - position)
	_set_tile(target_id)
	position = board.cell_top_local(Hex.coords(target_id))
	await get_tree().create_timer(Anim.t(0.15)).timeout
	visible = true
	tween = create_tween()
	tween.tween_property(body, "scale", Vector3(x, 1.0, 1.0), Anim.t(0.3)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	_land()
	moved.emit(from_id, target_id)


func play_intro(delay: float = 0.0) -> void:
	visible = false
	await get_tree().create_timer(Anim.t(delay)).timeout
	visible = true
	var end_pos := position
	position.y += intro_drop
	var tween := create_tween()
	tween.tween_property(self, "position", end_pos, Anim.t(intro_duration * 0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_land()


# ===========================================================================================================================================
# Movement
# ===========================================================================================================================================


func _hop_to(next_id: int) -> void:
	var from := position
	var to := board.cell_top_local(Hex.coords(next_id))
	_face(to - from)
	_set_tile(next_id)
	var arc := hop_height + maxf(to.y - from.y, 0.0)
	var tween := create_tween()
	tween.tween_method(func(t: float): position = from.lerp(to, t) + Vector3.UP * arc * 4.0 * t * (1.0 - t), 0.0, 1.0, Anim.t(hop_duration))
	await tween.finished
	_land()


## Flips the cut-out to face the direction of travel (screen left/right).
func _face(direction: Vector3) -> void:
	if not cutout or is_zero_approx(direction.x):
		return
	var facing := signf(direction.x)
	if signf(cutout.body.scale.x) != facing:
		create_tween().tween_property(cutout.body, "scale:x", facing, Anim.t(0.12)).set_trans(Tween.TRANS_BACK)


## Squash on landing and kick up the tile's terrain effect.
func _land() -> void:
	board.spawn_terrain_effect(tile_id)
	if not cutout:
		return
	var body := cutout.body
	var x := signf(body.scale.x)
	body.scale = Vector3(x * 1.25, 0.7, 1.0)
	create_tween().tween_property(body, "scale", Vector3(x, 1.0, 1.0), Anim.t(0.35)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _set_tile(new_tile_id: int) -> void:
	var old_id := tile_id
	if board.has_tile(old_id) and board.get_tile(old_id).piece == self:
		board.get_tile(old_id).piece = null
	tile_id = new_tile_id
	board.get_tile(tile_id).piece = self
	board.refresh_tile(old_id)
	board.refresh_tile(tile_id)
