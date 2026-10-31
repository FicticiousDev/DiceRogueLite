class_name EnemyStatsBar
extends Sprite3D

## An enemy's [EnemyInfo] panel, drawn into a viewport and shown in 3D a fixed height above the piece. Lives under
## the cut-out so it turns with it, and tilts back to face the camera's pitch so it stays readable.

const INFO_SCENE: PackedScene = preload("res://scenes/ui/enemy_info/enemy_info.tscn")
const VIEWPORT_SIZE: Vector2i = Vector2i(480, 150)

## Centre of the bar above the piece
@export var height: float = 1.3

var _viewport: SubViewport


func setup(enemy: Enemy) -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var center := CenterContainer.new()
	center.size = VIEWPORT_SIZE
	var info: EnemyInfo = INFO_SCENE.instantiate()
	info.enemy = enemy
	center.add_child(info)
	_viewport.add_child(center)
	add_child(_viewport)

	texture = _viewport.get_texture()
	pixel_size = 0.0045
	shaded = false
	# Mostly see-through background, so blend rather than cut out; transparent sprites sort back to front
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	double_sided = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = height


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		rotation.x = camera.global_rotation.x
