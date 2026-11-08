class_name BoardPiece
extends Node3D

## Anything that sits on a tile. Occupancy is stored on the HexTile; the board is told when it changes.

signal moved(from_id: int, to_id: int)

@export var occupies_tile: bool = true
@export var blocks_movement: bool = true
@export var blocks_line_of_sight: bool = false
@export var hop_duration: float = 0.22
@export var hop_height: float = 0.35
## Intro/outro match HexTile's so pieces arrive and leave with their tiles
@export var intro_duration: float = 0.6
@export var intro_drop: float = 1.5

@onready var cutout: Cutout = get_node_or_null("Cutout")

var board: Board
var tile_id: int = -1
## Status effects: stunned pieces can't act until the end of their own turn, poisoned ones take 1 damage at the start of each of
## their turns (a heal cures it instead of restoring health)
var stunned: bool = false
var poisoned: bool = false
## Player only: frozen - this turn's movement is halved (rounded up), set at the start of the turn after a freezing hit
## ([member frozen_next]). Burn: damage still to take at the start of the next round from hits that set the piece on fire
var frozen: bool = false
var frozen_next: bool = false
var burn: int = 0


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


## Shoved sideways onto [target_id] (knockback): a quick slide with a bump on arrival. Awaitable.
func shove_to(target_id: int) -> void:
	var from_id := tile_id
	_set_tile(target_id)
	var tween := create_tween()
	tween.tween_property(self, "position", board.cell_top_local(Hex.coords(target_id)), Anim.t(0.16)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tween.finished
	_land()
	moved.emit(from_id, target_id)


func play_intro(delay: float = 0.0) -> void:
	visible = false
	await get_tree().create_timer(Anim.t(delay)).timeout
	visible = true
	var end_pos := position
	position.y += intro_drop
	scale = Vector3.ONE * 0.01
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE, Anim.t(intro_duration)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", end_pos, Anim.t(intro_duration * 0.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(Anim.t(intro_duration * 0.6)).timeout
	_land()


## Shrinks away with its tile, then frees itself.
func play_outro(delay: float = 0.0) -> void:
	await get_tree().create_timer(Anim.t(delay)).timeout
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, Anim.t(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + intro_drop, Anim.t(0.35)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	remove_from_board()


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


# ===========================================================================================================================================
# Combat feedback
# ===========================================================================================================================================


## Quick jab towards [target_position] and back. Awaits the moment of impact.
func lunge(target_position: Vector3) -> void:
	var start := position
	var offset := (target_position - position) * Vector3(1, 0, 1)
	_face(offset)
	var tween := create_tween()
	tween.tween_property(self, "position", start + offset.limit_length(0.45), Anim.t(0.1)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", start, Anim.t(0.25)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(Anim.t(0.1)).timeout


## Shake and flash red.
func hurt() -> void:
	if not cutout:
		return
	var body := cutout.body
	var tween := create_tween()
	for i in 4:
		tween.tween_property(body, "position:x", 0.06 * (1 if i % 2 == 0 else -1), Anim.t(0.035))
	tween.tween_property(body, "position:x", 0.0, Anim.t(0.035))
	cutout.flash = Color(1, 0.15, 0.1, 0.8)
	create_tween().tween_property(cutout, "flash", Color(1, 0.15, 0.1, 0.0), Anim.t(0.35))


## Floating text rising from above the piece, e.g. damage numbers. Queued per piece (one at a time) by the board.
func popup(text: String, color: Color) -> void:
	board.popup(self, text, color)


## Hover feedback for pieces the player clicks on (gates, shops, banks).
func set_hovered(_hovered: bool) -> void:
	pass


## Takes the piece off its tile and frees it.
func remove_from_board() -> void:
	if board.has_tile(tile_id) and board.get_tile(tile_id).piece == self:
		board.get_tile(tile_id).piece = null
		board.refresh_tile(tile_id)
	queue_free()


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
