class_name EnemyInfo
extends PanelContainer

## Stats floating above an enemy: HP (with the planned result), attack range of damage, defence (plus defence
## dice assigned against it), move and attack range. Frees itself when the enemy is gone.

const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const RANGE: Texture2D = preload("res://assets/ui/icons/range.png")
const HEAD_HEIGHT: float = 1.15
const PLANNED_COLOR: Color = Color(1.0, 0.65, 0.25)
const DEFENCE_COLOR: Color = Color(0.45, 0.7, 1.0)

@onready var stats: HBoxContainer = %Stats

var enemy: Enemy
var camera: Camera3D
var _hp: StatIcon
var _defence: StatIcon
var _assigned: StatIcon


func setup(target: Enemy, view_camera: Camera3D) -> void:
	enemy = target
	camera = view_camera


func _ready() -> void:
	var data := enemy.data
	_hp = _add(HEART, Color(1, 0.35, 0.35))
	_add(Symbol.ICONS[Symbol.Type.ATTACK], Symbol.INK[Symbol.Type.ATTACK].lightened(0.3)).set_value("%d–%d" % [data.attack_min, data.attack_max])
	_defence = _add(Symbol.ICONS[Symbol.Type.DEFENCE], DEFENCE_COLOR)
	_defence.set_value(str(data.defence))
	_assigned = _add(Symbol.ICONS[Symbol.Type.DEFENCE], Color.WHITE)
	_add(Symbol.ICONS[Symbol.Type.MOVE], Symbol.INK[Symbol.Type.MOVE].lightened(0.4)).set_value(str(data.move))
	_add(RANGE, Color(0.9, 0.9, 0.6)).set_value(str(data.attack_range))
	if data.attacks_first:
		var first := Label.new()
		first.text = "FIRST"
		first.add_theme_font_size_override("font_size", 14)
		first.add_theme_color_override("font_color", PLANNED_COLOR)
		stats.add_child(first)


func _process(_delta: float) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		queue_free()
		return
	var head := enemy.global_position + Vector3.UP * HEAD_HEIGHT
	visible = enemy.visible and not camera.is_position_behind(head)
	if not visible:
		return
	position = camera.unproject_position(head) - Vector2(size.x / 2.0, size.y)

	if enemy.preview_hp != enemy.hp:
		_hp.set_value("%d → %d" % [enemy.hp, maxi(enemy.preview_hp, 0)], PLANNED_COLOR)
	else:
		_hp.set_value(str(enemy.hp))
	_assigned.visible = enemy.preview_defence > 0
	_assigned.set_value("+%d" % enemy.preview_defence, DEFENCE_COLOR)


func _add(texture: Texture2D, color: Color) -> StatIcon:
	var stat := StatIcon.create(texture, color)
	stats.add_child(stat)
	return stat
