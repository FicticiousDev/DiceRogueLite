class_name TopBar
extends Control

## Status bar along the top of the screen: character, any statuses, attack range, gold, banked gold (greyed
## while the bank is empty) and the dice pool - the pool's rarest die, turning, with the pool size; clicking it opens the
## pool viewer. The bar is a trapezoid hanging from the top edge, and its background is the health bar: one section per
## HP, filled dark red for each the player has left. Abilities and equipment are buttons beside the dice row
## ([AbilityBar], [EquipmentBar]). Hovering the bar names the character and its health; every stat has a [Tooltip].

signal pool_pressed

const COIN: Texture2D = preload("res://assets/ui/icons/coin.png")
const BANK: Texture2D = preload("res://assets/ui/icons/bank.png")
const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const BOW: Texture2D = preload("res://assets/ui/icons/bow.png")
const STUN: Texture2D = preload("res://assets/ui/icons/stun.png")
const POISON: Texture2D = preload("res://assets/ui/icons/poison.png")
const FREEZE: Texture2D = preload("res://assets/ui/icons/freeze.png")
const FIRE: Texture2D = preload("res://assets/ui/icons/fire.png")

## Horizontal run of each angled end
const SLANT: float = 44.0
const BORDER: float = 4.0
const DIVIDER: float = 3.0
const BACKGROUND: Color = Color(0.17, 0.17, 0.19, 0.95)
const HEALTH: Color = Color(0.4, 0.04, 0.08)
const BORDER_COLOR: Color = Color.BLACK
const DIVIDER_COLOR: Color = Color(0, 0, 0, 0.75)
const HEART_COLOR: Color = Color(1, 0.35, 0.35)
const RANGE_COLOR: Color = Color(0.95, 0.85, 0.6)
const GOLD_COLOR: Color = Color(1, 0.82, 0.3)
const BANK_COLOR: Color = Color(0.75, 0.8, 0.9)
## Contents sized to fill ~85% of the bar's 66px height
const ICON_SIZE: float = 56.0
const FONT_SIZE: int = 44
const DIE_SIZE: float = 52.0

@onready var stats: HBoxContainer = %Stats

## Set by the run; the player's range and statuses are read from it
var turn: TurnController
var _character: Label
var _range: StatIcon
var _stun: InfoIcon
var _poison: InfoIcon
var _frozen: InfoIcon
var _burning: InfoIcon
var _gold: StatIcon
var _bank: StatIcon
var _pool_box: HBoxContainer
var _pool_view: DieView
var _pool_label: Label
## The pool as last shown, to rebuild the die when it changes
var _pool_shown: Array[String] = []
## Health as drawn (eases towards the real value) and the section count
var _shown_health: float = -1.0
var _health_target: int = -1
var _sections: int = 0
var _health_tween: Tween
## The health tooltip as last set: [name, health, max]
var _health_tip: Array = []


func _ready() -> void:
	_character = Label.new()
	_character.add_theme_font_size_override("font_size", FONT_SIZE)
	_character.add_theme_constant_override("outline_size", 6)
	_character.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	stats.add_child(_character)
	_stun = _status(STUN, Color(1.0, 0.75, 0.3), tr("STATUS_STUNNED"), tr(HelpText.PLAYER_STUNNED))
	_poison = _status(POISON, Color(0.55, 1.0, 0.45), tr("STATUS_POISONED"), tr(HelpText.PLAYER_POISONED))
	_frozen = _status(FREEZE, Color(0.55, 0.85, 1.0), tr("STATUS_FROZEN"), tr(HelpText.PLAYER_FROZEN))
	_burning = _status(FIRE, Color(1.0, 0.55, 0.2), tr("STATUS_BURNING"), tr(HelpText.PLAYER_BURNING))
	_range = _add(BOW, RANGE_COLOR, "HUD_ATTACK_RANGE", "TIP_ATTACK_RANGE")
	_gold = _add(COIN, GOLD_COLOR, "HUD_GOLD", "TIP_GOLD")
	_bank = _add(BANK, BANK_COLOR, "HUD_BANK", "TIP_BANK")
	_pool_box = HBoxContainer.new()
	_pool_box.add_theme_constant_override("separation", 4)
	Tooltip.set_info(_pool_box, tr("HUD_YOUR_DICE"), _pool_rows())
	stats.add_child(_pool_box)
	_pool_label = Label.new()
	_pool_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_pool_label.add_theme_constant_override("outline_size", 6)
	_pool_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_pool_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_pool_label.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("select"):
			pool_pressed.emit())


