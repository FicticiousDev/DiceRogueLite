class_name ExitGate
extends BoardPiece

## A way out of the level, leading to map node [target]. Locked (and blocking) until the level is clear; then it
## opens, a bouncing arrow invites a click, and the player walks into it. The symbol shows the next level's type,
## coloured by its biome.

const LOCKED: Texture2D = preload("res://assets/pieces/gate_locked.png")
const OPEN: Texture2D = preload("res://assets/pieces/gate_open.png")

@onready var symbol: Sprite3D = $Cutout/Symbol
@onready var backing: Sprite3D = $Cutout/Symbol/Backing
@onready var indicator: Sprite3D = $Cutout/Indicator

var target: int = -1
var unlocked: bool = false
var _icon: Texture2D
var _color: Color
var _bounce: Tween


## Call before adding to the tree.
func setup(target_index: int, icon: Texture2D, color: Color) -> void:
	target = target_index
	_icon = icon
	_color = color


func _ready() -> void:
	symbol.texture = _icon
	symbol.modulate = _color
	backing.modulate = _color
	indicator.visible = false


## Changes the symbol, e.g. when the debug menu swaps the next level.
func set_icon(icon: Texture2D) -> void:
	_icon = icon
	if is_node_ready():
		symbol.texture = icon


func unlock() -> void:
	unlocked = true
	cutout.texture = OPEN
	_land()
	indicator.visible = true
	var y := indicator.position.y
	_bounce = create_tween().set_loops()
	_bounce.tween_property(indicator, "position:y", y + 0.25, Anim.t(0.35)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce.tween_property(indicator, "position:y", y, Anim.t(0.35)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func set_hovered(hovered: bool) -> void:
	create_tween().tween_property(cutout, "scale", Vector3.ONE * (1.15 if hovered else 1.0), Anim.t(0.12))


## Lets the player walk onto the gate's tile.
func open() -> void:
	blocks_movement = false
	board.refresh_tile(tile_id)
	if _bounce:
		_bounce.kill()
	indicator.visible = false


## Shrinks away once the player has stepped through.
func vanish() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, Anim.t(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	remove_from_board()
