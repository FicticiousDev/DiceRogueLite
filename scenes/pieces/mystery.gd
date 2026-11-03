class_name Mystery
extends BoardPiece

## A floating, spinning question mark: a cardboard cut-out like the other pieces (thickness and sticker border), coloured
## on both sides, turning about its upright axis so its edge shows. Moving onto or through it unlocks a locked loot die or item for good (the run
## shows the UnlockReveal). At most one per biome (RunMap), and only while something is still locked. Like a chest it
## doesn't occupy its tile, and it's lost if the level is cleared before it's collected. Built in code.

const COLOR: Color = Color(0.72, 0.5, 1.0)
## Placeholder art, also used by the UnlockReveal
const TEXTURE: Texture2D = preload("res://assets/pieces/mystery.png")
## Height of the cut-out, and of its base above the tile
const MARK_HEIGHT: float = 0.8
const HOVER_HEIGHT: float = 0.25
## How far it bobs either way
const BOB: float = 0.1
const BOB_TIME: float = 0.9
## Seconds per turn
const SPIN_TIME: float = 2.6

var _body: Node3D
var _mark: Cutout
var _glow: Sprite3D


func _init() -> void:
	occupies_tile = false
	blocks_movement = false


func _ready() -> void:
	_body = Node3D.new()
	_body.position.y = HOVER_HEIGHT
	add_child(_body)

	_glow = Sprite3D.new()
	_glow.texture = soft_glow()
	_glow.pixel_size = 1.3 / _glow.texture.get_width()
	_glow.modulate = Color(COLOR, 0.6)
	_glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glow.shaded = false
	_glow.position.y = MARK_HEIGHT / 2.0
	_body.add_child(_glow)

	# Spun by its own tween rather than turned to the camera, so the cardboard edge shows as it turns
	_mark = Cutout.new()
	_mark.texture = TEXTURE
	_mark.height = MARK_HEIGHT
	_mark.thickness = 0.08
	_mark.layers = 5
	_mark.face_camera = false
	_mark.double_sided = true
	_body.add_child(_mark)

	# Idle loops: the mark turns, the whole thing bobs and the glow breathes
	var spin := create_tween().set_loops()
	spin.tween_property(_mark, "rotation:y", TAU, SPIN_TIME).from(0.0)
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_body, "position:y", HOVER_HEIGHT + BOB, BOB_TIME)
	bob.tween_property(_body, "position:y", HOVER_HEIGHT - BOB, BOB_TIME)
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_glow, "scale", Vector3.ONE * 1.2, BOB_TIME * 0.75)
	pulse.tween_property(_glow, "scale", Vector3.ONE * 0.9, BOB_TIME * 0.75)


## A soft round glow, white in the middle fading out to the edge (tint it with modulate). Shared with UnlockReveal.
static func soft_glow() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


## Not registered on the tile, so anything can stand on or pass over it.
func place(on_board: Board, new_tile_id: int) -> void:
	board = on_board
	tile_id = new_tile_id
	position = board.cell_top_local(Hex.coords(tile_id))


func remove_from_board() -> void:
	queue_free()


## Shoots up, swells and pops, then frees itself.
func collect() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_body, "position:y", HOVER_HEIGHT + 0.8, Anim.t(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "scale", Vector3.ONE * 1.6, Anim.t(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_body, "scale", Vector3.ONE * 0.01, Anim.t(0.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)


## Fades into its tile with a puff and frees itself (left behind when the level is cleared).
func vanish() -> void:
	board.spawn_terrain_effect(tile_id)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_body, "scale", Vector3(1.3, 0.1, 1.3), Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_body, "position:y", 0.1, Anim.t(0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()