func _process(_delta: float) -> void:
	var run := SaveManager.run_data
	_update_health(run.health, run.max_health)
	_gold.set_value(str(run.gold))
	var bank := SaveManager.progression_data.gold_in_bank
	_bank.set_value(str(bank))
	_bank.modulate.a = 1.0 if bank > 0 else 0.35
	_update_pool()
	var has_player := turn != null and turn.player != null and is_instance_valid(turn.player)
	if has_player and turn.player.character:
		_character.text = turn.player.character.display_name
	_update_health_tip(run.health, run.max_health)
	_range.visible = has_player
	if has_player:
		_range.set_value(str(turn.player.attack_range))
	_stun.visible = has_player and turn.player.stunned
	_poison.visible = has_player and turn.player.poisoned
	_frozen.visible = has_player and (turn.player.frozen or turn.player.frozen_next)
	_burning.visible = has_player and turn.player.burn > 0


## The bar, then the health sections filled up to the health drawn, the section dividers and the border.
func _draw() -> void:
	var w := size.x
	var h := size.y
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - SLANT, h), Vector2(SLANT, h)])
	draw_colored_polygon(shape, BACKGROUND)
	if _sections > 0 and _shown_health > 0.0:
		var fill_x := w * clampf(_shown_health / _sections, 0.0, 1.0)
		var fill := PackedVector2Array([Vector2(0, 0), Vector2(fill_x, 0), Vector2(fill_x, h), Vector2(0, h)])
		for part in Geometry2D.intersect_polygons(shape, fill):
			draw_colored_polygon(part, HEALTH)
	for i in range(1, _sections):
		var x := w * i / _sections
		# Stop at the angled ends
		var bottom := minf(h, h * minf(x, w - x) / SLANT)
		draw_line(Vector2(x, 0), Vector2(x, bottom), DIVIDER_COLOR, DIVIDER, true)
	var inset := BORDER / 2.0
	var outline := PackedVector2Array([
		Vector2(inset, 0), Vector2(w - inset, 0), Vector2(w - SLANT - inset * 0.5, h - inset),
		Vector2(SLANT + inset * 0.5, h - inset), Vector2(inset, 0),
	])
	draw_polyline(outline, BORDER_COLOR, BORDER, true)


## Eases the drawn health to [param health]; a new section count redraws at once.
func _update_health(health: int, max_health: int) -> void:
	if max_health != _sections:
		_sections = max_health
		queue_redraw()
	if health == _health_target:
		return
	var first := _health_target == -1
	_health_target = health
	if _health_tween:
		_health_tween.kill()
	if first:
		_set_shown_health(health)
		return
	_health_tween = create_tween()
	_health_tween.tween_method(_set_shown_health, _shown_health, float(health), Anim.t(0.45)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _set_shown_health(value: float) -> void:
	_shown_health = value
	queue_redraw()


## Rebuilds the pool die when the pool changes.
func _update_pool() -> void:
	var dice := SaveManager.run_data.dice
	_pool_label.text = "%d / %d" % [dice.size(), SaveManager.run_data.max_dice]
	if dice == _pool_shown:
		return
	_pool_shown = dice.duplicate()
	if _pool_view:
		_pool_view.queue_free()
		_pool_view = null
	if _pool_label.get_parent():
		_pool_box.remove_child(_pool_label)
	if dice.size() > 0:
		_pool_view = DieView.create(DicePoolView.sorted_types(dice)[0], DIE_SIZE)
		_pool_view.inspect_on_click = false
		_pool_view.clicked.connect(pool_pressed.emit)
		Tooltip.set_info(_pool_view, tr("HUD_YOUR_DICE"), _pool_rows())
		_pool_box.add_child(_pool_view)
	_pool_box.add_child(_pool_label)


## Status icon shown after the character while the player has that status; hovering explains it.
func _status(texture: Texture2D, color: Color, title: String, explanation: String) -> InfoIcon:
	var icon := InfoIcon.new()
	icon.texture = texture
	icon.modulate = color
	var rows: Array[Dictionary] = [InfoPanel.row(texture, color, explanation)]
	icon.set_info(title, rows)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.visible = false
	stats.add_child(icon)
	return icon


## A stat with a tooltip: [param title_key] and [param tip_key] beside its icon.
func _add(texture: Texture2D, color: Color, title_key: String, tip_key: String) -> StatIcon:
	var stat := StatIcon.create(texture, color, FONT_SIZE, ICON_SIZE)
	var rows: Array[Dictionary] = [InfoPanel.row(texture, color, tr(tip_key))]
	Tooltip.set_info(stat, tr(title_key), rows)
	stats.add_child(stat)
	return stat


func _pool_rows() -> Array[Dictionary]:
	return [InfoPanel.row(null, Color.WHITE, tr("TIP_YOUR_DICE"))]


## The bar's own tooltip: the character (shown on the bar) and its health, updated when either changes.
func _update_health_tip(health: int, max_health: int) -> void:
	var tip := [_character.text, health, max_health]
	if tip == _health_tip:
		return
	_health_tip = tip
	var rows: Array[Dictionary] = [InfoPanel.row(HEART, HEART_COLOR, tr("TIP_HEALTH") % [health, max_health])]
	Tooltip.set_info(self, _character.text if _character.text != "" else tr("HUD_HEALTH"), rows)


func _make_custom_tooltip(_for_text: String) -> Object:
	return Tooltip.make(self)
