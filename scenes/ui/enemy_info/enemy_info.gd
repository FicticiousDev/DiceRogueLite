class_name EnemyInfo
extends PanelContainer

## Stats shown above an enemy (drawn into a viewport by [EnemyStatsBar]): HP (with the planned result), attack
## damage range, defence (plus defence assigned against it), move, attack range, attacks-first, and status
## effects (stunned, poisoned).

const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const SWORD: Texture2D = preload("res://assets/ui/icons/sword.png")
const SHIELD: Texture2D = preload("res://assets/ui/icons/shield.png")
const MOVE: Texture2D = preload("res://assets/ui/icons/move.png")
const BOW: Texture2D = preload("res://assets/ui/icons/bow.png")
const LIGHTNING: Texture2D = preload("res://assets/ui/icons/lightning.png")
const STUN: Texture2D = preload("res://assets/ui/icons/stun.png")
const POISON: Texture2D = preload("res://assets/ui/icons/poison.png")
const PLANNED_COLOR: Color = Color(1.0, 0.65, 0.25)
const DEFENCE_COLOR: Color = Color(0.45, 0.7, 1.0)
const FONT_SIZE: int = 40
const ICON_SIZE: float = 46.0

## Two rows to keep the bar narrow: HP, attack, defence / move, range, attacks-first, status effects
@onready var top: HBoxContainer = %Top
@onready var bottom: HBoxContainer = %Bottom

var enemy: Enemy
var _hp: StatIcon
var _defence: StatIcon
var _assigned: StatIcon
var _attack: StatIcon
var _stun: TextureRect
var _poison: TextureRect


func _ready() -> void:
	var data := enemy.data
	# Status effects lead the top row so they can't be missed
	_stun = _icon(top, STUN, Color(1.0, 0.75, 0.3))
	_poison = _icon(top, POISON, Color(0.55, 1.0, 0.45))
	_hp = _add(top, HEART, Color(1, 0.35, 0.35))
	_attack = _add(top, SWORD, Symbol.INK[Symbol.Type.ATTACK].lightened(0.3))
	_attack.set_value("%d–%d" % [data.attack_min, data.attack_max])
	_defence = _add(top, SHIELD, DEFENCE_COLOR)
	_defence.set_value(str(data.defence))
	_assigned = _add(top, SHIELD, Color.WHITE)
	_add(bottom, MOVE, Symbol.INK[Symbol.Type.MOVE].lightened(0.4)).set_value(str(data.move))
	# Range only matters beyond melee
	if data.attack_range > 1:
		_add(bottom, BOW, Color(0.95, 0.85, 0.6)).set_value(str(data.attack_range))
	if data.attacks_first:
		_icon(bottom, LIGHTNING, PLANNED_COLOR)


func _process(_delta: float) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.preview_hp != enemy.hp:
		_hp.set_value("%d → %d" % [enemy.hp, maxi(enemy.preview_hp, 0)], PLANNED_COLOR)
	else:
		_hp.set_value(str(enemy.hp))
	# Dimmed when the plan has it retaliate, as it then won't attack in the enemy turn
	_attack.modulate.a = 0.35 if enemy.preview_skips_attack else 1.0
	_assigned.visible = enemy.preview_defence > 0
	_assigned.set_value("+" + AttackContext.value_text(enemy.preview_defence), DEFENCE_COLOR)
	# Statuses the plan will apply show faded until they land
	_show_status(_stun, enemy.stunned, enemy.preview_stunned)
	_show_status(_poison, enemy.poisoned, enemy.preview_poisoned)


func _show_status(icon: TextureRect, active: bool, planned: bool) -> void:
	icon.visible = active or planned
	icon.modulate.a = 1.0 if active else 0.45


func _add(row: HBoxContainer, texture: Texture2D, color: Color) -> StatIcon:
	var stat := StatIcon.create(texture, color, FONT_SIZE, ICON_SIZE)
	row.add_child(stat)
	return stat


func _icon(row: HBoxContainer, texture: Texture2D, color: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = color
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	row.add_child(icon)
	return icon
