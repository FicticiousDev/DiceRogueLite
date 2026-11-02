class_name EnemyStatsBar
extends Node3D

## An enemy's on-board stats. Lives under the cut-out so it moves and turns about Y with it:
## - [EnemyHealthBar] (health, defence, boss crown) on the piece's top edge, just in front of it so it draws over the
##   frame, with the [EnemyInfo] row of chips above it; both tilt back together about the bar's base towards the camera
## - status badges (stunned, poisoned) stacked down the piece's top-right corner, faded while only planned
## Viewports are drawn at roughly twice screen density at the usual camera distance; much more and the textures
## alias when shrunk (they have no mipmaps).

const INFO_SCENE: PackedScene = preload("res://scenes/ui/enemy_info/enemy_info.tscn")
const STUN: Texture2D = preload("res://assets/ui/icons/stun.png")
const POISON: Texture2D = preload("res://assets/ui/icons/poison.png")
const DISC: Texture2D = preload("res://assets/ui/disc.png")
const STUN_COLOR: Color = Color(1.0, 0.75, 0.3)
const POISON_COLOR: Color = Color(0.55, 1.0, 0.45)
const HEALTH_PIXEL_SIZE: float = 0.0065
## Health bar width relative to the piece's
const HEALTH_WIDTH_SCALE: float = 1.38
## Gap between the top of the cut-out's texture and the health bar
const HEALTH_GAP: float = 0.0
## How far in front of the cut-out's front face the health bar stands
const HEALTH_FORWARD: float = 0.02
const BADGE_SIZE: float = 0.2
## Chips: largest pixel size (a row wider than the health bar shrinks to fit it) and the gap between them and the bar
const CHIPS_MAX_PIXEL_SIZE: float = 0.0062
const CHIPS_GAP: float = 0.0

var _enemy: Enemy
var _health_bar: EnemyHealthBar
var _health_viewport: SubViewport
var _health_pivot: Node3D
var _health_sprite: Sprite3D
var _info: EnemyInfo
var _info_viewport: SubViewport
var _chips_sprite: Sprite3D
var _stun: Sprite3D
var _poison: Sprite3D


func setup(enemy: Enemy) -> void:
	_enemy = enemy
	_health_bar = EnemyHealthBar.new()
	_health_bar.enemy = enemy
	_health_viewport = _add_viewport(_health_bar)
	_health_pivot = Node3D.new()
	add_child(_health_pivot)
	_health_sprite = _viewport_sprite(_health_viewport, HEALTH_PIXEL_SIZE)
	_health_pivot.add_child(_health_sprite)

	_info = INFO_SCENE.instantiate()
	_info.enemy = enemy
	_info_viewport = _add_viewport(_info)
	_chips_sprite = _viewport_sprite(_info_viewport, CHIPS_MAX_PIXEL_SIZE)
	_health_pivot.add_child(_chips_sprite)

	_stun = _badge(STUN, STUN_COLOR)
	_poison = _badge(POISON, POISON_COLOR)


func _process(_delta: float) -> void:
	_fit()
	_update_badges()
	var camera := get_viewport().get_camera_3d()
	if camera:
		# Camera direction in the cut-out's space; pitch only, so it keeps the piece's facing
		_health_pivot.rotation.x = _pitch_towards(camera, _health_pivot.position)


## Sizes the viewports to their contents and stacks the chips on the health bar.
func _fit() -> void:
	var cutout := _enemy.cutout
	var health_size := Vector2i(ceili(cutout.width() * HEALTH_WIDTH_SCALE / HEALTH_PIXEL_SIZE), int(EnemyHealthBar.height(_enemy.data.is_boss)))
	var info_size := Vector2i(_info.get_combined_minimum_size().ceil())
	if health_size == _health_viewport.size and info_size == _info_viewport.size:
		return
	_health_bar.size = health_size
	_health_viewport.size = health_size
	_info.size = info_size
	_info_viewport.size = info_size
	_health_pivot.position = Vector3(0.0, cutout.height + HEALTH_GAP, cutout.thickness / 2.0 + HEALTH_FORWARD)
	# Pivot at the bar's bottom centre; the bar stands on it and the chips on the bar
	var health_height := health_size.y * HEALTH_PIXEL_SIZE
	_health_sprite.position.y = health_height / 2.0
	var health_width := health_size.x * HEALTH_PIXEL_SIZE
	_chips_sprite.pixel_size = minf(CHIPS_MAX_PIXEL_SIZE, health_width / info_size.x)
	_chips_sprite.position.y = health_height + CHIPS_GAP + info_size.y * _chips_sprite.pixel_size / 2.0


## Stacks the badges that apply down from the top-right corner.
func _update_badges() -> void:
	var cutout := _enemy.cutout
	var corner := Vector3(cutout.width() / 2.0 - BADGE_SIZE / 2.0, cutout.height - BADGE_SIZE / 2.0, cutout.thickness / 2.0 + 0.015)
	for entry: Array in [[_stun, _enemy.stunned, _enemy.preview_stunned], [_poison, _enemy.poisoned, _enemy.preview_poisoned]]:
		var badge: Sprite3D = entry[0]
		badge.visible = entry[1] or entry[2]
		if badge.visible:
			badge.position = corner
			_set_alpha(badge, 1.0 if entry[1] else 0.45)
			corner.y -= BADGE_SIZE * 1.05


func _pitch_towards(camera: Camera3D, from: Vector3) -> float:
	var to_camera := to_local(camera.global_position) - from
	return -atan2(to_camera.y, to_camera.z)


## The icon on a dark, rimmed disc.
func _badge(texture: Texture2D, color: Color) -> Sprite3D:
	var disc := _sprite(DISC, BADGE_SIZE)
	disc.render_priority = 2
	var icon := _sprite(texture, BADGE_SIZE * 0.68)
	icon.modulate = color
	icon.position.z = 0.005
	icon.render_priority = 3
	# Same depth as the disc to within a hair, so sort it explicitly in front
	icon.sorting_offset = 0.1
	disc.add_child(icon)
	disc.visible = false
	add_child(disc)
	return disc


func _set_alpha(badge: Sprite3D, alpha: float) -> void:
	badge.modulate.a = alpha
	for child: Sprite3D in badge.get_children():
		child.modulate.a = alpha


func _sprite(texture: Texture2D, world_size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = world_size / texture.get_width()
	sprite.shaded = false
	sprite.double_sided = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite


func _add_viewport(content: Control) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(content)
	add_child(viewport)
	return viewport


func _viewport_sprite(viewport: SubViewport, pixel_size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.pixel_size = pixel_size
	sprite.shaded = false
	# Mostly see-through background, so blend rather than cut out; transparent sprites sort back to front
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.double_sided = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite
