class_name EnemyInfo
extends HBoxContainer

## An enemy's combat stats as a row of chips, drawn into a viewport by [EnemyStatsBar] above the health bar: attack
## damage (with the effects its hits give the player), move, attack range (beyond melee) and attacks-first. Health,
## defence and statuses are shown by the health bar and the piece's badges.

const SWORD: Texture2D = preload("res://assets/ui/icons/sword.png")
const MOVE: Texture2D = preload("res://assets/ui/icons/move.png")
const BOW: Texture2D = preload("res://assets/ui/icons/bow.png")
const LIGHTNING: Texture2D = preload("res://assets/ui/icons/lightning.png")
const STUN: Texture2D = preload("res://assets/ui/icons/stun.png")
const POISON: Texture2D = preload("res://assets/ui/icons/poison.png")
const FREEZE: Texture2D = preload("res://assets/ui/icons/freeze.png")
const FIRE: Texture2D = preload("res://assets/ui/icons/fire.png")
const PLANNED_COLOR: Color = Color(1.0, 0.65, 0.25)
const FONT_SIZE: int = 26
const ICON_SIZE: float = 26.0
const EFFECT_SIZE: float = 22.0
const OUTLINE_SIZE: int = 7

var enemy: Enemy
var _attack: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)
	_build()
	# Bosses change stats mid-fight
	enemy.stats_changed.connect(_build)


## Lays out the chips for the enemy's current stats.
func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var data := enemy.data
	var attack_text := str(data.attack) if data.attacks_per_turn <= 1 else "%d×%d" % [data.attack, data.attacks_per_turn]
	_attack = _chip(SWORD, Symbol.INK[Symbol.Type.ATTACK].lightened(0.3), attack_text)
	if data.applies_stun:
		_attack.get_child(0).add_child(_icon(STUN, Color(1.0, 0.75, 0.3), EFFECT_SIZE))
	if data.applies_poison:
		_attack.get_child(0).add_child(_icon(POISON, Color(0.55, 1.0, 0.45), EFFECT_SIZE))
	if data.applies_freeze:
		_attack.get_child(0).add_child(_icon(FREEZE, Color(0.55, 0.85, 1.0), EFFECT_SIZE))
	if data.applies_fire:
		_attack.get_child(0).add_child(_icon(FIRE, Color(1.0, 0.55, 0.2), EFFECT_SIZE))
	add_child(_attack)
	add_child(_chip(MOVE, Symbol.INK[Symbol.Type.MOVE].lightened(0.4), str(data.move)))
	# Range only matters beyond melee
	if data.attack_range > 1:
		add_child(_chip(BOW, Color(0.95, 0.85, 0.6), str(data.attack_range)))
	if data.attacks_first:
		add_child(_chip(LIGHTNING, PLANNED_COLOR, ""))


func _process(_delta: float) -> void:
	# Dimmed when the plan has it retaliate, as it then won't attack in the enemy turn
	if is_instance_valid(enemy):
		_attack.modulate.a = 0.35 if enemy.preview_skips_attack else 1.0


## A dark pill holding an icon and its value.
func _chip(texture: Texture2D, color: Color, text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.82)
	style.set_border_width_all(2)
	style.border_color = Color(0, 0, 0, 0.9)
	style.set_corner_radius_all(10)
	style.content_margin_left = 5.0
	style.content_margin_right = 7.0 if text != "" else 5.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	chip.add_theme_stylebox_override("panel", style)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(content)
	content.add_child(_icon(texture, color, ICON_SIZE))
	if text != "":
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		content.add_child(label)
	return chip


func _icon(texture: Texture2D, color: Color, icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = color
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
