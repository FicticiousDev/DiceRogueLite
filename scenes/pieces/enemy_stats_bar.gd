class_name EnemyStatsBar
extends Node3D

## An enemy's [EnemyInfo] column, drawn into a viewport and shown in 3D on the right of the piece. Lives under the
## cut-out so it moves and turns with it: it faces the piece's forward, tilted back about its base towards the
## camera so it stays readable. Its top lines up with the top of the piece; a column taller than the piece stands
## on the piece's base and grows upwards.

const INFO_SCENE: PackedScene = preload("res://scenes/ui/enemy_info/enemy_info.tscn")
const PIXEL_SIZE: float = 0.005
## Gap between the cut-out's right edge and the column
const GAP: float = 0.04

var _enemy: Enemy
var _info: EnemyInfo
var _viewport: SubViewport
var _sprite: Sprite3D


func setup(enemy: Enemy) -> void:
	_enemy = enemy
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_info = INFO_SCENE.instantiate()
	_info.enemy = enemy
	_viewport.add_child(_info)
	add_child(_viewport)

	_sprite = Sprite3D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.shaded = false
	# Mostly see-through background, so blend rather than cut out; transparent sprites sort back to front
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_sprite.double_sided = false
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)


func _process(_delta: float) -> void:
	_fit()
	var camera := get_viewport().get_camera_3d()
	if camera:
		# Camera direction in the cut-out's space; pitch only, so the column keeps the piece's facing
		var to_camera := get_parent_node_3d().to_local(camera.global_position) - position
		rotation = Vector3(-atan2(to_camera.y, to_camera.z), 0.0, 0.0)


## Sizes the viewport to the column (it changes as statuses come and go) and places the column's base.
func _fit() -> void:
	var size := Vector2i(_info.get_combined_minimum_size().ceil())
	if size == _viewport.size:
		return
	_info.size = size
	_viewport.size = size
	var column := Vector2(size) * PIXEL_SIZE
	var piece_height := _enemy.cutout.height
	# Pivot at the column's bottom centre; the sprite stands on it
	_sprite.position.y = column.y / 2.0
	position = Vector3(_enemy.cutout.width() / 2.0 + GAP + column.x / 2.0, maxf(piece_height - column.y, 0.0), 0.0)
