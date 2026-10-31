class_name TopBar
extends PanelContainer

## Status bar along the top: character and ability charges, HP, gold, banked gold (greyed while the bank is empty).

const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const COIN: Texture2D = preload("res://assets/ui/icons/coin.png")
const BANK: Texture2D = preload("res://assets/ui/icons/bank.png")
const BOW: Texture2D = preload("res://assets/ui/icons/bow.png")
const STUN: Texture2D = preload("res://assets/ui/icons/stun.png")
const POISON: Texture2D = preload("res://assets/ui/icons/poison.png")

@onready var stats: HBoxContainer = %Stats

## Set by the run; ability charges are read from it
var turn: TurnController
var _character: Label
var _abilities: Dictionary[StringName, Label] = {}
var _hp: StatIcon
var _range: StatIcon
var _stun: TextureRect
var _poison: TextureRect
var _gold: StatIcon
var _bank: StatIcon


func _ready() -> void:
	_character = Label.new()
	_character.add_theme_font_size_override("font_size", 24)
	stats.add_child(_character)
	_hp = _add(HEART, Color(1, 0.35, 0.35))
	_range = _add(BOW, Color(0.95, 0.85, 0.6))
	_range.tooltip_text = "Attack range"
	_stun = _status(STUN, Color(1.0, 0.75, 0.3), "Stunned: you lose your next turn.")
	_poison = _status(POISON, Color(0.55, 1.0, 0.45), "Poisoned: 1 damage at the start of each turn until healed.")
	_gold = _add(COIN, Color(1, 0.82, 0.3))
	_bank = _add(BANK, Color(0.75, 0.8, 0.9))


func _process(_delta: float) -> void:
	var run := SaveManager.run_data
	var low := run.health <= run.max_health / 3
	_hp.set_value("%d / %d" % [run.health, run.max_health], Color(1, 0.4, 0.35) if low else Color.WHITE)
	_gold.set_value(str(run.gold))
	var bank := SaveManager.progression_data.gold_in_bank
	_bank.set_value(str(bank))
	_bank.modulate.a = 1.0 if bank > 0 else 0.35
	_update_abilities()
	# Range only shows beyond melee
	var has_player := turn != null and turn.player != null and is_instance_valid(turn.player)
	_range.visible = has_player and turn.player.attack_range > 1
	if _range.visible:
		_range.set_value(str(turn.player.attack_range))
	var poisoned := turn != null and turn.player != null and is_instance_valid(turn.player) and turn.player.poisoned
	var stunned := turn != null and turn.player != null and is_instance_valid(turn.player) and turn.player.stunned
	_stun.visible = stunned
	_poison.visible = poisoned


## Character name, then each ability; the active shows its uses left this level (as planned while planning).
func _update_abilities() -> void:
	if turn == null or turn.player == null or turn.player.character == null:
		return
	var character := turn.player.character
	_character.text = character.display_name
	var uses := turn.uses_preview()
	for ability in character.abilities:
		if not _abilities.has(ability.id):
			var label := Label.new()
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if ability.active else Color(0.8, 0.85, 0.95))
			label.tooltip_text = ability.description
			label.mouse_filter = Control.MOUSE_FILTER_PASS
			stats.add_child(label)
			stats.move_child(label, _character.get_index() + _abilities.size() + 1)
			_abilities[ability.id] = label
		var label := _abilities[ability.id]
		if ability.active:
			var left: int = uses.get(ability.id, 0)
			label.text = "%s %d/%d" % [ability.display_name, left, ability.uses_per_level]
			label.modulate.a = 1.0 if left > 0 else 0.35
		else:
			label.text = ability.display_name


## Status icon shown next to HP while the player has that status.
func _status(texture: Texture2D, color: Color, tooltip: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = color
	icon.tooltip_text = tooltip
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32, 32)
	icon.visible = false
	stats.add_child(icon)
	return icon


func _add(texture: Texture2D, color: Color) -> StatIcon:
	var stat := StatIcon.create(texture, color, 24, 30)
	stats.add_child(stat)
	return stat
